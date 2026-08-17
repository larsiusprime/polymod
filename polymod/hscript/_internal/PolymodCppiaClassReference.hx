package polymod.hscript._internal;

/**
 * A class reference backed by a compiled cppia class instead of a parsed script.
 */
class PolymodCppiaClassReference extends PolymodStaticClassReference
{
  public static final MANIFEST_CLASS:String = 'PolymodCppiaManifest';

  static final registry:Map<String, Class<Dynamic>> = new Map<String, Class<Dynamic>>();

  /**
   * The version a cppia must be stamped with to be accepted.
   */
  public static var expectedVersion:Null<String> = null;

  static var reportedMismatch:Bool = false;

  public static function clearCppiaClasses():Void
  {
    registry.clear();
    reportedMismatch = false;
  }

  public static function hasCppiaClass(clsName:String):Bool
  {
    return registry.exists(clsName);
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
    var module:cpp.cppia.Module = null;

    try
    {
      module = cpp.cppia.Module.fromData(data.getData());
      module.boot();
    }
    catch (e:Dynamic)
    {
      Polymod.error(SCRIPT_PARSE_FAILED, 'Failed to load compiled script "$path": $e', SCRIPT_RUNTIME);
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

    var registered:Array<String> = [];
    for (cls in declared)
    {
      if (cls == null) continue;

      var name = Type.getClassName(cls);
      if (name == null) continue;

      registry.set(name, cls);
      registered.push(name);
    }

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
    try
    {
      return Type.createInstance(cppiaClass, args ?? []);
    }
    catch (e:Dynamic)
    {
      Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Could not construct instance of compiled class ($clsName): $e', SCRIPT_RUNTIME);
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
    var fn:Dynamic = Reflect.field(cppiaClass, funcName);
    if (fn == null)
    {
      Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Compiled class ($clsName) has no static function "$funcName".', SCRIPT_RUNTIME);
      return null;
    }
    return Reflect.callMethod(cppiaClass, fn, args ?? []);
  }

  override public function getField(fieldName:String):Dynamic
  {
    return Reflect.field(cppiaClass, fieldName);
  }

  override public function setField(fieldName:String, fieldValue:Dynamic):Dynamic
  {
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
