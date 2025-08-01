package polymod.hscript._internal;

#if hscript
import hscript.Expr;
import hscript.Interp;
import hscript.Tools;
import polymod.hscript._internal.PolymodExprEx;
import polymod.hscript._internal.PolymodClassDeclEx.PolymodClassImport;
import polymod.hscript._internal.PolymodClassDeclEx.PolymodStaticClassReference;

using StringTools;

/**
 * Based on code by Ian Harrigan
 * @see https://github.com/ianharrigan/hscript-ex
 */
@:access(polymod.hscript._internal.PolymodScriptClass)
@:access(polymod.hscript._internal.PolymodAbstractScriptClass)
@:access(polymod.hscript._internal.PolymodEnum)
class PolymodInterpEx extends Interp
{
	var targetCls:Class<Dynamic>;

	private var _proxy:PolymodAbstractScriptClass = null;

	var _classDeclOverride:PolymodClassDeclEx = null;

	function getClassDecl():PolymodClassDeclEx {
		if (_classDeclOverride != null) {
			return _classDeclOverride;
		} else if (_proxy != null) {
			return _proxy._c;
		} else {
			return null;
		}
	}

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
		// Try to retrieve a scripted class with this name in the same package.
		if (getClassDecl().pkg != null && getClassDecl().pkg.length > 0) {
			var localClassId = getClassDecl().pkg.join('.') + "." + cl;
			var clsRef = PolymodStaticClassReference.tryBuild(localClassId);
			if (clsRef != null) return clsRef.instantiate(args);
		}

		// Try to retrieve a scripted class with this name in the base package.
		var clsRef = PolymodStaticClassReference.tryBuild(cl);
		if (clsRef != null) return clsRef.instantiate(args);

		@:privateAccess
		if (getClassDecl()?.pkg != null)
		{
			@:privateAccess
			var packagedClass = getClassDecl().pkg.join(".") + "." + cl;
			if (_scriptClassDescriptors.exists(packagedClass))
			{
				// OVERRIDE CHANGE: Create a PolymodScriptClass instead of a hscript.ScriptClass
				var proxy:PolymodAbstractScriptClass = new PolymodScriptClass(_scriptClassDescriptors.get(packagedClass), args);
				return proxy;
			}
		}

		@:privateAccess
		if (getClassDecl()?.imports != null && getClassDecl().imports.exists(cl))
		{
			var importedClass:PolymodClassImport = getClassDecl().imports.get(cl);
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
		else if (Std.isOfType(o, PolymodStaticClassReference)) {
			var ref:PolymodStaticClassReference = cast(o, PolymodStaticClassReference);

			return ref.callFunction(f, args);
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
				// This is a scripted class!
				// We should try to call the function on the scripted class.
				// If it doesn't exist, `asc.callFunction()` will handle generating an error message.
				if (o.scriptCall != null) {
					return o.scriptCall(f, args);
				}

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

	private static var _scriptClassDescriptors:Map<String, PolymodClassDeclEx> = new Map<String, PolymodClassDeclEx>();

	private static function registerScriptClass(c:PolymodClassDeclEx)
	{
		var name = c.name;
		if (c.pkg != null)
		{
			name = c.pkg.join(".") + "." + name;
		}

		if (_scriptClassDescriptors.exists(name)) {
			Polymod.error(SCRIPT_CLASS_ALREADY_REGISTERED, 'A scripted class with the fully qualified name "$name" has already been defined. Please change the class name or the package name to ensure a unique name.');
			return;
		} else {
			Polymod.debug('Registering scripted class $name');
			_scriptClassDescriptors.set(name, c);
		}
	}

	public function clearScriptClassDescriptors():Void {
		// Clear the script class descriptors.
		_scriptClassDescriptors.clear();

		// Also destroy local variable scope.
		this.resetVariables();
	}

	public static function findScriptClassDescriptor(name:String)
	{
		return _scriptClassDescriptors.get(name);
	}

	private static var _scriptEnumDescriptors:Map<String, PolymodEnumDeclEx> = new Map<String, PolymodEnumDeclEx>();

	private static function registerScriptEnum(e:PolymodEnumDeclEx)
	{
		var name = e.name;
		if (e.pkg != null)
		{
			name = e.pkg.join(".") + "." + name;
		}

		if (_scriptEnumDescriptors.exists(name)) {
			Polymod.error(SCRIPT_ENUM_ALREADY_REGISTERED, 'An enum with the fully qualified name "$name" has already been defined. Please change the enum name to ensure a unique name.');
			return;
		} else {
			Polymod.debug('Registering enum $name');
			_scriptEnumDescriptors.set(name, e);
		}
	}

	public function clearScriptEnumDescriptors():Void {
		// Clear the script enum descriptors.
		_scriptEnumDescriptors.clear();

		// Also destroy local variable scope.
		this.resetVariables();
	}

	public static function validateImports():Void 
	{
		for (cls in _scriptClassDescriptors) 
		{
			var clsPath = cls.pkg != null ? (cls.pkg.join(".") + ".") : "";
			clsPath += cls.name;

			for (key => imp in cls.importsToValidate) 
			{
				if (_scriptEnumDescriptors.exists(imp.fullPath))
				{
					cls.imports.set(key, imp);
					continue;
				}

				Polymod.error(SCRIPT_CLASS_MODULE_NOT_FOUND, 'Could not import ${imp.fullPath}', clsPath);
			}
		}
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

				@:privateAccess
				{
					if (_proxy != null)
					{
						var decl = _proxy.findVar(id);
						var v = expr(e2);
						switch (decl?.set)
						{
							case "set":
								var out = _proxy.callFunction('set_$id', [v]);
								return (out == null) ? v : out;

							case "never":
								errorEx(EInvalidAccess(id));
								return null;
						}
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
						else
						{
							@:privateAccess
							{
								// Check if we are setting a final. If so, throw an error.
								if (_proxy != null && _proxy._c != null)
								{
									for (imp in _proxy._c.imports)
									{
										if (imp.name != id0) continue;
										var finals = PolymodFinalMacro.getAllFinals().get(imp.fullPath) ?? [];

										if (finals.contains(id))
										{
											errorEx(EInvalidFinalSet(id));
											return null;
										}
									}
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

	override function increment(e:Expr, prefix:Bool, delta:Int)
	{
		switch (Tools.expr(e))
		{
			case EIdent(id):
				@:privateAccess
				{
					if (_proxy != null)
					{
						var decl = _proxy.findVar(id);
						if (decl != null)
						{
							var v:Dynamic = switch (decl.get)
							{
								case "get": _proxy.callFunction('get_$id');
								default: decl.expr != null ? expr(decl.expr) : null;
							}

							if (prefix)
								v += delta;

							switch(decl.set)
							{
								case "set":
									_proxy.callFunction('set_$id', [prefix ? v : (v += delta)]);
									return prefix ? v : (v += delta);
								case "never":
									errorEx(EInvalidAccess(id));
									return prefix ? v : (v += delta);
							}
						}
					}
				}
			default:
		}

		return super.increment(e, prefix, delta);
	}

	override function evalAssignOp(op:String, fop:Dynamic->Dynamic->Dynamic, e1:Expr, e2:Expr)
	{
		switch (Tools.expr(e1))
		{
			case EIdent(id):
				@:privateAccess
				{
					if (_proxy != null)
					{
						var decl = _proxy.findVar(id);
						if (decl != null)
						{
							var value = switch (decl.get)
							{
								case "get": _proxy.callFunction('get_$id');
								default: expr(e1);
							}

							var v = fop(value,expr(e2));

							switch(decl.set)
							{
								case "set":
									_proxy.callFunction('set_$id', [v]);
									return v;
								case "never":
									errorEx(EInvalidAccess(id));
									return v;
							}
						}
					}
				}
			default:
		}
		return super.evalAssignOp(op, fop, e1, e2);
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
			case EIdent(id):
				// When resolving a variable, check if it is a property with a getter, and call it if necessary.
				@:privateAccess
				{
					if (_proxy != null)
					{
						var decl = _proxy.findVar(id);
						switch (decl?.get)
						{
							case "get":
								return _proxy.callFunction('get_$id');
						}
					}
				}
			case EFunction(params, fexpr, name, _):
				// Fix to ensure callback functions catch thrown errors.
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
				var newFun:Dynamic = function(args:Array<Dynamic>)
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
							PolymodScriptClass.reportErrorEx(err, 'anonymous');
							r = null;
						}
						catch (err:hscript.Expr.Error)
						{
							PolymodScriptClass.reportError(err, 'anonymous');
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
				var hasMapElements = (hasElements && Tools.expr(arr[0]).match(EBinop("=>", _)));

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
					// restore vars
					restore(old);
					inTry = oldTry;
					// declare 'v'
					declared.push({ n : n, old : locals.get(n) });
					locals.set(n, { r : switch (err) {
						case EScriptThrow(errValue): errValue;
						default: error;
					}});
					var v : Dynamic = expr(ecatch);
					restore(old);
					return v;
				} catch (error : Dynamic) {
					var en = Type.getEnum(error);
					if (en != null && (en.getName() == "hscript._Interp.Stop" || en.getName() == "hscript.Interp.Stop")) {
						// HScript catches errors specifically of the type Stop, and uses them to handle
						// `break`, `continue`, and `return` statements without extensive logic to skip subsequent expressions.
						// This is safe to throw since it won't escalate outside of Polymod.
						inTry = oldTry;
						throw error;
					}
					// restore vars
					restore(old);
					inTry = oldTry;
					// declare 'v'
					declared.push({ n : n, old : locals.get(n) });
					locals.set(n, { r : error });
					var v : Dynamic = expr(ecatch);
					restore(old);
					return v;
				}
			case EThrow(e):
				// If there is a try/catch block, the error will be caught.
				// If there is no try/catch block, the error will be reported.
				errorEx(EScriptThrow('${expr(e)}'));
			// Enums
			case EField(e,f):
				var name = getIdent(e);
				name = getClassDecl().imports.get(name)?.fullPath ?? name;
				if (name != null && _scriptEnumDescriptors.exists(name))
				{
					return new PolymodEnum(_scriptEnumDescriptors.get(name), f, []);
				}
			case ECall(e,params):
				var args = new Array();
				for (p in params)
					args.push(expr(p));

				switch(Tools.expr(e)) {
					case EField(e,f):
						var name = getIdent(e);
						name = getClassDecl().imports.get(name)?.fullPath ?? name;
						if (name != null && _scriptEnumDescriptors.exists(name))
						{
							return new PolymodEnum(_scriptEnumDescriptors.get(name), f, args);
						}
					default:
				}
				case ESwitch(e, cases, def):
					var val:Dynamic = expr(e);
					
					if (Std.isOfType(val, PolymodEnum))
					{
						var old:Int = declared.length;
						var match = false;
						for(c in cases) 
						{
							for(v in c.values) 
							{
								switch (Tools.expr(v)) 
								{
									case ECall(e, params):
										switch (Tools.expr(e)) 
										{
											case EField(_, f):
												if (val._value == f) 
												{
													for (i => p in params) 
													{
														switch (Tools.expr(p)) 
														{
															case EIdent(n):
																declared.push({
																	n: n,
																	old: {r: locals.get(n)}
																});
																locals.set(n, {r: val._args[i]});
															default:
														}
													}
													match = true;
													break;
												}
											default:
										}
									case EField(_, f):
										if (val._value == f) 
										{
											match = true;
											break;
										}
									default:
								}
							}
							if(match) 
							{
								val = expr(c.expr);
								break;
							}
						}
						if (!match)
						{
							val = def == null ? null : expr(def);
						}
						restore(old);
						return val;
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
	public function exprWithType(e:Expr, ?t:CType):Dynamic {
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

	function exprMap(entries:Array<Expr>):Dynamic {
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

	function makeMapEmpty(keyType:CType):Dynamic {
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

	function exprArray(entries:Array<Expr>):Dynamic {
		// Create an Array<Dynamic>
		var a = new Array();
		for( e in entries )
			a.push(expr(e));
		return a;
	}

	function getIdent(e:Expr):Null<String> {
		#if hscriptPos
		switch (e.e)
		{
		#else
		switch (e)
		{
		#end
			case EIdent(v):
				return v;
			default:
				return null;
		}
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

		if (target != null && target == _proxy)
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
			PolymodScriptClass.reportErrorEx(err, 'anonymous');
			return null;
		}
		catch (err:hscript.Expr.Error)
		{
			PolymodScriptClass.reportError(err, 'anonymous');
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
		if (o == null) errorEx(EInvalidAccess(f));
		if (Std.isOfType(o, PolymodStaticClassReference)) {
			var ref:PolymodStaticClassReference = cast(o, PolymodStaticClassReference);

			return ref.getField(f);
		} else if (Std.isOfType(o, PolymodScriptClass))
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
			if (o.scriptGet != null) {
				return o.scriptGet(f);
			}

			errorEx(EInvalidScriptedVarGet(f));

			// var result = Reflect.getProperty(o, f);
			// To save a bit of performance, we only query for the existence of the property
			// if the value is reported as null, AND only in debug builds.

			// #if debug
			// if (!Reflect.hasField(o, f))
			// {
			// 	  var propertyList = Type.getInstanceFields(Type.getClass(o));
			// 	  if (propertyList.indexOf(f) == -1)
			// 	  {
			// 	  	errorEx(EInvalidScriptedVarGet(f));
			// 	  }
			// }
			// #end
			// return result;
		}

		var abstractKey:String = Type.getClassName(o) + '.' + f;
		if (PolymodScriptClass.abstractClassStatics.exists(abstractKey)) {
			return Reflect.getProperty(PolymodScriptClass.abstractClassStatics[abstractKey], abstractKey.replace('.', '_'));
		}

		// Default behavior
		if (Reflect.hasField(o, f)) {
			return Reflect.field(o, f);
		} else {
			try {
				return Reflect.getProperty(o, f);
			} catch (e:Dynamic) {
				return Reflect.field(o, f);
			}
		}
		// return super.get(o, f);
	}

	override function set(o:Dynamic, f:String, v:Dynamic):Dynamic
	{
		if (o == null)
			errorEx(EInvalidAccess(f));
		if (Std.isOfType(o, PolymodStaticClassReference)) {
			var ref:PolymodStaticClassReference = cast(o, PolymodStaticClassReference);

			return ref.setField(f, v);
		} else if (Std.isOfType(o, PolymodScriptClass))
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
			if (o.scriptSet != null) {
				return o.scriptSet(f, v);
			}

			errorEx(EInvalidScriptedVarSet(f));

			// Reflect.setProperty(o, f, v);
			// return v;
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
		if (id == "super")
		{
			if (_proxy == null) {
				errorEx(EInvalidInStaticContext("super"));
			}
			else if (_proxy.superClass == null)
			{
				return _proxy.superConstructor;
			}
			else
			{
				return _proxy.superClass;
			}
		}
		else if (id == "this")
		{
			if (_proxy != null) {
				return _proxy;
			} else {
				errorEx(EInvalidInStaticContext("this"));
			}
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

		// Attempt to access an import.
		if (getClassDecl() != null)
		{
			var importedClass:PolymodClassImport = getClassDecl().imports.get(id);
			if (importedClass != null) {
				if (importedClass.cls != null) return importedClass.cls;
				if (importedClass.enm != null) return importedClass.enm;
			}
		} else {
			trace('No proxy, trying to resolve: ${id}');
		}

		// Allow access to scripted classes for calling static functions.

		if (getClassDecl().name == id) {
			// Self-referencing
			return new PolymodStaticClassReference(getClassDecl());
		} else {
			// Try to retrieve a scripted class with this name in the same package.
			if (getClassDecl().pkg != null && getClassDecl().pkg.length > 0){
				var localClassId = getClassDecl().pkg.join('.') + "." + id;
				var result = PolymodStaticClassReference.tryBuild(localClassId);
				if (result != null) return result;
			}

			// Try to retrieve a scripted class with this name in the base package.
			var result = PolymodStaticClassReference.tryBuild(id);
			if (result != null) return result;
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
				// Skip and fall through to the next case.
			}
		}
		if (getClassDecl() != null) {
			// We are retrieving an adjacent field from a static context.
			var cls = getClassDecl();
			var name = cls.name;
			if (cls.pkg != null && cls.pkg.length > 0) {
				name = cls.pkg.join('.') + "." + name;
			}
			return PolymodScriptClass.getScriptClassStaticField(name, id);
		}

		errorEx(EUnknownVariable(id));

		return null;
	}

	public function addModule(moduleContents:String, ?origin:String = "hscript")
	{
		var parser = new PolymodParserEx();
		var decls = parser.parseModule(moduleContents, origin);
		registerModules(decls, origin);
	}

	/**
	 * Call a static function of a scripted class.
	 * @param clsName The full classpath of the scripted class.
	 * @param fnName The name of the function to call.
	 * @param args The arguments to pass to the function.
	 * @return The return value of the function.
	 */
	public function callScriptClassStaticFunction(clsName:String, fnName:String, args:Array<Dynamic> = null):Dynamic {
		var fn:Null<FunctionDecl> = null;
		var imports:Map<String, PolymodClassImport> = [];

		var cls:Null<PolymodClassDeclEx> = _scriptClassDescriptors.get(clsName);
		if (cls != null) {
			imports = cls.imports;

			// TODO: Optimize with a cache?
			for (f in cls.staticFields)
			{
				if (f.name == fnName)
				{
					switch (f.kind)
					{
						case KFunction(func):
							fn = func;
						case _:
					}
				}
			}
		} else {
			Polymod.error(SCRIPT_CLASS_NOT_REGISTERED, 'Scripted class $clsName has not been defined.');
			return null;
		}

		if (fn != null) {
			// Populate function arguments.

			// previousValues is used to restore variables after they are shadowed in the local scope.
			var previousClassDecl = _classDeclOverride;
			var previousValues:Map<String, Dynamic> = [];
			var i = 0;
			for (a in fn.args)
			{
				var value:Dynamic = null;

				if (args != null && i < args.length)
				{
					value = args[i];
				}
				else if (a.value != null)
				{
					value = this.expr(a.value);
				}

				// NOTE: We assign these as variables rather than locals because those get wiped when we enter the function.
				if (this.variables.exists(a.name))
				{
					previousValues.set(a.name, this.variables.get(a.name));
				}
				this.variables.set(a.name, value);
				i++;
			}

			this._classDeclOverride = cls;

			var result:Dynamic = null;
			try
			{
				result = this.exprReturn(fn.expr);
			}
			catch (err:PolymodExprEx.ErrorEx)
			{
				PolymodScriptClass.reportErrorEx(err, clsName, fnName);
				// A script error occurred while executing the script function.
				// Purge the function from the cache so it is not called again.
				// purgeFunction(fnName);
				return null;
			}
			catch (err:hscript.Expr.Error)
			{
				PolymodScriptClass.reportError(err, clsName, fnName);
				// A script error occurred while executing the script function.
				// Purge the function from the cache so it is not called again.
				// purgeFunction(fnName);
				return null;
			}

			// Restore previous values.
			for (a in fn.args)
			{
				if (previousValues.exists(a.name))
				{
					this.variables.set(a.name, previousValues.get(a.name));
				}
				else
				{
					this.variables.remove(a.name);
				}
			}
			this._classDeclOverride = previousClassDecl;

			return result;
		} else {
			Polymod.error(SCRIPT_RUNTIME_EXCEPTION,
				'Error while calling static function ${clsName}.${fnName}(): EInvalidAccess' + '\n' +
				'Static function "${fnName}" does not exist! Define it or call the correct function.');
			return null;
		}
	}

	public function hasScriptClassStaticFunction(clsName:String, fnName:String, args:Array<Dynamic> = null):Bool {
		var imports:Map<String, PolymodClassImport> = [];

		var cls:Null<PolymodClassDeclEx> = _scriptClassDescriptors.get(clsName);
		if (cls != null) {
			imports = cls.imports;

			// TODO: Optimize with a cache?
			for (f in cls.staticFields)
			{
				if (f.name == fnName)
				{
					switch (f.kind)
					{
						case KFunction(func):
							return true;
						case _:
					}
				}
			}
		} else {
			Polymod.error(SCRIPT_CLASS_NOT_REGISTERED, 'Scripted class $clsName has not been defined.');
			return false;
		}

		return false;
	}

	public function getScriptClassStaticField(clsName:String, fieldName:String):Dynamic {
		var prefixedName = clsName + '#' + fieldName;
		var fieldDecl = getScriptClassStaticFieldDecl(clsName, fieldName);

		if (fieldDecl != null) {
			if (!this.variables.exists(prefixedName)) {
				switch (fieldDecl.kind) {
					case KFunction(fn):
						var result = buildScriptClassStaticFunction(clsName, fieldName, fn);
						this.variables.set(prefixedName, result);
						return result;
					case KVar(v):
						if (v.expr != null) {
							var result = this.expr(v.expr);
							this.variables.set(prefixedName, result);
							return result;
						}
						return null;
					default:
						throw 'Wuh?';
				}

			} else {
				return this.variables.get(prefixedName);
			}
		} else {
			errorEx(EInvalidAccess(fieldName));
			return null;
		}
	}

	private function buildScriptClassStaticFunction(clsName:String, fieldName:String, fn:FunctionDecl):Dynamic {
		var argCount = fn.args.length;
		switch(argCount) {
			case 0: return function():Dynamic {
				return callScriptClassStaticFunction(clsName, fieldName, []);
			};

			case 1: return function(a:Dynamic):Dynamic {
				return callScriptClassStaticFunction(clsName, fieldName, [a]);
			};

			case 2: return function(a:Dynamic, b:Dynamic):Dynamic {
				return callScriptClassStaticFunction(clsName, fieldName, [a, b]);
			};

			case 3: return function(a:Dynamic, b:Dynamic, c:Dynamic):Dynamic {
				return callScriptClassStaticFunction(clsName, fieldName, [a, b, c]);
			}

			case 4: return function(a:Dynamic, b:Dynamic, c:Dynamic, d:Dynamic):Dynamic {
				return callScriptClassStaticFunction(clsName, fieldName, [a, b, c, d]);
			}

			#if neko
			case _: @:privateAccess error(ECustom("only 4 params allowed in script class functions (.bind limitation)"));
			#else
			case 5: return function(a:Dynamic, b:Dynamic, c:Dynamic, d:Dynamic, e:Dynamic):Dynamic {
				return callScriptClassStaticFunction(clsName, fieldName, [a, b, c, d, e]);
			}

			case 6: return function(a:Dynamic, b:Dynamic, c:Dynamic, d:Dynamic, e:Dynamic, f:Dynamic):Dynamic {
				return callScriptClassStaticFunction(clsName, fieldName, [a, b, c, d, e, f]);
			}

			case 7: return function(a:Dynamic, b:Dynamic, c:Dynamic, d:Dynamic, e:Dynamic, f:Dynamic, g:Dynamic):Dynamic {
				return callScriptClassStaticFunction(clsName, fieldName, [a, b, c, d, e, f, g]);
			}

			case 8: return function(a:Dynamic, b:Dynamic, c:Dynamic, d:Dynamic, e:Dynamic, f:Dynamic, g:Dynamic, h:Dynamic):Dynamic {
				return callScriptClassStaticFunction(clsName, fieldName, [a, b, c, d, e, f, g, h]);
			}

			case _: @:privateAccess error(ECustom("only 8 params allowed in script class functions (.bind limitation)"));
			#end
		}

		// Fallthrough
		return null;
	}

	public function setScriptClassStaticField(clsName:String, fieldName:String, value:Dynamic):Dynamic {
		var v = getScriptClassStaticFieldDecl(clsName, fieldName);
		if (v != null) {
			var prefixedName = clsName + '#' + fieldName;
			this.variables.set(prefixedName, value);
			return value;
		} else {
			errorEx(EInvalidAccess(fieldName));
			return null;
		}
	}

	/**
	 * Retrieve a static field declaration of a scripted class.
	 * @param clsName The full classpath of the scripted class.
	 * @param fieldName The name of the field to retrieve.
	 * @return The value of the field.
	 */
	 public function getScriptClassStaticFieldDecl(clsName:String, fieldName:String):Null<FieldDecl> {
		if (_scriptClassDescriptors.exists(clsName)) {
			var cls = _scriptClassDescriptors.get(clsName);
			var staticFields = cls.staticFields;

			// TODO: Optimize with a cache?
			for (f in staticFields)
			{
				if (f.name == fieldName)
				{
					return f;
				}
			}

			// Fallthrough.
			return null;
		} else {
			Polymod.error(SCRIPT_CLASS_NOT_REGISTERED, 'Scripted class $clsName has not been defined.');
			return null;
		}
	}

	public function registerModules(module:Array<ModuleDecl>, ?origin:String = "hscript")
	{
		var pkg:Array<String> = null;
		var imports:Map<String, PolymodClassImport> = [];
		var importsToValidate:Map<String, PolymodClassImport> = [];

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
				case DImport(path, _, name):
					var clsName = path[path.length - 1];
					if (name != null) clsName = name;

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
					} else if (PolymodScriptClass.abstractClassImpls.exists(importedClass.fullPath)) {
						// We used a macro to map each abstract to its implementation.
						importedClass.cls = PolymodScriptClass.abstractClassImpls.get(importedClass.fullPath);
						trace('RESOLVED ABSTRACT CLASS ${importedClass.fullPath} -> ${Type.getClassName(importedClass.cls)}');
						trace(Type.getClassFields(importedClass.cls));
					} else if (_scriptEnumDescriptors.exists(importedClass.fullPath)) {
						// do nothing
					} else {
						var resultCls:Class<Dynamic> = Type.resolveClass(importedClass.fullPath);

						// If the class is not found, try to find it as an enum.
						var resultEnm:Enum<Dynamic> = null;
						if (resultCls == null)
							resultEnm = Type.resolveEnum(importedClass.fullPath);

						// If the class is still not found, skip this import entirely.
						if (resultCls == null && resultEnm == null) {
							//Polymod.error(SCRIPT_CLASS_MODULE_NOT_FOUND, 'Could not import class ${importedClass.fullPath}', origin);
							// this could be a scripted class or enum that hasn't been registered yet
							importsToValidate.set(importedClass.name, importedClass);
							continue;
						} else if (resultCls != null) {
							importedClass.cls = resultCls;
						} else if (resultEnm != null) {
							importedClass.enm = resultEnm;
						}
					}

					Polymod.debug('Imported class ${importedClass.name} from ${importedClass.fullPath}');
					imports.set(importedClass.name, importedClass);
				case DClass(c):
					var extend = c.extend;
					if (extend != null)
					{
						var superClassPath = new hscript.Printer().typeToString(extend);
						if (!imports.exists(superClassPath)) {
							switch (extend) {
								case CTPath(path, params):
									if (params != null && params.length > 0) {
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

					var instanceFields = [];
					var staticFields = [];
					for (f in c.fields)
					{
						if (f.access.contains(AStatic)) {
							staticFields.push(f);
						} else {
							instanceFields.push(f);
						}
					}

					var classDecl:PolymodClassDeclEx = {
						imports: imports,
						importsToValidate: importsToValidate,
						pkg: pkg,
						name: c.name,
						params: c.params,
						meta: c.meta,
						isPrivate: c.isPrivate,
						extend: extend,
						implement: c.implement,
						fields: instanceFields,
						isExtern: c.isExtern,
						staticFields: staticFields,
					};
					registerScriptClass(classDecl);
				case DEnum(e):
					if (pkg != null) 
					{
						imports.set(e.name, {
							name: e.name,
							pkg: pkg,
							fullPath: pkg.join(".") + "." + e.name,
							cls: null,
							enm: null,
						});
					}

					var enumDecl:PolymodEnumDeclEx = {
						pkg: pkg,
						name: e.name,
						fields: e.fields,
					};

					registerScriptEnum(enumDecl);
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
