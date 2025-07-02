package polymod.hscript._internal;

#if hscript
import hscript.Expr;
import polymod.hscript._internal.PolymodExprEx;

enum Param
{
	Unused;
}

@:allow(polymod.hscript._internal.PolymodScriptMacro)
class PolymodScriptClass 
{
	private static final SCRIPT_IMPL_SUFFIX:String = '_ScriptImpl_';

	public var superClass(default, null):Null<Dynamic>;

	private var _c:PolymodClassDeclEx;

	private var _extendingScriptedClass:Null<Bool>;

	private var _interp:PolymodInterpEx;

	/**
	 * Cache variables
	 */

	private var _cachedVarDecls:Map<String, VarDecl> = [];
	private var _cachedFunctionDecls:Map<String, FunctionDecl> = [];
	private var _cachedFieldDecls:Map<String, FieldDecl> = [];
	
	// only used if extending a regular class
	private var _cachedSuperFields:Array<String> = [];

	private var _childClass:Null<PolymodScriptClass>;

	public function new(c:PolymodClassDeclEx, args:Array<Dynamic>, ?childClass:PolymodScriptClass) 
	{
		var targetClass:Null<Class<Dynamic>> = null;

		if (c.extend != null) 
		{
			switch (c.extend)
			{
				case CTPath(path, params):
					var clsPath = path.join('.');
					var clsName = path[path.length - 1];

					if (PolymodScriptManager.instance.scriptClassDecls.exists(clsPath))
						targetClass = PolymodScriptClass;

					if (targetClass == null)
						targetClass = PolymodScriptManager.instance.scriptOverrides.get(clsPath);

					if (targetClass == null)
						targetClass = c.imports.get(clsName).cls;

					if (targetClass == null) 
						Polymod.error(SCRIPT_PARSE_ERROR, 'Could not find class "${clsPath}"');

					_extendingScriptedClass = targetClass == PolymodScriptClass;
				default:
					Polymod.error(SCRIPT_PARSE_ERROR, 'Could not determine target class for "${c.extend}" (unknown type?)');
			}
		}

		_c = c;
		_interp = childClass?._interp ?? new PolymodInterpEx(this);
		_childClass = childClass;

		buildCache(targetClass);

		construct(targetClass, args);

		if (!_extendingScriptedClass && superClass != null)
			superClass.__scriptClass__ = _childClass ?? this;
	}

	public function reportError(err:Error, className:String = null, fnName:String = null)
	{
		var errEx = ErrorExUtil.toErrorEx(err);
		reportErrorEx(errEx, fnName);
	}

	public function reportErrorEx(err:ErrorEx, className:String = null, fnName:String = null):Void
	{
		var errLine:String = #if hscriptPos '${err.line}' #else "#???" #end;

		#if hscriptPos
		switch (err.e)
		#else
		switch (err)
		#end
		{
			// EInvalidChar
			// EUnexpected
			// EUnterminatedString
			// EUnterminatedComment
			// EInvalidPreprocessor
			// EInvalidIterator
			// EInvalidOp
			case ECustom(msg):
				Polymod.error(SCRIPT_RUNTIME_EXCEPTION,
					'Error while executing function ${className}.${fnName}()#${errLine}: ' + '\n' + 'An unknown error occurred: ${msg}');
			case EClassUnresolvedSuperclass(c, r):
				Polymod.error(SCRIPT_RUNTIME_EXCEPTION,
					'Error while executing function ${className}.${fnName}()#${errLine}: ' + '\n' + 'Could not resolve super class type "${c}" (${r})');
			case EClassSuperNotCalled:
					Polymod.error(SCRIPT_RUNTIME_EXCEPTION,
						'Error while executing function ${className}.${fnName}()#${errLine}: ' + '\n' + 'Custom constructor does not call "super()".');
			case EInvalidScriptedFnAccess(f):
				Polymod.error(SCRIPT_RUNTIME_EXCEPTION,
					'Error while executing function ${className}.${fnName}()#${errLine}: ' + '\n' +
					'Could not call function "${f}" on scripted class. Did you try obj.scriptCall("${f}", [...])?');
			case EInvalidInStaticContext(v):
				Polymod.error(SCRIPT_RUNTIME_EXCEPTION,
					'Error while executing function ${className}.${fnName}()#${errLine}: ' + '\n' +
					'Cannot access value "${v}" from a static context.');
			case EInvalidScriptedVarGet(v):
				Polymod.error(SCRIPT_RUNTIME_EXCEPTION,
					'Error while executing function ${className}.${fnName}()#${errLine}: ' + '\n' +
					'Could not retrieve variable "${v}" on scripted class. Did you try obj.scriptGet("${v}")?');
			case EInvalidScriptedVarSet(v):
				Polymod.error(SCRIPT_RUNTIME_EXCEPTION,
					'Error while executing function ${className}.${fnName}()#${errLine}: ' + '\n' +
					'Could not assign variable "${v}" on scripted class. Did you try obj.scriptSet("${v}", value)?');
			case EInvalidModule(m):
				Polymod.error(SCRIPT_RUNTIME_EXCEPTION,
					'Error while executing function ${className}.${fnName}()#${errLine}: ' + '\n' + 'Could not resolve imported module type "${m}".');
			case EBlacklistedModule(m):
				Polymod.error(SCRIPT_RUNTIME_EXCEPTION,
					'Error while executing function ${className}.${fnName}()#${errLine}: ' + '\n' + 'Imported module "${m}" has been blacklisted.');
			case EUnknownVariable(v):
				Polymod.error(SCRIPT_RUNTIME_EXCEPTION,
					'Error while executing function ${className}.${fnName}()#${errLine}: EUnknownVariable' + '\n' +
					'UnknownVariable error: Tried to access "${v}", an unknown variable or identifier.');
			case EInvalidAccess(f):
				Polymod.error(SCRIPT_RUNTIME_EXCEPTION,
					'Error while executing function ${className}.${fnName}()#${errLine}: EInvalidAccess' + '\n' +
					'InvalidAccess error: Tried to access "${f}", but it is not a valid field or method. Is the target object null?');
			case EScriptThrow(v):
				Polymod.error(SCRIPT_RUNTIME_EXCEPTION,
					'Error while executing function ${className}.${fnName}()#${errLine}: EScriptThrow' + '\n' +
					'User script threw an error: ${v}');
			default:
				Polymod.error(SCRIPT_RUNTIME_EXCEPTION,
					'Error while executing function ${className}.${fnName}()#${errLine}: ' + '\n' + 'An unknown error occurred: ${err}');
		}
	}

	public function findVar(name:String):Null<VarDecl> 
	{
		if (_cachedVarDecls.exists(name))
			return _cachedVarDecls.get(name);

		if (_extendingScriptedClass) 
			return superClass?.findVar(name);

		return null;
	}

	public function findFunction(name:String):Null<FunctionDecl> 
	{
		if (_cachedFunctionDecls.exists(name))
			return _cachedFunctionDecls.get(name);

		if (_extendingScriptedClass) 
			return superClass?.findFunction(name);

		return null;
	}

	public function findField(name:String):Null<FieldDecl> 
	{
		if (_cachedFieldDecls.exists(name))
			return _cachedFieldDecls.get(name);

		if (_extendingScriptedClass) 
			return superClass?.findField(name);

		return null;
	}

	/**
	 * This returns true if the super class has a field with the given name.
	 * Only use this if the super class is a regular class
	 * @param name Field name
	 * @return Bool
	 */
	public function regularSuperHasField(name:String):Bool 
	{
		if (superClass == null)
			return false;

		if (_extendingScriptedClass)
			return superClass?.regularSuperHasField(name);

		return _cachedSuperFields.contains(name) || _cachedSuperFields.contains('get_$name');
	}

	/**
	 * Get the super class that isn't a scripted class
	 * @return Null<Dynamic>
	 */
	public function getRegularSuper():Null<Dynamic> 
	{
		if (superClass == null)
			return null;

		if (_extendingScriptedClass)
			return superClass?.getRegularSuper();

		return superClass;
	}

	public function superConstructor(arg0:Dynamic = Unused, arg1:Dynamic = Unused, arg2:Dynamic = Unused, arg3:Dynamic = Unused #if !neko , arg4:Dynamic = Unused, arg5:Dynamic = Unused, arg6:Dynamic = Unused, arg7:Dynamic = Unused #end):Void
	{
		var args = [];
		if (arg0 != Unused) 
			args.push(arg0);
		if (arg1 != Unused)
			args.push(arg1);
		if (arg2 != Unused)
			args.push(arg2);
		if (arg3 != Unused)
			args.push(arg3);

		#if !neko
		if (arg4 != Unused)
			args.push(arg4);
		if (arg5 != Unused)
			args.push(arg5);
		if (arg6 != Unused)
			args.push(arg6);
		if (arg7 != Unused)
			args.push(arg7);
		#end

		createSuperClass(args);
	}

	public function callFunction(fnName:String, ?args:Array<Dynamic>):Dynamic 
	{
		switch (fnName)
		{
			case 'castType':
				return Reflect.callMethod(this, Reflect.field(this, 'castType'), args);
			case 'castPath':
				return Reflect.callMethod(this, Reflect.field(this, 'castPath'), args);
			case 'toString':
				return Reflect.callMethod(this, Reflect.field(this, 'toString'), args);	
			case 'scriptGet':
				return Reflect.callMethod(this, Reflect.field(this, 'scriptGet'), args);	
			case 'scriptSet':
				return Reflect.callMethod(this, Reflect.field(this, 'scriptSet'), args);	
			case 'scriptCall':
				return Reflect.callMethod(this, Reflect.field(this, 'scriptCall'), args);	
		}

		var r:Dynamic = null;
		var fn:Null<FunctionDecl> = findFunction(fnName);
		args = args ?? [];

		if (fn != null)
		{
			@:privateAccess
			if (_childClass != null)
				_interp._overrideProxies.push(this);

			var prev:Map<String, Dynamic> = [];
			for (i => a in fn.args) 
			{
				prev.set(a.name, _interp.variables.get(a.name));

				if (i < args.length)
					_interp.variables.set(a.name, args[i]);
				else if (a.value != null)
					_interp.variables.set(a.name, _interp.expr(a.value));
			}

			r = _interp.executeEx(fn.expr);

			for (k => v in prev)
				_interp.variables.set(k, v);

			@:privateAccess _interp._overrideProxies.pop();
		} 
		else if (getRegularSuper() != null) 
		{
			var fn = Reflect.field(getRegularSuper(), fnName);

			if (fn == null)
			{
				Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Could not find function "${fnName}" in super class "${Type.getClassName(Type.getClass(getRegularSuper()))}"');
				return null;
			}

			r = Reflect.callMethod(getRegularSuper(), fn, args);
		} 
		else 
		{
			Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Could not find function "${fnName}" in class "${_c.name}"');
			return null;
		}

		return r;
	}

	public function fieldRead(name:String):Dynamic 
	{
		switch (name)
		{
			case 'superClass':
				return superClass;
			default:
				if (findVar(name) != null) 
				{
					return _interp.variables.get(name);
				}
				else if (findFunction(name) != null)
				{  
					var fn = findFunction(name);
					var nargs = fn.args != null ? fn.args.length : 0;
					switch (nargs)
					{
						case 0: return callFunction0.bind(name);
						case 1: return callFunction1.bind(name, _);
						case 2: return callFunction2.bind(name, _, _);
						case 3: return callFunction3.bind(name, _, _, _);
						case 4: return callFunction4.bind(name, _, _, _, _);
						#if neko
						default: @:privateAccess _interp.error(ECustom('only 4 params allowed in script class functions'));
						#else
						case 5: return callFunction5.bind(name, _, _, _, _, _);
						case 6: return callFunction6.bind(name, _, _, _, _, _, _);
						case 7: return callFunction7.bind(name, _, _, _, _, _, _, _);
						case 8: return callFunction8.bind(name, _, _, _, _, _, _, _, _);
						default: @:privateAccess _interp.error(ECustom('only 8 params allowed in script class functions'));
						#end
					}
				}
				else if (regularSuperHasField(name)) 
				{  
					return Reflect.getProperty(getRegularSuper(), name);
				}
		}

		throw 'field "${name}" does not exist in script class "${_c.name}" or super class "${Type.getClassName(Type.getClass(getRegularSuper()))}"';
	}

	public function fieldWrite(name:String, value:Dynamic):Dynamic 
	{
		if (findVar(name) != null)
			_interp.variables.set(name, value);
		else if (getRegularSuper() != null && regularSuperHasField(name))
			Reflect.setProperty(getRegularSuper(), name, value);
		else
			throw 'field "${name}" does not exist in script class "${_c.name}" or super class "${Type.getClassName(Type.getClass(getRegularSuper()))}"';

		return value;
	}

	public function getFullyQualifiedPath(cls:String):String
	{
		var path:String = cls;
		if (_c.pkg != null)
			path = '${_c.pkg.join('.')}.${cls}';
		return path;
	}

	/**
	 * Cast to a super class using the given type
	 * @param type Type of the super class
	 * @return Null<Dynamic>
	 */
	public function castType(type:Class<Dynamic>):Null<Dynamic>
	{
		var parentClass = superClass;
		while (parentClass != null)
		{
			if (Std.isOfType(parentClass, type))
				return parentClass;
			if (Std.isOfType(parentClass, PolymodScriptClass))
				parentClass = superClass.superClass;
			else
				break;
		}
		Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Could not cast ${this.toString()} to ${Type.getClassName(type)}');
		return null;
	}

	/**
	 * Cast to a super class using the fully qualified name of the class
	 * @param path Fully qualified name of the class
	 * @return Null<Dynamic>
	 */
	public function castPath(path:String):Null<Dynamic>
	{
		var parentClass = superClass;
		while (parentClass != null)
		{
			if (Std.isOfType(parentClass, PolymodScriptClass))
			{
				if (parentClass.getFullyQualifiedPath(parentClass._c.name) == path)
					return parentClass;
				else
					parentClass = superClass.superClass;
			} 
			else 
			{
				var cls = Type.resolveClass(path);
				if (cls != null && Std.isOfType(parentClass, cls))
					return parentClass;
				else
					break;
			}
		}
		Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Could not cast ${this.toString()} to ${path}');
		return null;
	}

	public function toString():String 
	{
		return 'PolymodScriptClass(${getFullyQualifiedPath(_c.name)})';
	}

	private function construct(targetClass:Null<Class<Dynamic>>, args:Array<Dynamic>):Void 
	{
		if (findFunction('new') != null) 
		{
			callFunction('new', args);

			if (superClass == null && targetClass != null)
				Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Missing super() call in "${_c.name}"');
		} 
		else if (targetClass != null)
		{
			createSuperClass(args);
		
			if (superClass == null)
				Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'Could not create super class "${Type.getClassName(Type.getClass(superClass))}" in "${_c.name}"');
		}
	}

	private function createSuperClass(args:Array<Dynamic> = null):Void
	{
		if (args == null)
		{
			args = [];
		}

		var fullExtendString = new hscript.Printer().typeToString(_c.extend);

		// Templates are ignored completely since there's no type checking in HScript.
		if (fullExtendString.indexOf('<') != -1)
		{
			fullExtendString = fullExtendString.split('<')[0];
		}

		// Build an unqualified path too.
		var fullExtendStringParts = fullExtendString.split('.');
		var extendString = fullExtendStringParts[fullExtendStringParts.length - 1];

		if (PolymodScriptManager.instance.scriptClassDecls.exists(extendString))
		{
			superClass = new PolymodScriptClass(PolymodScriptManager.instance.scriptClassDecls.get(extendString), args, _childClass ?? this);
		}
		else
		{
			var clsToCreate:Class<Dynamic> = null;

			if (PolymodScriptManager.instance.scriptOverrides.exists(fullExtendString))
			{
				clsToCreate = PolymodScriptManager.instance.scriptOverrides.get(fullExtendString);

				if (clsToCreate == null)
					@:privateAccess _interp.errorEx(EClassUnresolvedSuperclass(fullExtendString, 'WHY?'));
			}
			else if (_c.imports.exists(extendString)) 
			{
				clsToCreate = _c.imports.get(extendString).cls;

				if (clsToCreate == null)
					@:privateAccess _interp.errorEx(EClassUnresolvedSuperclass(extendString, 'target class blacklisted'));
			} 
			else 
			{
				@:privateAccess _interp.errorEx(EClassUnresolvedSuperclass(extendString, 'missing import'));
			}

			if (clsToCreate == PolymodScriptClass)
				superClass = new PolymodScriptClass(PolymodScriptManager.instance.scriptClassDecls.get(_c.imports.get(extendString).fullPath), args, _childClass ?? this);
			else
				superClass = Type.createInstance(clsToCreate, args);
		}
	}

	private function buildCache(?targetClass:Class<Dynamic>):Void 
	{
		for (field in _c.fields)
		{
			_cachedFieldDecls.set(field.name, field);
			switch (field.kind) 
			{
				case KVar(v):
					_cachedVarDecls.set(field.name, v);
					if (v.expr != null)
						_interp.variables.set(field.name, _interp.expr(v.expr));
				case KFunction(f):
					_cachedFunctionDecls.set(field.name, f);
				default:
					throw 'Unknown field kind "${field.kind}"';
			}
		}

		if (!_extendingScriptedClass && targetClass != null)
			_cachedSuperFields = Type.getInstanceFields(targetClass);
	}

	private inline function callFunction0(name:String):Dynamic
	{
		return callFunction(name);
	}

	private inline function callFunction1(name:String, arg0:Dynamic):Dynamic
	{
		return callFunction(name, [arg0]);
	}

	private inline function callFunction2(name:String, arg0:Dynamic, arg1:Dynamic):Dynamic
	{
		return callFunction(name, [arg0, arg1]);
	}

	private inline function callFunction3(name:String, arg0:Dynamic, arg1:Dynamic, arg2:Dynamic):Dynamic
	{
		return callFunction(name, [arg0, arg1, arg2]);
	}

	private inline function callFunction4(name:String, arg0:Dynamic, arg1:Dynamic, arg2:Dynamic, arg3:Dynamic):Dynamic
	{
		return callFunction(name, [arg0, arg1, arg2, arg3]);
	}

	#if !neko
	private inline function callFunction5(name:String, arg0:Dynamic, arg1:Dynamic, arg2:Dynamic, arg3:Dynamic, arg4:Dynamic):Dynamic
	{
		return callFunction(name, [arg0, arg1, arg2, arg3, arg4]);
	}

	private inline function callFunction6(name:String, arg0:Dynamic, arg1:Dynamic, arg2:Dynamic, arg3:Dynamic, arg4:Dynamic, arg5:Dynamic):Dynamic
	{
		return callFunction(name, [arg0, arg1, arg2, arg3, arg4, arg5]);
	}

	private inline function callFunction7(name:String, arg0:Dynamic, arg1:Dynamic, arg2:Dynamic, arg3:Dynamic, arg4:Dynamic, arg5:Dynamic, arg6:Dynamic):Dynamic
	{
		return callFunction(name, [arg0, arg1, arg2, arg3, arg4, arg5, arg6]);
	}

	private inline function callFunction8(name:String, arg0:Dynamic, arg1:Dynamic, arg2:Dynamic, arg3:Dynamic, arg4:Dynamic, arg5:Dynamic, arg6:Dynamic, arg7:Dynamic):Dynamic
	{
		return callFunction(name, [arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7]);
	}
	#end

/**
 * DEPRECATED FUNCTIONS
 * These functions are deprecated and should not be used.
 * They exist for backwards compatibility.
 */

	public function scriptGet(name:String):Dynamic 
	{
		return fieldRead(name);
	}

	public function scriptSet(name:String, value:Dynamic):Dynamic 
	{
		return fieldWrite(name, value);
	}

	public function scriptCall(name:String, ?args:Array<Dynamic>):Dynamic 
	{
		return callFunction(name, args);
	}
}
#end