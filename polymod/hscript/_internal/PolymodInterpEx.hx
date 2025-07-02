package polymod.hscript._internal;

#if hscript
import hscript.Expr;
import hscript.Interp;
import hscript.Tools;
import polymod.hscript._internal.PolymodClassDeclEx;
import polymod.hscript._internal.PolymodExprEx;

/**
 * Based on code by Ian Harrigan
 * @see https://github.com/ianharrigan/hscript-ex
 */
@:access(polymod.hscript._internal.PolymodScriptClass)
class PolymodInterpEx extends Interp
{
	public var scriptManager(get, never):PolymodScriptManager;

	public function get_scriptManager():PolymodScriptManager
	{
		return PolymodScriptManager.instance;
	}

	private var _proxy:PolymodScriptClass = null;

	private var _overrideProxies:Array<PolymodScriptClass> = [];

	private function getProxy():PolymodScriptClass
	{
		if (_overrideProxies.length >= 1)
			return _overrideProxies[_overrideProxies.length - 1]
		else 
			return _proxy;
	}

	public function new(proxy:PolymodScriptClass)
	{
		super();
		_proxy = proxy;
		variables.set('Math', Math);
		variables.set('Std', Std);
	}

	override function cnew(cls:String, args:Array<Dynamic>):Dynamic
	{
		if (getProxy() != null)
		{
			if (getProxy()._c.imports.exists(cls))
			{
				var imp = getProxy()._c.imports.get(cls);

				if (imp.cls != null)
				{
					if (imp.cls == PolymodScriptClass)
						return new PolymodScriptClass(scriptManager.scriptClassDecls.get(imp.fullPath), args);
					else
						return Type.createInstance(imp.cls, args);
				}

				if (imp.enm != null)
				{
					errorEx(ECustom('Cannot instantiate an enum'));
					return null;
				}
			}

			var clsPath = getProxy().getFullyQualifiedPath(cls);
			if (scriptManager.scriptClassDecls.exists(clsPath))
				return new PolymodScriptClass(scriptManager.scriptClassDecls.get(clsPath), args);
		}

		var clsType = Type.resolveClass(cls);
		if (clsType == null)
			clsType = resolve(cls);
		if (clsType == null)
			errorEx(EInvalidModule(cls));
		return Type.createInstance(clsType, args);
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

			case EVar(name, type, expression):
				// Fix to ensure local variables are committed properly.
				declared.push({n: name, old: locals.get(name)});

				// Evaluate the expression before assigning, applying typing if possible.
				var result = (expression != null) ? exprWithType(expression, type) : null;

				locals.set(name, {r: result});
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
							var str = 'Invalid number of parameters. Got ' + args.length + ', required ' + minParams;
							if (name != null)
								str += ' for function "' + name + '"';
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
							getProxy().reportErrorEx(err, 'anonymous');
							r = null;
						}
						catch (err:hscript.Expr.Error)
						{
							getProxy().reportError(err, 'anonymous');
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
			case EArrayDecl(arr):
				// Initialize an array (or map) from a declaration.
				var hasElements = arr.length > 0;
				var hasMapElements = (hasElements && Tools.expr(arr[0]).match(EBinop('=>', _)));

				if( hasMapElements ) {
					return exprMap(arr);
				} else {
					return exprArray(arr);
				}
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
					if (Type.getEnumName(err) == 'hscript.Interp.Stop') {
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
			case EField(e, f):
				switch (Tools.expr(e))
				{
					case EIdent(v):
						var o = expr(e);

						if (o == PolymodScriptClass)
						{
							var classPath = v;
							if (getProxy()._c.imports.exists(v))
								classPath = getProxy()._c.imports.get(v).fullPath;
							return scriptManager.staticFieldRead(classPath, f);
						} 
						else 
						{
							return get(o, f);
						}
					default:
						return get(expr(e), f);
				}
			case ECall(e, params):
				switch (Tools.expr(e))
				{
					case EField(e, f):
						switch (Tools.expr(e))
						{
							case EIdent(id):
								var classPath:Null<String> = null;

								if (id == getProxy()._c.name)
									classPath = getProxy().getFullyQualifiedPath(id);
								else if (getProxy()._c.imports.get(id)?.cls == PolymodScriptClass)
									classPath = getProxy()._c.imports.get(id).fullPath;

								if (classPath != null)
									return scriptManager.staticCallFunction(classPath, f, getArgs(params, false));
							default:
						}
						var o = expr(e);

						if (o == null) 
							errorEx(EInvalidAccess(f));

						if (Std.isOfType(o, PolymodScriptClass))
						{
							var scriptClass:PolymodScriptClass = cast(o, PolymodScriptClass);
							if (!scriptClass.regularSuperHasField(f))
								return fcall(o, f, getArgs(params, false));
						}

						return fcall(o, f, getArgs(params, true));
					case EIdent(id):
						if (id == 'trace')
							return call(null, expr(e), getArgs(params, false));
						else if (getProxy() != null && getProxy().findField(id) != null)
							return callThis(expr(e), getProxy().regularSuperHasField(id) ? getArgs(params, true) : getArgs(params, false));
						else if (getProxy() != null && getProxy().regularSuperHasField(id))
							return call(getProxy().getRegularSuper(), expr(e), getArgs(params, true));
						else if (getProxy() != null && scriptManager.staticFieldExists(getProxy().getFullyQualifiedPath(getProxy()._c.name), id))
							return scriptManager.staticCallFunction(getProxy().getFullyQualifiedPath(getProxy()._c.name), id, getArgs(params, false));
						else
							return call(null, expr(e), getArgs(params, true));
					default:
						return call(null, expr(e), getArgs(params,  true));
				}
			default:
				// Do nothing.
		}

		// Default case.
		return super.expr(e);
	}

	/**
	 * Parse an expression, but optionally utilizing additional provided type information.
	 * @param e The expression to parse.
	 * @param t The explicit type of the expression, if provided.
	 * @return The parsed expression.
	 */
	public function exprWithType(e:Expr, ?t:CType):Dynamic 
	{
		if (t == null) {
			return this.expr(e);
		}

		#if hscriptPos
		curExpr = e;
		switch (e.e)
		{
		#else
		switch (e)
		{
		#end
			case EArrayDecl(arr):
				// Initialize an array (or map) from a declaration.
				var hasElements = arr.length > 0;
				var hasMapElements = (hasElements && Tools.expr(arr[0]).match(EBinop("=>", _)));
				var hasArrayElements = (hasElements && !hasMapElements);

				switch (t) {
					case CTPath(path, params):
						if (path.length > 0) {
							var last = path[path.length - 1];
							if (last == "Map") {
								if (!hasElements) {
									// Properly handle maps with no keys.
									return this.makeMapEmpty(params[0]);
								}
								else if (hasMapElements) {
									// Properly handle maps with no keys.
									return exprMap(arr);
								} else {
									#if hscriptPos
									curExpr = e;
									#end
									var error = 'Invalid expression in map initialization (expected key=>value, got ${hscript.Printer.toString(e)})';
									errorEx(ECustom(error));
								}
							} else if (last == "Array") {
								if (!hasElements) {
									// Create an empty Array<Dynamic>.
									return exprArray([]);
								}
								if (hasArrayElements) {
									// Create an array of elements.
									return exprArray(arr);
								} else {
									#if hscriptPos
									curExpr = e;
									#end
									var error = 'Invalid expression in array initialization (expected no key=>value pairs, got ${hscript.Printer.toString(e)})';
									errorEx(ECustom(error));
								}
							} else {
								// Whatever.
							}
						}
					default:
						// Whatever.
				}

			default:
				// Whatever.
		}

		// Fallthrough.
		return this.expr(e);
	}

	function exprMap(entries:Array<Expr>):Dynamic 
	{
		if (entries.length == 0) return super.makeMap([],[]);

		var keys = [];
		var values = [];
		for( e in entries ) {
			switch(Tools.expr(e)) {
				case EBinop("=>", eKey, eValue):
					// Look for map entries.
					keys.push(expr(eKey));
					values.push(expr(eValue));
				default:
					// Complain about anything else.
					// This error message has been modified to provide more information.
					#if hscriptPos
					curExpr = e;
					#end
					var error = 'Invalid expression in map initialization (expected key=>value, got ${hscript.Printer.toString(e)})';
					errorEx(ECustom(error));
			}
		}

		return super.makeMap(keys, values);
	}

	function makeMapEmpty(keyType:CType):Dynamic 
	{
		switch (keyType) {
			case CTPath(path, params):
				if (path.length > 0) {
					var last = path[path.length - 1];
					switch (last) {
						case "Int":
							return new Map<Int, Dynamic>();
						case "String":
							return new Map<String, Dynamic>();
						default:
							// TODO: Properly handle distinguishing Enum maps from Object maps.
							return new Map<{}, Dynamic>();
					}
				}
			default:
				// Whatever.
				error(ECustom('Invalid key type for empty map initialization (${new hscript.Printer().typeToString(keyType)}).'));
		}
		return super.makeMap([], []);
	}

	function exprArray(entries:Array<Expr>):Dynamic 
	{
		// Create an Array<Dynamic>
		var a = new Array();
		for( e in entries )
			a.push(expr(e));
		return a;
	}

	override function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic
	{
		if (Std.isOfType(o, PolymodScriptClass))
		{
			var proxy:PolymodScriptClass = cast(o, PolymodScriptClass);
			return proxy.callFunction(f, args);
		}

		var func = get(o, f);

		// Workaround for an HTML5-specific issue.
		// https://github.com/HaxeFoundation/haxe/issues/11298
		if (func == null && f == "contains")
			func = get(o, "includes");

		if (func == null)
			errorEx(EInvalidAccess(f));

		return call(o, func, args);
	}

		/**
 	 * Call a given function on a given target with the given arguments.
 	 * @param target The object to call the function on.
 	 * @param fun The function to call.
 	 * @param args The arguments to apply to that function.
 	 * @return The result of the function call.
 	 */
	override function call(target:Dynamic, fun:Dynamic, args:Array<Dynamic>):Dynamic
	{
		if (fun == null)
			errorEx(EInvalidAccess(fun));

		try 
		{
			var result = Reflect.callMethod(target, fun, args);
			return result;
		} 
		catch (e) 
		{
			errorEx(EScriptCallThrow(e));
			return null;
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
		try 
		{
			var result = Reflect.callMethod(getProxy(), fun, args);

			// Restore the local scope.
			this.locals = capturedLocals;
			this.declared = capturedDeclared;
			this.depth = capturedDepth;

			return result;
		} 
		catch (e) 
		{
			errorEx(EScriptCallThrow(e));

			// Restore the local scope.
			this.locals = capturedLocals;
			this.declared = capturedDeclared;
			this.depth = capturedDepth;

			return null;
		}
	}

	override function get(o:Dynamic, f:String):Dynamic
	{
		if (o == null) 
			errorEx(EInvalidAccess(f));

		if (Std.isOfType(o, PolymodScriptClass))
		{
			var proxy:PolymodScriptClass = cast o;
			try 
			{
				return proxy.fieldRead(f);
			}
			catch (e:Dynamic)
			{
				errorEx(EUnknownVariable(f));
			}	
		}

		// Default behavior
		try
		{
			return Reflect.getProperty(o, f);
		}
		catch (e:Dynamic) {}
		return null;
	}

	override function set(o:Dynamic, f:String, v:Dynamic):Dynamic
	{
		if (o == null)
			errorEx(EInvalidAccess(f));

		if (Std.isOfType(o, PolymodScriptClass))
		{
			var proxy:PolymodScriptClass = cast o;
			try
			{
				return proxy.fieldWrite(f, v);
			}
			catch (e:Dynamic)
			{
				errorEx(EUnknownVariable(f));
			}
			return v;
		}

		// Default behavior
		try
		{
			Reflect.setProperty(o, f, v);
		}
		catch (e:Dynamic) {}
		return v;
	}

	override function assign(e1:Expr, e2:Expr):Dynamic
	{
		if (getProxy() != null)
		{
			switch (Tools.expr(e1))
			{
				case EIdent(id):
					// Make sure setting superclass fields directly works.
					// Also ensures property functions are accounted for.
					if (getProxy().getRegularSuper() != null)
					{
						if (getProxy().regularSuperHasField(id))
						{
							var v = expr(e2);
							Reflect.setProperty(getProxy().getRegularSuper(), id, v);
							return v;
						}
					}

					var classPath = getProxy().getFullyQualifiedPath(getProxy()._c.name);
					if (scriptManager.staticFieldExists(classPath, id))
					{
						var v = expr(e2);
						return scriptManager.staticFieldWrite(classPath, id, v);
					}
				case EField(e0, f):
					switch (Tools.expr(e0))
					{
						case EIdent(id):
							// Make sure setting superclass fields works when using this.
							// Also ensures property functions are accounted for.
							if (id == "this")
							{
								if (getProxy().getRegularSuper() != null)
								{
									if (getProxy().regularSuperHasField(f))
									{
										var v = expr(e2);
										Reflect.setProperty(getProxy().getRegularSuper(), f, v);
										return v;
									}
								}
							}
							else 
							{
								var classPath:Null<String> = null;

								if (id == getProxy()._c.name)
									classPath = getProxy().getFullyQualifiedPath(id);
								else if (getProxy()._c.imports.get(id)?.cls == PolymodScriptClass)
									classPath = getProxy()._c.imports.get(id).fullPath;

								if (classPath != null)
								{
									var v = expr(e2);
									return scriptManager.staticFieldWrite(classPath, f, v);
								}
							}
						default:
							// Do nothing
					}
				default:
			}
		}
		// Fallback, which calls set()
		return super.assign(e1, e2);
	}

	override function evalAssignOp(op, fop, e1, e2):Dynamic 
	{
		if (getProxy() != null)
		{
			switch (Tools.expr(e1))
			{
				case EIdent(id):
					var classPath = getProxy().getFullyQualifiedPath(getProxy()._c.name);
					if (scriptManager.staticFieldExists(classPath, id))
					{
						var v = fop(scriptManager.staticFieldRead(classPath, id), expr(e2));
						return scriptManager.staticFieldWrite(classPath, id, v);
					}
				case EField(e, f):
					switch (Tools.expr(e))
					{
						case EIdent(id):
							var classPath:Null<String> = null;

							if (id == getProxy()._c.name)
								classPath = getProxy().getFullyQualifiedPath(id);
							else if (getProxy()._c.imports.get(id)?.cls == PolymodScriptClass)
								classPath = getProxy()._c.imports.get(id).fullPath;

							if (classPath != null)
							{
								var v = fop(scriptManager.staticFieldRead(classPath, f), expr(e2));
								return scriptManager.staticFieldWrite(classPath, f, v);
							}
						default:
					}
				default:
			}
		}
		return super.evalAssignOp(op, fop, e1, e2);
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
			getProxy().reportErrorEx(err, 'anonymous');
			return null;
		}
		catch (err:hscript.Expr.Error)
		{
			getProxy().reportError(err, 'anonymous');
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

	override function resolve(id:String):Dynamic
	{
		if (id == 'super')
		{
			if (getProxy() == null)
				errorEx(EInvalidInStaticContext('super'));
			else if (getProxy().superClass == null)
				return getProxy().superConstructor;
			else	
				return getProxy().superClass;
		}
		else if (id == 'this')
		{
			if (getProxy() != null)
				return getProxy();
			else 
				errorEx(EInvalidInStaticContext('this'));
		}
		else if (id == 'null')
		{
			return null;
		}

		if (locals.exists(id))
			return locals.get(id).r;

		if (variables.exists(id))
			return variables.get(id);

		// Access static field of this class
		if (getProxy() != null)
		{
			var classPath = getProxy().getFullyQualifiedPath(getProxy()._c.name);
			if (scriptManager.staticFieldExists(classPath, id))
				return scriptManager.staticFieldRead(classPath, id);
		}

		// Attempt to access this class statically
		if (getProxy() != null && id == getProxy()._c.name)
			return PolymodScriptClass;

		// Attempt to access an import.
		if (getProxy() != null && getProxy()._c.imports.exists(id))
		{
			var imp:PolymodClassImport = getProxy()._c.imports.get(id);
			if (imp.cls != null) return imp.cls;
			if (imp.enm != null) return imp.enm;
		}

		// We are calling a LOCAL function from the same module.
		if (getProxy() != null)
		{
			if (getProxy().findFunction(id) != null)
				return getProxy().fieldRead(id);

			if (getProxy().regularSuperHasField(id))
				return Reflect.getProperty(getProxy().getRegularSuper(), id);

			try
			{
				return getProxy().fieldRead(id);
			}
			catch (e:Dynamic)
			{
				// Skip and fall through to the next case.
			}
		}

		errorEx(EUnknownVariable(id));

		return null;
	}

	function getArgs(params:Array<Expr>, autoCast:Bool):Array<Dynamic>
	{
		var args = new Array();
		for (p in params)
		{
			var o = expr(p);
			if (autoCast && Std.isOfType(o, PolymodScriptClass))
			{
				var scriptClass:PolymodScriptClass = cast(o, PolymodScriptClass);
				switch (Tools.expr(p))
				{
					case EMeta(name, _, _):
						if (name != ':noCast')
							o = scriptClass.getRegularSuper() ?? o;
					default:
						o = scriptClass.getRegularSuper() ?? o;
				}
			}
			args.push(o);
		}
		return args;
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
