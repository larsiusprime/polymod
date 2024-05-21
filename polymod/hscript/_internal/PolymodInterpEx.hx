package polymod.hscript._internal;

#if hscript
import hscript.Expr;
import hscript.Interp;
import hscript.Tools;
import polymod.hscript._internal.PolymodExprEx;
import polymod.hscript._internal.PolymodClassDeclEx.PolymodClassImport;

/**
 * Based on code by Ian Harrigan
 * @see https://github.com/ianharrigan/hscript-ex
 */
@:access(polymod.hscript._internal.PolymodScriptClass)
@:access(polymod.hscript._internal.PolymodAbstractScriptClass)
class PolymodInterpEx extends Interp
{
	var targetCls:Class<Dynamic>;

	public function new(targetCls:Class<Dynamic>, proxy:PolymodAbstractScriptClass)
	{
		super();
		_proxy = proxy;
		variables.set("Math", Math);
		variables.set("Std", Std);
		this.targetCls = targetCls;
	}

	function errorEx(e:#if hscriptPos ErrorDefEx #else ErrorEx #end, rethrow = false):Dynamic
	{
		#if hscriptPos var e = new ErrorEx(e, curExpr?.pmin ?? 0, curExpr?.pmax ?? 0, curExpr?.origin ?? 'unknown', curExpr?.line ?? 0); #end
		if (rethrow)
			this.rethrow(e)
		else
			throw e;
		return null;
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
				var importedClass:PolymodClassImport = _proxy._c.imports.get(cl);
				if (_scriptClassDescriptors.exists(importedClass.fullPath))
				{
					// OVERRIDE CHANGE: Create a PolymodScriptClass instead of a hscript.ScriptClass
					var proxy:PolymodAbstractScriptClass = new PolymodScriptClass(_scriptClassDescriptors.get(importedClass.fullPath), args);
					return proxy;
				}

				// Ignore importedClass.enm as enums cannot be instantiated.
				var c = importedClass.cls;
				if (c == null)
				{
					errorEx(EBlacklistedModule(importedClass.fullPath));
				} else {
					return Type.createInstance(c, args);
				}
			}
		}

		// Attempt to resolve the class without overrides.
		var cls = Type.resolveClass(cl);
		if (cls == null)
			cls = resolve(cl);
		if (cls == null)
			errorEx(EInvalidModule(cl));
		return Type.createInstance(cls,args);
	}

	/**
	 * Note to self: Calls to `this.xyz()` will have the type of `o` as `polymod.hscript.PolymodScriptClass`.
	 * Calls to `super.xyz()` will have the type of `o` as `stage.ScriptedStage`.
	 */
	override function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic
	{
		// OVERRIDE CHANGE: Custom logic to handle super calls to prevent infinite recursion
		if (_proxy != null && o == _proxy.superClass)
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

		// Workaround for an HTML5-specific issue.
		// https://github.com/HaxeFoundation/haxe/issues/11298
		if (func == null && f == "contains") {
			func = get(o, "includes");
		}

		if (func == null)
		{
			if (Std.isOfType(o, HScriptedClass))
			{
				// Could not call the function.
				// It might be a custom function on the scripted class,
				// in which case you need to use `scriptCall()` instead.
				errorEx(EInvalidScriptedFnAccess(f));
			}
			else
			{
				// Throw an error for a missing function.
				errorEx(EInvalidAccess(f));
			}
		}
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
			if (_proxy.superHasField(id))
			{
				// Set in super class.
				Reflect.setProperty(_proxy.superClass, id, v);
				return;
			}
		}

		// Fallback to setting in local scope.
		super.setVar(id, v);
	}

	override function assign(e1:Expr, e2:Expr):Dynamic
	{
		switch (Tools.expr(e1))
		{
			case EIdent(id):
				// Make sure setting superclass fields directly works.
				// Also ensures property functions are accounted for.
				if (_proxy != null && _proxy.superClass != null)
				{
					if (_proxy.superHasField(id))
					{
						var v = expr(e2);
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
								if (_proxy.superHasField(id))
								{
									var v = expr(e2);
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

	public override function expr(e:Expr):Dynamic
	{
		// Override to provide some fixes, falling back to super.expr() when not needed.
		#if hscriptPos
		curExpr = e;
		switch (e.e)
		{
		#else
		switch (e)
		{
		#end
			// These overrides are used to handle specific cases where problems occur.

			case EVar(n, _, e): // Fix to ensure local variables are committed properly.
				declared.push({n: n, old: locals.get(n)});
				var result = (e == null) ? null : expr(e);
				locals.set(n, {r: result});
				return null;
			case EFunction(params, fexpr, name, _): // Fix to ensure callback functions catch thrown errors.
				var capturedLocals = duplicate(locals);
				var me = this;
				var hasOpt = false, minParams = 0;
				for (p in params)
				{
					if (p.opt)
					{
						hasOpt = true;
					}
					else
					{
						minParams++;
					}
				}

				// This CREATES a new function in memory, that we call later.
				var newFun = function(args:Array<Dynamic>)
				{
					if (((args == null) ? 0 : args.length) != params.length)
					{
						if (args.length < minParams)
						{
							var str = "Invalid number of parameters. Got " + args.length + ", required " + minParams;
							if (name != null)
								str += " for function '" + name + "'";
							errorEx(ECustom(str));
						}
						// make sure mandatory args are forced
						var args2 = [];
						var extraParams = args.length - minParams;
						var pos = 0;
						for (p in params)
						{
							if (p.opt)
							{
								if (extraParams > 0)
								{
									args2.push(args[pos++]);
									extraParams--;
								}
								else
								{
									args2.push(null);
								}
							}
							else
							{
								args2.push(args[pos++]);
							}
						}
						args = args2;
					}
					var old = me.locals;
					var depth = me.depth;
					me.depth++;
					me.locals = me.duplicate(capturedLocals);
					for (i in 0...params.length)
					{
						me.locals.set(params[i].name, {r: args[i]});
					}
					var r = null;
					var oldDecl = declared.length;
					if (inTry)
					{
						// True if the SCRIPT wraps the function in a try/catch block.
						try
						{
							r = me.exprReturn(fexpr);
						}
						catch (e:Dynamic)
						{
							me.locals = old;
							me.depth = depth;
							#if neko
							neko.Lib.rethrow(e);
							#else
							throw e;
							#end
						}
					}
					else
					{
						// There is no try/catch block. We can add some custom error handling.
						try
						{
							r = me.exprReturn(fexpr);
						}
						catch (err:PolymodExprEx.ErrorEx)
						{
							_proxy.reportErrorEx(err, 'anonymous');
							r = null;
						}
						catch (err:hscript.Expr.Error)
						{
							_proxy.reportError(err, 'anonymous');
							r = null;
						}
						catch (err:Dynamic)
						{
							throw err;
						}
					}
					restore(oldDecl);
					me.locals = old;
					me.depth = depth;
					return r;
				};

				newFun = Reflect.makeVarArgs(newFun);
				if (name != null)
				{
					if (depth == 0)
					{
						// Store the function as a global.
						variables.set(name, newFun);
					}
					else
					{
						// function-in-function is a local function
						declared.push({n: name, old: locals.get(name)});
						var ref = {r: newFun};
						locals.set(name, ref);
						capturedLocals.set(name, ref); // allow self-recursion
					}
				}
				return newFun;
			case ETry(e,n,_,ecatch):
				var old = declared.length;
				var oldTry = inTry;
				try {
					inTry = true;
					var v : Dynamic = expr(e);
					restore(old);
					inTry = oldTry;
					return v;
			} catch( error : PolymodExprEx.ErrorEx ) {
					#if hscriptPos
					var err = error.e;
					#else
					var err = error;
					#end
					switch (err) {
						case EScriptThrow(errValue):
							// restore vars
							restore(old);
							inTry = oldTry;
							// declare 'v'
							declared.push({ n : n, old : locals.get(n) });
							locals.set(n,{ r : errValue });
							var v : Dynamic = expr(ecatch);
							restore(old);
							return v;
						default:
							throw err;
					}
				} catch( err : Dynamic ) {
					// I can't handle this error the normal way because Stop is private GRAAAAA
					if (Type.getEnumName(err) == "hscript.Interp.Stop") {
						inTry = oldTry;
						throw err;
					}

					// restore vars
					restore(old);
					inTry = oldTry;
					// declare 'v'
					declared.push({ n : n, old : locals.get(n) });
					locals.set(n,{ r : err });
					var v : Dynamic = expr(ecatch);
					restore(old);
					return v;
				}
			case EThrow(e):
				var str = 'Script Error: ${expr(e)}';
				// If there is a try/catch block, the error will be caught.
				// If there is no try/catch block, the error will be reported.
				errorEx(EScriptThrow(str));
			default:
				// Do nothing.
		}

		// Default case.
		return super.expr(e);
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
			errorEx(EInvalidIterator(v));
		}
		return v;
	}

	/**
 * Call a given function on a given target with the given arguments.
 * @param target The object to call the function on.
 *   If null, defaults to `this`.
 * @param fun The function to call.
 * @param args The arguments to apply to that function.
 * @return The result of the function call.
 */
	override function call(target:Dynamic, fun:Dynamic, args:Array<Dynamic>):Dynamic
	{
		// Calling fn() in hscript won't resolve an object first. Thus, we need to change it to use this.fn() instead.
		if (target == null && _nextCallObject != null)
		{
			target = _nextCallObject;
		}

		if (fun == null)
		{
			errorEx(EInvalidAccess(fun));
		}

		if (target == _proxy)
		{
			// If we are calling this.fn(), special handling is needed to prevent the local scope from being destroyed.
			// By checking `target == _proxy`, we handle BOTH fn() and this.fn().
			// super.fn() is exempt since it is not scripted.
			return callThis(fun, args);
		}
		else
		{
			try {
				var result = Reflect.callMethod(target, fun, args);
				_nextCallObject = null;
				return result;
			} catch (e) {
				errorEx(EScriptCallThrow(e));
				_nextCallObject = null;
				return null;
			}
		}
	}

	/**
   * Call a given function on the current proxy with the given arguments.
   * Ensures that the local scope is not destroyed.
   * @param fun The function to call.
   * @param args The arguments to apply to that function.
   * @return The result of the function call.
   */
	function callThis(fun:Dynamic, args:Array<Dynamic>):Dynamic
	{
		// If we are calling this.fn(), special handling is needed to prevent the local scope from being destroyed.
		// Store the local scope.
		var capturedLocals = this.duplicate(locals);
		var capturedDeclared = this.declared;
		var capturedDepth = this.depth;

		this.depth++;

		// Call the function.
		try {
			var result = Reflect.callMethod(_proxy, fun, args);

			// Restore the local scope.
			this.locals = capturedLocals;
			this.declared = capturedDeclared;
			this.depth = capturedDepth;

			return result;
		} catch (e) {
			errorEx(EScriptCallThrow(e));

			// Restore the local scope.
			this.locals = capturedLocals;
			this.declared = capturedDeclared;
			this.depth = capturedDepth;

			return null;
		}

	}

	override function execute(expr:Expr):Dynamic
	{
		// If this function is being called (and not executeEx),
		// PolymodScriptClass is not being used to call the expression.
		// This happens during callbacks and in some other niche cases.
		// In this case, we know the parent caller doesn't have error handling!
		// That means we have to do it here.
		try
		{
			return super.execute(expr);
		}
		catch (err:PolymodExprEx.ErrorEx)
		{
			_proxy.reportErrorEx(err, 'anonymous');
			return null;
		}
		catch (err:hscript.Expr.Error)
		{
			_proxy.reportError(err, 'anonymous');
			return null;
		}
		catch (err:Dynamic)
		{
			throw err;
		}
	}

	public function executeEx(expr:Expr):Dynamic
	{
		// Directly call execute (assume error handling happens higher).
		return super.execute(expr);
	}

	override function get(o:Dynamic, f:String):Dynamic
	{
		if (o == null)
			errorEx(EInvalidAccess(f));
		if (Std.isOfType(o, PolymodScriptClass))
		{
			var proxy:PolymodAbstractScriptClass = cast(o, PolymodScriptClass);
			if (proxy._interp.variables.exists(f))
			{
				return proxy._interp.variables.get(f);
			}
			else if (proxy.superClass != null && proxy.superHasField(f))
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
				errorEx(EUnknownVariable(f));
			}
		}
		else if (Std.isOfType(o, HScriptedClass))
		{
			try
			{
				var result = Reflect.getProperty(o, f);
				// I guess there's no way to distinguish between properties that don't exist,
				// and properties that are equal to null?
				if (result == null)
				{
					// To save a bit of performance, we only query for the existence of the property
					// if the value is reported as null, AND only in debug builds.

					#if debug
					if (!Reflect.hasField(o, f))
					{
						var propertyList = Type.getInstanceFields(Type.getClass(o));
						if (propertyList.indexOf(f) == -1)
						{
							errorEx(EInvalidScriptedVarGet(f));
						}
					}
					#end
					return result;
				}
				return result;
			}
			catch (e:Dynamic)
			{
				errorEx(EInvalidScriptedVarGet(f));
			}
		}
		return super.get(o, f);
	}

	override function set(o:Dynamic, f:String, v:Dynamic):Dynamic
	{
		if (o == null)
			errorEx(EInvalidAccess(f));
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
				errorEx(EUnknownVariable(f));
			}
			return v;
		}
		else if (Std.isOfType(o, HScriptedClass))
		{
			try
			{
				Reflect.setProperty(o, f, v);
			}
			catch (e)
			{
				errorEx(EInvalidScriptedVarSet(f));
			}
			return v;
		}

		try
		{
			Reflect.setProperty(o, f, v);
		}
		catch (e)
		{
			errorEx(EInvalidAccess(f));
		}
		return v;
	}

	private var _nextCallObject:Dynamic = null;

	override function exprReturn(expr:Expr):Dynamic
	{
		return super.exprReturn(expr);
		// catch (err:hscript.Expr.Error)
		// {
		// 	#if hscriptPos
		// 	throw err;
		// 	#else
		// 	throw err;
		// 	#end
		// }
	}

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

		if (locals.exists(id))
		{
			// NOTE: id may exist but be null
			return locals.get(id).r;
		}
		if (variables.exists(id))
		{
			// NOTE: id may exist but be null
			return variables.get(id);
		}
		// OVERRIDE CHANGE: Allow access to modules for calling static functions.
		var importedClass:PolymodClassImport = _proxy._c.imports.get(id);
		if (_proxy != null && importedClass != null)
		{
			// TODO: Somehow allow accessing static fields of a ScriptClass without instantiating it.

			if (importedClass.cls != null) return importedClass.cls;
			if (importedClass.enm != null) return importedClass.enm;
		}

		var prop:Dynamic;
		// We are calling a LOCAL function from the same module.
		if (_proxy != null && _proxy.findFunction(id, true) != null)
		{
			_nextCallObject = _proxy;
			return _proxy.resolveField(id);
		}
		else if (_proxy != null && _proxy.superHasField(id))
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
			errorEx(EUnknownVariable(id));
		}
		else
		{
			errorEx(EUnknownVariable(id));
		}
		return null;
	}

	public function addModule(moduleContents:String, ?origin:String = "hscript")
	{
		var parser = new PolymodParserEx();
		var decls = parser.parseModule(moduleContents, origin);
		registerModule(decls, origin);
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
		else
		{
			Polymod.error(SCRIPT_CLASS_NOT_REGISTERED, 'Scripted class $className has not been defined.');
		}
		return null;
	}

	public function registerModule(module:Array<ModuleDecl>, ?origin:String = "hscript")
	{
		var pkg:Array<String> = null;
		var imports:Map<String, PolymodClassImport> = [];

		for (importPath in PolymodScriptClass.defaultImports.keys())
		{
			var splitPath = importPath.split(".");
			var clsName = splitPath[splitPath.length - 1];

			imports.set(clsName, {
				name: clsName,
				pkg: splitPath.slice(0, splitPath.length - 1),
				fullPath: importPath,
				cls: PolymodScriptClass.defaultImports.get(importPath),
			});
		}

		for (decl in module)
		{
			switch (decl)
			{
				case DPackage(path):
					pkg = path;
				case DImport(path, _):
					var clsName = path[path.length - 1];

					if (imports.exists(clsName))
					{
						if (imports.get(clsName) == null) {
							Polymod.error(SCRIPT_CLASS_MODULE_BLACKLISTED, 'Scripted class ${clsName} is blacklisted and cannot be used in scripts.', origin);
						} else {
							Polymod.warning(SCRIPT_CLASS_MODULE_ALREADY_IMPORTED, 'Scripted class ${clsName} has already been imported.', origin);
						}
						continue;
					}

					var importedClass:PolymodClassImport = {
						name: clsName,
						pkg: path.slice(0, path.length - 1),
						fullPath: path.join("."),
						cls: null,
						enm: null
					};

					if (PolymodScriptClass.importOverrides.exists(importedClass.fullPath)) {
						// importOverrides can exist but be null (if it was set to null).
						// If so, that means the class is blacklisted.

						importedClass.cls = PolymodScriptClass.importOverrides.get(importedClass.fullPath);
					} else {
						var resultCls:Class<Dynamic> = Type.resolveClass(importedClass.fullPath);

						// If the class is not found, try to find it as an enum.
						var resultEnm:Enum<Dynamic> = null;
						if (resultCls == null)
							resultEnm = Type.resolveEnum(importedClass.fullPath);

						// If the class is still not found, skip this import entirely.
						if (resultCls == null && resultEnm == null) {
							Polymod.error(SCRIPT_CLASS_MODULE_NOT_FOUND, 'Could not import class ${importedClass.fullPath}', origin);
							continue;
						} else if (resultCls != null) {
							importedClass.cls = resultCls;
						} else if (resultEnm != null) {
							importedClass.enm = resultEnm;
						}
					}

					imports.set(importedClass.name, importedClass);
				case DClass(c):
					var extend = c.extend;
					if (extend != null)
					{
						var superClassPath = new hscript.Printer().typeToString(extend);
						if (!imports.exists(superClassPath)) {
							switch (extend) {
								case CTPath(path, params):
									if (params.length > 0) {
										errorEx(EClassUnresolvedSuperclass(superClassPath, 'do not include type parameters in super class name'));
									}
								default:
									// Other error handling?
							}
							// Default
							errorEx(EClassUnresolvedSuperclass(superClassPath, 'not recognized, is the type imported?'));
						}

						if (imports.exists(superClassPath))
						{
							var extendImport = imports.get(superClassPath);
							if (extendImport.cls == null)
								errorEx(EClassUnresolvedSuperclass(superClassPath, 'expected a class'));

							switch (extend)
							{
								case CTPath(_, params):
									extend = CTPath(imports.get(superClassPath).fullPath.split('.'), params);
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
#end
