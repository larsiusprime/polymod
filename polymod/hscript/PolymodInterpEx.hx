package polymod.hscript;
#if hscript_ex
import hscript.AbstractScriptClass;
import hscript.Interp;

/**
 * Based on code by Ian Harrigan
 * @see https://github.com/ianharrigan/hscript-ex
 */
@:access(polymod.hscript.PolymodScriptClass)
@:access(polymod.hscript.PolymodAbstractScriptClass)
class PolymodInterpEx extends Interp {
  var targetCls:Class<Dynamic>;
  public function new(targetCls:Class<Dynamic>, proxy:AbstractScriptClass) {
    super(proxy);
    this.targetCls = targetCls;
  }

  override function cnew(cl:String, args:Array<Dynamic>):Dynamic {
    if (_scriptClassDescriptors.exists(cl)) {
      // OVERRIDE CHANGE: Create a PolymodScriptClass instead of a hscript.ScriptClass
			var proxy:AbstractScriptClass = new PolymodScriptClass(_scriptClassDescriptors.get(cl), args);
			return proxy;
		} else if (_proxy != null) {
      @:privateAccess
			if (_proxy._c.pkg != null) {
        @:privateAccess
				var packagedClass = _proxy._c.pkg.join(".") + "." + cl;
				if (_scriptClassDescriptors.exists(packagedClass)) {
          // OVERRIDE CHANGE: Create a PolymodScriptClass instead of a hscript.ScriptClass
					var proxy:AbstractScriptClass = new PolymodScriptClass(_scriptClassDescriptors.get(packagedClass), args);
					return proxy;
				}
			}

      @:privateAccess
			if (_proxy._c.imports != null && _proxy._c.imports.exists(cl)) {
				var importedClass = _proxy._c.imports.get(cl).join(".");
				if (_scriptClassDescriptors.exists(importedClass)) {
          // OVERRIDE CHANGE: Create a PolymodScriptClass instead of a hscript.ScriptClass
					var proxy:AbstractScriptClass = new PolymodScriptClass(_scriptClassDescriptors.get(importedClass), args);
					return proxy;
				}

				var c = Type.resolveClass(importedClass);
				if (c != null) {
					return Type.createInstance(c, args);
				}
			}
		}
		return super.cnew(cl, args);
	}

  /**
   * Note to self: Calls to `this.xyz()` will have the type of `o` as `polymod.hscript.PolymodScriptClass`.
   * Calls to `super.xyz()` will have the type of `o` as `stage.ScriptedStage`.
   */
  override function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic {
    // OVERRIDE CHANGE: Custom logic to handle super calls to prevent infinite recursion
    // trace('fcall: ${Type.typeof(o)}.${f}()');
    // trace('compare: ${targetCls}');
		if (Std.isOfType(o, targetCls)) {
      // Force call super function.
      //trace('Force call to __super_');
      return super.fcall(o, '__super_${f}', args);  
    } else if (Std.isOfType(o, PolymodScriptClass)) {
			_nextCallObject = null;
      //trace('Fix call to self');
			var proxy:PolymodScriptClass = cast(o, PolymodScriptClass);
			return proxy.callFunction(f, args);
		}
    //trace('Call to other function');
		return super.fcall(o, f, args);
	}

  private var _proxy:AbstractScriptClass = null;

	public function new(proxy:AbstractScriptClass = null) {
		super();
		_proxy = proxy;
		variables.set("Type", Type);
		variables.set("Math", Math);
		variables.set("Std", Std);
	}

	private static var _scriptClassDescriptors:Map<String, ClassDeclEx> = new Map<String, ClassDeclEx>();
	private static var _scriptClassOverrides:Map<String, Class<Dynamic>> = new Map<String, Class<Dynamic>>();

	private static function registerScriptClass(c:ClassDeclEx) {
		var name = c.name;
		if (c.pkg != null) {
			name = c.pkg.join(".") + "." + name;
		}
		_scriptClassDescriptors.set(name, c);
	}

	public static function findScriptClassDescriptor(name:String) {
		return _scriptClassDescriptors.get(name);
	}

	override function assign(e1:Expr, e2:Expr):Dynamic {
		var v = expr(e2);
		switch (Tools.expr(e1)) {
			case EIdent(id):
				if (_proxy.superClass != null && Reflect.hasField(_proxy.superClass, id)) {
					Reflect.setProperty(_proxy.superClass, id, v);
					return v;
				}
			case _:
		}
		return super.assign(e1, e2);
	}

	override function call(o:Dynamic, f:Dynamic, args:Array<Dynamic>):Dynamic {
		// TODO: not sure if this make sense !! seems hacky, but fn() in hscript wont resolve an object first (this.fn() or super.fn() would work fine)
		if (o == null && _nextCallObject != null) {
			o = _nextCallObject;
		}
		var r = super.call(o, f, args);
		_nextCallObject = null;
		return r;
	}

	override function get(o:Dynamic, f:String):Dynamic {
		trace('get ${f}');
		if (o == null)
			error(EInvalidAccess(f));
		if (Std.is(o, ScriptClass)) {
			var proxy:AbstractScriptClass = cast(o, ScriptClass);
			if (proxy._interp.variables.exists(f)) {
				return proxy._interp.variables.get(f);
			} else if (proxy.superClass != null && Reflect.hasField(proxy.superClass, f)) {
				return Reflect.getProperty(proxy.superClass, f);
			} else {
				try {
					return proxy.resolveField(f);
				} catch (e:Dynamic) {}
				error(EUnknownVariable(f));
			}
		}
		return super.get(o, f);
	}

	override function set(o:Dynamic, f:String, v:Dynamic):Dynamic {
		if (o == null)
			error(EInvalidAccess(f));
		if (Std.is(o, ScriptClass)) {
			var proxy:ScriptClass = cast(o, ScriptClass);
			if (proxy._interp.variables.exists(f)) {
				proxy._interp.variables.set(f, v);
			} else if (proxy.superClass != null && Reflect.hasField(proxy.superClass, f)) {
				Reflect.setProperty(proxy.superClass, f, v);
			} else {
				error(EUnknownVariable(f));
			}
			return v;
		}
		return super.set(o, f, v);
	}

	private var _nextCallObject:Dynamic = null;

	override function resolve(id:String):Dynamic {
		trace('resolve ${id}');
		_nextCallObject = null;
		if (id == "super" && _proxy != null) {
			if (_proxy.superClass == null) {
				return _proxy.superConstructor;
			} else {
				return _proxy.superClass;
			}
		} else if (id == "this" && _proxy != null) {
			return _proxy;
		}

		var l = locals.get(id);
		if (l != null) {
			trace('returning local');
			return l.r;
		}
		var v = variables.get(id);
		if (v != null) {
			trace('returning variable');
			return v;
		}
    // OVERRIDE CHANGE: Allow access to modules for calling static functions.
    var m = _proxy._c.imports.get(id);
    if (m != null) {
      var importedClass = m.join(".");

      trace('returning imported module ${importedClass}');

      // TODO: Somehow allow accessing static fields of a ScriptClass without instantiating it.

      return Type.resolveClass(importedClass);
    }

		if (_proxy != null && _proxy.findFunction(id) != null) {
			_nextCallObject = _proxy;
			trace('returning resolve');
			return _proxy.resolveField(id);
		} else if (_proxy != null
			&& _proxy.superClass != null
			&& (Reflect.hasField(_proxy.superClass, id) || Reflect.getProperty(_proxy.superClass, id) != null)) {
			_nextCallObject = _proxy.superClass;
      trace('returning reflect');
			return Reflect.getProperty(_proxy.superClass, id);
		} else if (_proxy != null) {
			try {
				var r = _proxy.resolveField(id);
				_nextCallObject = _proxy;
        trace('returning proxy resolve');
				return r;
			} catch (e:Dynamic) {}
			trace('unknown variable and nonnull proxy');
			error(EUnknownVariable(id));
		} else {
			trace('unknown variable and null proxy');
			error(EUnknownVariable(id));
		}
    return null;
	}

	public function addModule(moduleContents:String) {
		var parser = new hscript.ParserEx();
		var decls = parser.parseModule(moduleContents);
		registerModule(decls);
	}

	public function createScriptClassInstance(className:String, args:Array<Dynamic> = null):AbstractScriptClass {
		if (args == null) {
			args = [];
		}
		var r:AbstractScriptClass = cnew(className, args);
		return r;
	}

	public function registerModule(module:Array<ModuleDecl>) {
		var pkg:Array<String> = null;
		var imports:Map<String, Array<String>> = [];
		for (decl in module) {
			switch (decl) {
				case DPackage(path):
					pkg = path;
				case DImport(path, _):
					var last = path[path.length - 1];
					imports.set(last, path);
				case DClass(c):
					var extend = c.extend;
					if (extend != null) {
						var superClassPath = new Printer().typeToString(extend);
						if (imports.exists(superClassPath)) {
							switch (extend) {
								case CTPath(_, params):
									extend = CTPath(imports.get(superClassPath), params);
								case _:
							}
						}
					}
					var classDecl:ClassDeclEx = {
						imports: imports,
						pkg: pkg,
						name: c.name,
						params: c.params,
						meta: c.meta,
						isPrivate: c.isPrivate,
						extend: extend,
						implement: c.implement,
						fields: c.fields,
						isExtern: c.isExtern
					};
					registerScriptClass(classDecl);
				case DTypedef(_):
			}
		}
	}
}
#end