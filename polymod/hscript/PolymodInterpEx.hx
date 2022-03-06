package polymod.hscript;

import hscript.Interp;
import hscript.Expr;
import hscript.Tools;

/**
 * Based on code by Ian Harrigan
 * @see https://github.com/ianharrigan/hscript-ex
 */
@:access(polymod.hscript.PolymodScriptClass)
@:access(polymod.hscript.PolymodAbstractScriptClass)
class PolymodInterpEx extends Interp
{
	var targetCls:Class<Dynamic>;

	public function new(targetCls:Class<Dynamic>, proxy:PolymodAbstractScriptClass)
	{
		super();
		_proxy = proxy;
		variables.set("Type", Type);
		variables.set("Math", Math);
		variables.set("Std", Std);
		this.targetCls = targetCls;
	}

	override function cnew(cl:String, args:Array<Dynamic>):Dynamic
	{
		if (_scriptClassDescriptors.exists(cl))
		{
			// OVERRIDE CHANGE: Create a PolymodScriptClass instead of a hscript.ScriptClass
			var proxy:PolymodAbstractScriptClass = new PolymodScriptClass(_scriptClassDescriptors.get(cl), args);
			return proxy;
		}
		else if (_proxy != null)
		{
			@:privateAccess
			if (_proxy._c.pkg != null)
			{
				@:privateAccess
				var packagedClass = _proxy._c.pkg.join(".") + "." + cl;
				if (_scriptClassDescriptors.exists(packagedClass))
				{
					// OVERRIDE CHANGE: Create a PolymodScriptClass instead of a hscript.ScriptClass
					var proxy:PolymodAbstractScriptClass = new PolymodScriptClass(_scriptClassDescriptors.get(packagedClass), args);
					return proxy;
				}
			}

			@:privateAccess
			if (_proxy._c.imports != null && _proxy._c.imports.exists(cl))
			{
				var importedClass = _proxy._c.imports.get(cl).join(".");
				if (_scriptClassDescriptors.exists(importedClass))
				{
					// OVERRIDE CHANGE: Create a PolymodScriptClass instead of a hscript.ScriptClass
					var proxy:PolymodAbstractScriptClass = new PolymodScriptClass(_scriptClassDescriptors.get(importedClass), args);
					return proxy;
				}

				var c = Type.resolveClass(importedClass);
				if (c != null)
				{
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
	override function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic
	{
		// OVERRIDE CHANGE: Custom logic to handle super calls to prevent infinite recursion
		if (Std.isOfType(o, targetCls))
		{
			// Force call super function.
			return super.fcall(o, '__super_${f}', args);
		}
		else if (Std.isOfType(o, PolymodScriptClass))
		{
			_nextCallObject = null;
			var proxy:PolymodScriptClass = cast(o, PolymodScriptClass);
			return proxy.callFunction(f, args);
		}

		var func = get(o, f);
		if (func == null)
			error(EInvalidAccess(f));
		return call(o, func, args);
	}

	private var _proxy:PolymodAbstractScriptClass = null;

	private static var _scriptClassDescriptors:Map<String, PolymodClassDeclEx> = new Map<String, PolymodClassDeclEx>();

	private static function registerScriptClass(c:PolymodClassDeclEx)
	{
		var name = c.name;
		if (c.pkg != null)
		{
			name = c.pkg.join(".") + "." + name;
		}
		_scriptClassDescriptors.set(name, c);
	}

	public static function findScriptClassDescriptor(name:String)
	{
		return _scriptClassDescriptors.get(name);
	}

	override function setVar(id:String, v:Dynamic)
	{
		if (_proxy != null && _proxy.superClass != null)
		{
			if (Reflect.hasField(_proxy.superClass, id))
			{
				// Set in super class.
				Reflect.setProperty(_proxy.superClass, id, v);
				return;
			}
			else if (Type.getInstanceFields(Type.getClass(_proxy.superClass)).contains(id))
			{
				// Set in super class (alternate).
				Reflect.setProperty(_proxy.superClass, id, v);
				return;
			}
		}

		// Fallback to setting in local scope.
		super.setVar(id, v);
	}

	override function assign(e1:Expr, e2:Expr):Dynamic
	{
		return super.assign(e1, e2);
		var v = expr(e2);

		switch (Tools.expr(e1))
		{
			case EIdent(id):
				// Make sure setting superclass fields directly works.
				// Also ensures property functions are accounted for.
				if (_proxy != null && _proxy.superClass != null)
				{
					if (Reflect.hasField(_proxy.superClass, id))
					{
						Reflect.setProperty(_proxy.superClass, id, v);
						return v;
					}
					else if (Type.getInstanceFields(Type.getClass(_proxy.superClass)).contains(id))
					{
						Reflect.setProperty(_proxy.superClass, id, v);
						return v;
					}
				}
			case EField(e0, id):
				// Make sure setting superclass fields works when using this.
				// Also ensures property functions are accounted for.
				switch (Tools.expr(e0))
				{
					case EIdent(id0):
						if (id0 == "this")
						{
							if (_proxy != null && _proxy.superClass != null)
							{
								if (Reflect.hasField(_proxy.superClass, id))
								{
									Reflect.setProperty(_proxy.superClass, id, v);
									return v;
								}
								else if (Type.getInstanceFields(Type.getClass(_proxy.superClass)).contains(id))
								{
									Reflect.setProperty(_proxy.superClass, id, v);
									return v;
								}
							}
						}
					default:
						// Do nothing
				}
			default:
		}
		// Fallback, which calls set()
		return super.assign(e1, e2);
	}

	override function makeIterator(v:Dynamic):Iterator<Dynamic>
	{
		if (v.iterator != null)
		{
			try
			{
				v = v.iterator();
			}
			catch (e:Dynamic)
			{
			};
		}
		if (Std.isOfType(v, Array))
		{
			v = new ArrayIterator(v);
		}
		if (v.hasNext == null || v.next == null)
		{
			error(EInvalidIterator(v));
		}
		return v;
	}

	override function call(o:Dynamic, f:Dynamic, args:Array<Dynamic>):Dynamic
	{
		// TODO: not sure if this make sense !! seems hacky, but fn() in hscript wont resolve an object first (this.fn() or super.fn() would work fine)
		if (o == null && _nextCallObject != null)
		{
			o = _nextCallObject;
		}

		if (f == null)
		{
			error(EInvalidAccess(f));
		}

		var r = Reflect.callMethod(o, f, args);
		_nextCallObject = null;
		return r;
	}

	override function get(o:Dynamic, f:String):Dynamic
	{
		if (o == null)
			error(EInvalidAccess(f));
		if (Std.isOfType(o, PolymodScriptClass))
		{
			var proxy:PolymodAbstractScriptClass = cast(o, PolymodScriptClass);
			if (proxy._interp.variables.exists(f))
			{
				return proxy._interp.variables.get(f);
			}
			else if (proxy.superClass != null && Reflect.hasField(proxy.superClass, f))
			{
				return Reflect.getProperty(proxy.superClass, f);
			}
			else if (proxy.superClass != null && Type.getInstanceFields(Type.getClass(_proxy.superClass)).contains(f))
			{
				return Reflect.getProperty(proxy.superClass, f);
			}
			else
			{
				try
				{
					return proxy.resolveField(f);
				}
				catch (e:Dynamic)
				{
				}
				error(EUnknownVariable(f));
			}
		}
		return super.get(o, f);
	}

	override function set(o:Dynamic, f:String, v:Dynamic):Dynamic
	{
		if (o == null)
			error(EInvalidAccess(f));
		if (Std.isOfType(o, PolymodScriptClass))
		{
			var proxy:PolymodScriptClass = cast(o, PolymodScriptClass);
			if (proxy._interp.variables.exists(f))
			{
				proxy._interp.variables.set(f, v);
			}
			else if (proxy.superClass != null && Reflect.hasField(proxy.superClass, f))
			{
				Reflect.setProperty(proxy.superClass, f, v);
			}
			else if (proxy.superClass != null && Type.getInstanceFields(Type.getClass(_proxy.superClass)).contains(f))
			{
				Reflect.setProperty(proxy.superClass, f, v);
			}
			else
			{
				error(EUnknownVariable(f));
			}
			return v;
		}
		return super.set(o, f, v);
	}

	private var _nextCallObject:Dynamic = null;

	override function resolve(id:String):Dynamic
	{
		_nextCallObject = null;
		if (id == "super" && _proxy != null)
		{
			if (_proxy.superClass == null)
			{
				return _proxy.superConstructor;
			}
			else
			{
				return _proxy.superClass;
			}
		}
		else if (id == "this" && _proxy != null)
		{
			return _proxy;
		}
		else if (id == "null")
		{
			return null;
		}

		var l = locals.get(id);
		if (l != null)
		{
			return l.r;
		}
		var v = variables.get(id);
		if (v != null)
		{
			return v;
		}
		// OVERRIDE CHANGE: Allow access to modules for calling static functions.
		if (_proxy != null && _proxy._c.imports.get(id) != null)
		{
			var importedClass = _proxy._c.imports.get(id).join(".");

			// TODO: Somehow allow accessing static fields of a ScriptClass without instantiating it.

			var result:Dynamic = Type.resolveClass(importedClass);
			if (result != null)
				return result;

			// If the class is not found, try to find it as an enum.
			result = Type.resolveEnum(importedClass);
			if (result != null)
				return result;
		}

		if (_proxy != null && _proxy.findFunction(id) != null)
		{
			_nextCallObject = _proxy;
			return _proxy.resolveField(id);
		}
		else if (_proxy != null
			&& _proxy.superClass != null
			&& (Reflect.hasField(_proxy.superClass, id) || Reflect.getProperty(_proxy.superClass, id) != null))
		{
			_nextCallObject = _proxy.superClass;
			return Reflect.getProperty(_proxy.superClass, id);
		}
		else if (_proxy != null)
		{
			try
			{
				var r = _proxy.resolveField(id);
				_nextCallObject = _proxy;
				return r;
			}
			catch (e:Dynamic)
			{
			}
			error(EUnknownVariable(id));
		}
		else
		{
			error(EUnknownVariable(id));
		}
		return null;
	}

	public function addModule(moduleContents:String)
	{
		var parser = new polymod.hscript.PolymodParserEx();
		var decls = parser.parseModule(moduleContents);
		registerModule(decls);
	}

	public function createScriptClassInstance(className:String, args:Array<Dynamic> = null):PolymodAbstractScriptClass
	{
		if (args == null)
		{
			args = [];
		}
		if (_scriptClassDescriptors.exists(className))
		{
			// OVERRIDE CHANGE: Create a PolymodScriptClass instead of a hscript.ScriptClass
			var proxy:PolymodAbstractScriptClass = new PolymodScriptClass(_scriptClassDescriptors.get(className), args);
			return proxy;
		}
		return null;
	}

	public function registerModule(module:Array<ModuleDecl>)
	{
		var pkg:Array<String> = null;
		var imports:Map<String, Array<String>> = [];
		for (decl in module)
		{
			switch (decl)
			{
				case DPackage(path):
					pkg = path;
				case DImport(path, _):
					var last = path[path.length - 1];
					imports.set(last, path);
				case DClass(c):
					var extend = c.extend;
					if (extend != null)
					{
						var superClassPath = new hscript.Printer().typeToString(extend);
						if (imports.exists(superClassPath))
						{
							switch (extend)
							{
								case CTPath(_, params):
									extend = CTPath(imports.get(superClassPath), params);
								case _:
							}
						}
					}
					var classDecl:PolymodClassDeclEx = {
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

private class ArrayIterator<T>
{
	var a:Array<T>;
	var pos:Int;

	public inline function new(a)
	{
		this.a = a;
		this.pos = 0;
	}

	public inline function hasNext()
	{
		return pos < a.length;
	}

	public inline function next()
	{
		return a[pos++];
	}
}
