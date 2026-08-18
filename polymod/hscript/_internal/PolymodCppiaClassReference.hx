package polymod.hscript._internal;

/**
 * A class reference backed by a compiled cppia class instead of a parsed script.
 */
class PolymodCppiaClassReference extends PolymodStaticClassReference
{
  public static final MANIFEST_CLASS:String = 'PolymodCppiaManifest';

  static final registry:Map<String, Class<Dynamic>> = new Map<String, Class<Dynamic>>();

  /**
   * What each file gave us, kept across reloads.
   */
  static final loadedModules:Map<String, LoadedCppiaModule> = new Map<String, LoadedCppiaModule>();

  /**
   * Every class name any compiled script has ever provided, kept for the life of the process.
   */
  static final everProvided:Map<String, Bool> = new Map<String, Bool>();

  /**
   * The version a cppia must be stamped with to be accepted.
   */
  public static var expectedVersion:Null<String> = null;

  static var reportedMismatch:Bool = false;

  public static function clearCppiaClasses():Void
  {
    // Only the active registry is dropped. What was loaded stays known, because it cannot be undone.
    registry.clear();
    reportedMismatch = false;
  }

  /**
   * Signature of a file's contents, used to tell a reload of the same bytes from a rebuilt mod.
   */
  static function signatureOf(data:haxe.io.Bytes):String
  {
    return '${data.length}:${haxe.crypto.Crc32.make(data)}';
  }

  public static function hasCppiaClass(clsName:String):Bool
  {
    return registry.exists(clsName);
  }

  /**
   * Whether this name belongs to a compiled script that is no longer loaded.
   *
   * The class object still exists, because hxcpp cannot unload it, but nothing should resolve to it.
   */
  public static function isInactiveCppiaClass(clsName:String):Bool
  {
    return everProvided.exists(clsName) && !registry.exists(clsName);
  }

  /**
   * Free the code of every module whose classes are no longer registered.
   */
  public static function unloadInactiveModules():Void
  {
    #if (hxcpp && POLYMOD_CPPIA)
    // Snapshot the keys, the loop removes entries.
    for (path in [for (key in loadedModules.keys()) key])
    {
      var loaded:LoadedCppiaModule = loadedModules.get(path);

      var active:Array<String> = loaded.names.filter(name -> registry.exists(name));

      if (active.length == loaded.names.length) continue;

      if (active.length > 0)
      {
        // Another script re-registered part of this one's classes.
        Polymod.warning(SCRIPT_PARSE_FAILED,
          'Compiled script "$path" is partly still in use (${active.join(", ")} of ${loaded.names.join(", ")}), so it cannot be unloaded. Two scripts are probably providing the same class.',
          SCRIPT_RUNTIME);
        continue;
      }

      if (!unloadModule(loaded, path)) continue;

      loadedModules.remove(path);
      trace('[cppia] unloaded "$path", its mod is no longer enabled.');
    }
    #end
  }

  /**
   * Free one module's code, reporting rather than throwing if the native side refuses.
   * @return Whether the module was actually unloaded.
   */
  static function unloadModule(loaded:LoadedCppiaModule, path:String):Bool
  {
    try
    {
      loaded.unload();
      return true;
    }
    catch (e:Dynamic)
    {
      Polymod.error(SCRIPT_RUNTIME_EXCEPTION,
        'Failed to unload compiled script "$path": $e. Its code stays in memory until the game restarts.', SCRIPT_RUNTIME);
      return false;
    }
  }

  public static function listCppiaClasses():Array<String>
  {
    return [for (name in registry.keys()) name];
  }

  /**
   * A cppia class is a real class, so we can check its superclasses to see if it extends the given class path.
   */
  public static function listCppiaClassesExtending(clsPath:String):Array<String>
  {
    var result:Array<String> = [];

    for (name => cls in registry)
    {
      var superCls = Type.getSuperClass(cls);
      while (superCls != null)
      {
        if (Type.getClassName(superCls) == clsPath)
        {
          result.push(name);
          break;
        }
        superCls = Type.getSuperClass(superCls);
      }
    }

    return result;
  }

  /**
   * The names a compiled script may not reference.
   */
  static function deniedNames():Map<String, Bool>
  {
    var result:Map<String, Bool> = new Map<String, Bool>();

    for (name => alias in PolymodScriptClass.importOverrides)
    {
      if (alias == null || Type.getClassName(alias) != name) result.set(name, true);
    }

    return result;
  }

  /**
   * Which denied name a type resolves to, if any.
   */
  static function deniedNameFor(type:String, denied:Map<String, Bool>):Null<String>
  {
    if (denied.exists(type)) return type;

    var parts:Array<String> = type.split('.');
    for (i in 1...parts.length)
    {
      var suffix:String = parts.slice(i).join('.');
      if (denied.exists(suffix)) return suffix;
    }

    return null;
  }

  /**
   * Check a compiled script against the blacklist before any of it runs.
   * @return The denied names it references, or null if the file could not be read at all.
   */
  static function scanDenied(data:haxe.io.Bytes, path:String):Null<Array<String>>
  {
    var types:Array<String> = null;

    try
    {
      types = PolymodCppiaScanner.readTypes(data);
    }
    catch (e:Dynamic)
    {
      Polymod.error(SCRIPT_PARSE_FAILED, 'Could not read the header of compiled script "$path": $e', SCRIPT_RUNTIME);
      return null;
    }

    var denied:Map<String, Bool> = deniedNames();
    var found:Array<String> = [];

    for (type in types)
    {
      var name:Null<String> = deniedNameFor(type, denied);
      if (name != null && !found.contains(name)) found.push(name);
    }

    return found;
  }

  public static function tryBuildCppia(clsName:String):Null<PolymodCppiaClassReference>
  {
    var cls = registry.get(clsName);
    if (cls == null) return null;
    return new PolymodCppiaClassReference(clsName, cls);
  }

  /**
   * Load a compiled script and register the classes it declares.
   * @return The names of the classes registered, empty if the module was refused.
   */
  public static function registerModule(data:haxe.io.Bytes, path:String):Array<String>
  {
    #if (hxcpp && POLYMOD_CPPIA)
    if (data == null || data.length == 0)
    {
      Polymod.error(SCRIPT_PARSE_FAILED, 'Compiled script "$path" is empty, rebuild it with the current build command.', SCRIPT_RUNTIME);
      return [];
    }

    var signature:String = signatureOf(data);
    var previous:LoadedCppiaModule = loadedModules.get(path);

    if (previous != null && previous.signature == signature)
    {
      // Same bytes as last time. Put the classes we already have back in the registry.
      for (i in 0...previous.names.length)
      {
        registry.set(previous.names[i], previous.refs[i]);
        everProvided.set(previous.names[i], true);
      }

      trace('[cppia] reused "$path" providing ${previous.names.join(", ")}, unchanged since it was loaded.');
      return previous.names.copy();
    }

    if (previous != null)
    {
      Polymod.info(SCRIPT_PARSE_START,
        'Compiled script "$path" changed since it was loaded, unloading the previous copy.', SCRIPT_RUNTIME);

      unloadModule(previous, path);
      loadedModules.remove(path);
    }

    var denied:Null<Array<String>> = scanDenied(data, path);
    if (denied == null) return [];

    if (denied.length > 0)
    {
      Polymod.error(SCRIPT_PARSE_FAILED,
        'Compiled script "$path" references ${denied.length == 1 ? "a class" : "classes"} that mods are not allowed to use: ${denied.join(", ")}. It will not be loaded.',
        SCRIPT_RUNTIME);
      return [];
    }

    var module:cpp.cppia.Module = null;

    trace('[cppia] reading "$path" (${data.length} bytes)...');

    try
    {
      module = cpp.cppia.Module.fromData(data.getData());
    }
    catch (e:Dynamic)
    {
      Polymod.error(SCRIPT_PARSE_FAILED, 'Failed to read compiled script "$path": $e', SCRIPT_RUNTIME);
      return [];
    }

    if (module == null)
    {
      Polymod.error(SCRIPT_PARSE_FAILED, 'Compiled script "$path" produced no module, it is probably corrupt.', SCRIPT_RUNTIME);
      return [];
    }

    trace('[cppia] booting "$path"...');

    try
    {
      module.boot();
    }
    catch (e:Dynamic)
    {
      Polymod.error(SCRIPT_PARSE_FAILED, 'Failed to boot compiled script "$path": $e', SCRIPT_RUNTIME);
      return [];
    }

    var manifest:Class<Dynamic> = null;
    try
    {
      manifest = module.resolveClass(MANIFEST_CLASS);
    }
    catch (e:Dynamic)
    {
      manifest = null;
    }

    if (manifest == null)
    {
      Polymod.error(SCRIPT_PARSE_FAILED, 'Compiled script "$path" has no $MANIFEST_CLASS, rebuild it with the current build command.', SCRIPT_RUNTIME);
      return [];
    }

    var stamp:String = Std.string(Reflect.field(manifest, 'gameVersion'));
    if (expectedVersion != null && stamp != expectedVersion)
    {
      if (!reportedMismatch)
      {
        reportedMismatch = true;
        Polymod.error(SCRIPT_PARSE_FAILED,
          'Compiled script "$path" was built for game version "$stamp" but this game is "$expectedVersion". It will not be loaded, so the mod needs rebuilding.',
          SCRIPT_RUNTIME);
      }
      return [];
    }

    var declared:Array<Class<Dynamic>> = cast Reflect.field(manifest, 'classRefs');
    if (declared == null)
    {
      Polymod.error(SCRIPT_PARSE_FAILED, 'Compiled script "$path" has no classRefs, rebuild it with the current build command.', SCRIPT_RUNTIME);
      return [];
    }

    var expectedNames:Array<String> = cast Reflect.field(manifest, 'classes');

    var registered:Array<String> = [];
    var registeredRefs:Array<Class<Dynamic>> = [];
    for (i in 0...declared.length)
    {
      var cls = declared[i];
      var expectedName:String = (expectedNames != null && i < expectedNames.length) ? expectedNames[i] : 'entry $i';

      if (cls == null)
      {
        Polymod.error(SCRIPT_PARSE_FAILED, 'Compiled script "$path" declares "$expectedName" but the module did not provide it, rebuild it with the current build command.',
          SCRIPT_RUNTIME);
        continue;
      }

      var name = Type.getClassName(cls);
      if (name == null)
      {
        Polymod.error(SCRIPT_PARSE_FAILED, 'Compiled script "$path" provided an unnamed class for "$expectedName".', SCRIPT_RUNTIME);
        continue;
      }

      if (registry.exists(name))
      {
        Polymod.warning(SCRIPT_PARSE_FAILED, 'Compiled class "$name" was already registered, "$path" is replacing it.', SCRIPT_RUNTIME);
      }

      registry.set(name, cls);
      everProvided.set(name, true);
      registered.push(name);
      registeredRefs.push(cls);
    }

    loadedModules.set(path, new LoadedCppiaModule(signature, registered, registeredRefs, module));

    trace('[cppia] loaded "$path" providing ${registered.join(", ")}');

    return registered;
    #else
    return [];
    #end
  }

  final clsName:String;
  final cppiaClass:Class<Dynamic>;

  public function new(clsName:String, cppiaClass:Class<Dynamic>)
  {
    super();
    this.clsName = clsName;
    this.cppiaClass = cppiaClass;
  }

  override public function instantiate(?args:Array<Dynamic>):Null<Dynamic>
  {
    if (cppiaClass == null)
    {
      Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Compiled class ($clsName) is not loaded, so it cannot be constructed.', SCRIPT_RUNTIME);
      return null;
    }

    var callArgs:Array<Dynamic> = args ?? [];

    try
    {
      var result = Type.createInstance(cppiaClass, callArgs);
      if (result == null)
      {
        Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Constructing compiled class ($clsName) with ${callArgs.length} argument(s) returned null.', SCRIPT_RUNTIME);
      }
      return result;
    }
    catch (e:Dynamic)
    {
      Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Could not construct compiled class ($clsName) with ${callArgs.length} argument(s): $e', SCRIPT_RUNTIME);
      return null;
    }
  }

  override public function buildASC(?args:Array<Dynamic>):PolymodAbstractScriptClass
  {
    Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Compiled class ($clsName) has no script class to build.', SCRIPT_RUNTIME);
    return null;
  }

  override public function callFunction(funcName:String, ?args:Array<Dynamic>):Dynamic
  {
    if (cppiaClass == null)
    {
      Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Compiled class ($clsName) is not loaded, so "$funcName" cannot be called.', SCRIPT_RUNTIME);
      return null;
    }

    var fn:Dynamic = Reflect.field(cppiaClass, funcName);
    if (fn == null)
    {
      Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Compiled class ($clsName) has no static function "$funcName".', SCRIPT_RUNTIME);
      return null;
    }

    if (!Reflect.isFunction(fn))
    {
      Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Compiled class ($clsName) field "$funcName" is not a function.', SCRIPT_RUNTIME);
      return null;
    }

    // A script calling into compiled code must not take the whole game down on a bad call.
    try
    {
      return Reflect.callMethod(cppiaClass, fn, args ?? []);
    }
    catch (e:Dynamic)
    {
      Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Compiled class ($clsName) threw calling "$funcName": $e', SCRIPT_RUNTIME);
      return null;
    }
  }

  override public function getField(fieldName:String):Dynamic
  {
    if (cppiaClass == null)
    {
      Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Compiled class ($clsName) is not loaded, so "$fieldName" cannot be read.', SCRIPT_RUNTIME);
      return null;
    }

    return Reflect.field(cppiaClass, fieldName);
  }

  override public function setField(fieldName:String, fieldValue:Dynamic):Dynamic
  {
    if (cppiaClass == null)
    {
      Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Compiled class ($clsName) is not loaded, so "$fieldName" cannot be written.', SCRIPT_RUNTIME);
      return null;
    }

    Reflect.setField(cppiaClass, fieldName, fieldValue);
    return fieldValue;
  }

  override public function getFullyQualifiedName():String
  {
    return clsName;
  }

  override public function toString():String
  {
    return 'PolymodCppiaClassReference($clsName)';
  }
}

@:headerInclude("hx/Scriptable.h")
private class LoadedCppiaModule
{
  public final signature:String;
  public final names:Array<String>;
  public final refs:Array<Class<Dynamic>>;

  #if (hxcpp && POLYMOD_CPPIA)
  var module:Null<cpp.cppia.Module>;
  #end

  public function new(signature:String, names:Array<String>, refs:Array<Class<Dynamic>>, module:Dynamic)
  {
    this.signature = signature;
    this.names = names;
    this.refs = refs;
    #if (hxcpp && POLYMOD_CPPIA)
    this.module = module;
    #end
  }

  /**
   * Free the module's code.
   */
  public function unload():Void
  {
    #if (hxcpp && POLYMOD_CPPIA)
    if (module == null) return;

    var m = module;
    module = null;
    untyped __cpp__("{0}->unload()", m);
    #end
  }
}
