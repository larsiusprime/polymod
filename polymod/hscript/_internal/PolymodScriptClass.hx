package polymod.hscript._internal;

#if hscript
import hscript.Expr.FieldDecl;
import hscript.Expr.FunctionDecl;
import hscript.Expr.VarDecl;
import hscript.Printer;
import polymod.hscript._internal.PolymodClassDeclEx;

using StringTools;

enum Param
{
	Unused;
}

/**
 * Provides handlers for scripted classes
 * Based on code by Ian Harrigan
 * @see https://github.com/ianharrigan/hscript-ex
 */
class PolymodScriptClass
{
	/*
	 * STATIC VARIABLES
	 */
	private static final scriptInterp = new PolymodInterpEx(null, null);

	/**
	 * Define a list of script classes to override the default behavior of Polymod.
	 * For example, script classes should import `ScriptedSprite` instead of `Sprite`.
	 */
	public static final scriptClassOverrides:Map<String, Class<Dynamic>> = new Map<String, Class<Dynamic>>();

	/**
	 * Provide a class name along with a corresponding class to override imports.
	 * You can set the value to `null` to prevent the class from being imported.
	 */
	public static final importOverrides:Map<String, Class<Dynamic>> = new Map<String, Class<Dynamic>>();

	/**
	 * Provide a class name along with a corresponding class to import it in every scripted class.
	 */
	public static final defaultImports:Map<String, Class<Dynamic>> = new Map<String, Class<Dynamic>>();

	/*
	 * STATIC METHODS
	 */
	/**
	 * Register a scripted class by parsing the text of that script.
	 */
	static function registerScriptClassByString(body:String, path:String = null):Void
	{
		scriptInterp.addModule(body, path == null ? 'hscriptClass' : 'hscriptClass($path)');
	}

	/**
	 * Register a scripted class by retrieving the script from the given path.
	 */
	static function registerScriptClassByPath(path:String):Void
	{
		@:privateAccess {
			var scriptBody = Polymod.assetLibrary.getText(path);
			try
			{
				registerScriptClassByString(scriptBody, path);
			}
			catch (err:PolymodExprEx.ErrorEx)
			{
				var errLine:String = #if hscriptPos '${err.line}' #else "#???" #end;
				#if hscriptPos
				switch (err.e)
				#else
				switch (err)
				#end
				{
					case EUnexpected(s):
						Polymod.error(SCRIPT_PARSE_ERROR,
							'Error while parsing function ${path}#${errLine}: EUnexpected' + '\n' +
							'Unexpected error: Unexpected token "${s}", is there invalid syntax on this line?');
					default:
						Polymod.error(SCRIPT_PARSE_ERROR, 'Error while executing function ${path}#${errLine}: ' + '\n' + 'An unknown error occurred: ${err}');
				}
			} catch (err:hscript.Expr.Error) {
				var errLine:String = #if hscriptPos '${err.line}' #else "#???" #end;
				#if hscriptPos
				switch (err.e)
				#else
				switch (err)
				#end
				{
					case EUnexpected(s):
						Polymod.error(SCRIPT_PARSE_ERROR,
							'Error while parsing function ${path}#${errLine}: EUnexpected' + '\n' +
							'Unexpected error: Unexpected token "${s}", is there invalid syntax on this line?');
					default:
						Polymod.error(SCRIPT_PARSE_ERROR, 'Error while executing function ${path}#${errLine}: ' + '\n' + 'An unknown error occurred: ${err}');
				}
			}
		}
	}

	static function registerScriptClassByPathAsync(path:String):Bool
	{
		@:privateAccess {
			var promise = new lime.app.Promise<Bool>();

			Polymod.assetLibrary.loadText(path).onComplete((text) ->
			{
				try
				{
					registerScriptClassByString(text);
					promise.complete(true);
				}
				catch (err:PolymodExprEx.ErrorEx)
				{
					var errLine:String = #if hscriptPos '${err.line}' #else "#???" #end;
					#if hscriptPos
					switch (err.e)
					#else
					switch (err)
					#end
					{
						case EUnexpected(s):
							Polymod.error(SCRIPT_PARSE_ERROR,
								'Error while parsing function ${path}#${errLine}: EUnexpected' + '\n' +
								'Unexpected error: Unexpected token "${s}", is there invalid syntax on this line?');
						default:
							Polymod.error(SCRIPT_PARSE_ERROR,
								'Error while executing function ${path}#${errLine}: ' + '\n' + 'An unknown error occurred: ${err}');
					}
					promise.error(err);
				}
			}).onError((err) ->
				{
					Polymod.error(SCRIPT_PARSE_ERROR, 'Error while parsing function ${path}: ' + '\n' + 'An unknown error occurred: ${err}');
					promise.error(err);
				});

			// Await the promise
			return promise.future.result();
		}
	}

	/**
	 * Returns a list of all registered classes.
	 * @return Array<String>
	 */
	public static function listScriptClasses():Array<String>
	{
		var result = [];
		@:privateAccess
		for (key => _value in PolymodInterpEx._scriptClassDescriptors)
		{
			result.push(key);
		}
		return result;
	}

	/**
	 * Returns a list of all registered classes which extend the class specified by the given name.
	 * @return Array<String>
	 */
	public static function listScriptClassesExtending(clsPath:String):Array<String>
	{
		var result = [];
		@:privateAccess
		for (key => value in PolymodInterpEx._scriptClassDescriptors)
		{
			var superClasses = getSuperClasses(value);
			if (superClasses.indexOf(clsPath) != -1)
			{
				result.push(key);
			}
		}
		return result;
	}

	/**
	 * Returns a list of all registered classes which extend the specified class.
	 		* @param cls Any Class which you expect scripted classes to be extending.
	 * @return Array<String>
	 */
	static function listScriptClassesExtendingClass(cls:Class<Dynamic>):Array<String>
	{
		return listScriptClassesExtending(Type.getClassName(cls));
	}

	static function getSuperClasses(classDecl:PolymodClassDeclEx):Array<String>
	{
		if (classDecl.extend == null)
		{
			// No superclasses.
			return [];
		}

		// Get the super class name.
		var extendString = (new hscript.Printer()).typeToString(classDecl.extend);
		// Prepend the package name.
		if (classDecl.pkg != null && extendString.indexOf('.') == -1)
		{
			var extendPkg = classDecl.pkg.join('.');
			extendString = '$extendPkg.$extendString';
		}

		// Check if the superclass is a scripted class.
		var classDescriptor:PolymodClassDeclEx = PolymodInterpEx.findScriptClassDescriptor(extendString);

		if (classDescriptor != null)
		{
			var result = [extendString];

			// Parse the parent scripted class.
			return result.concat(getSuperClasses(classDescriptor));
		}
		else
		{
			// Templates are ignored completely since there's no type checking in HScript.
			if (extendString.indexOf('<') != -1)
			{
				extendString = extendString.split('<')[0];
			}

			var superCls:Class<Dynamic> = null;

			if (classDecl.imports.exists(extendString))
			{
				var importedClass:PolymodClassImport = classDecl.imports.get(extendString);
				if (importedClass != null && importedClass.cls == null) {
					// importedClass was defined but `cls` was null. This class must have been blacklisted.
					var clsName = classDecl.pkg != null ? '${classDecl.pkg.join('.')}.${classDecl.name}' : classDecl.name;
					Polymod.error(SCRIPT_PARSE_ERROR, 'Could not parse superclass "${classDecl.name}" of scripted class "${clsName}". The superclass may be blacklisted.');
					return [];
				} else if (importedClass != null) {
					superCls = importedClass.cls;
				}
			}

			if (superCls == null) {
				// Check if the superclass is a native class.
				superCls = Type.resolveClass(extendString);
			}

			// Check if the superclass was resolved.
			if (superCls != null)
			{
				var result = [];
				// The superclass is a native class.
				while (superCls != null)
				{
					// Recursively add this class's superclasses.
					result.push(Type.getClassName(superCls));

					// This returns null when the class has no superclass.
					superCls = Type.getSuperClass(superCls);
				}
				return result;
			}
			else
			{
				// The superclass is not a scripted class or native class. Probably doesn't exist, throw an error.
				var clsName = classDecl.pkg != null ? '${classDecl.pkg.join('.')}.${classDecl.name}' : classDecl.name;
				Polymod.error(SCRIPT_PARSE_ERROR, 'Could not parse superclass "$extendString" of scripted class "${clsName}". Are you sure that the superclass exists?');
				return [];
			}
		}
	}

	public static function createScriptClassInstance(name:String, args:Array<Dynamic> = null):PolymodAbstractScriptClass
	{
		return scriptInterp.createScriptClassInstance(name, args);
	}

	/**
	 * INSTANCE METHODS
	 */
	public function new(c:PolymodClassDeclEx, args:Array<Dynamic>)
	{
		var targetClass:Class<Dynamic> = null;
		switch (c.extend)
		{
			case CTPath(pth, params):
				var clsPath = pth.join('.');

				if (scriptClassOverrides.exists(clsPath)) {
					targetClass = scriptClassOverrides.get(clsPath);
				}
				else if (c.imports.exists(clsPath))
				{
					var importedClass:PolymodClassImport = c.imports.get(clsPath);
					if (importedClass != null && importedClass.cls != null) {
						targetClass = importedClass.cls;
					} else if (importedClass != null && importedClass.cls == null) {
						Polymod.error(SCRIPT_PARSE_ERROR, 'Could not determine target class for "${pth.join('.')}" (blacklisted type?)');
					} else {
						Polymod.error(SCRIPT_PARSE_ERROR, 'Could not determine target class for "${pth.join('.')}" (unregistered type?)');
					}
				} else {
					Polymod.error(SCRIPT_PARSE_ERROR, 'Could not determine target class for "${pth.join('.')}" (unregistered type?)');
				}
			default:
				Polymod.error(SCRIPT_PARSE_ERROR, 'Could not determine target class for "${c.extend}" (unknown type?)');
		}
		_interp = new PolymodInterpEx(targetClass, this);
		_c = c;
		buildCaches();

		var ctorField = findField("new");
		if (ctorField != null)
		{
			callFunction("new", args);
			if (superClass == null && _c.extend != null)
			{
				@:privateAccess _interp.errorEx(EClassSuperNotCalled);
			}
		}
		else if (_c.extend != null)
		{
			createSuperClass(args);
		}
	}

	var __superClassFieldList:Array<String> = null;

	public function superHasField(name:String):Bool
	{
		if (superClass == null)
			return false;
		// Reflect.hasField(this, name) is REALLY expensive so we use a cache.
		if (__superClassFieldList == null)
		{
			__superClassFieldList = Reflect.fields(superClass).concat(Type.getInstanceFields(Type.getClass(superClass)));
		}
		return __superClassFieldList.indexOf(name) != -1;
	}

	private function createSuperClass(args:Array<Dynamic> = null)
	{
		if (args == null)
		{
			args = [];
		}

		var extendString = new hscript.Printer().typeToString(_c.extend);
		if (_c.pkg != null && extendString.indexOf(".") == -1)
		{
			extendString = _c.pkg.join(".") + "." + extendString;
		}

		// Templates are ignored completely since there's no type checking in HScript.
		if (extendString.indexOf('<') != -1)
		{
			extendString = extendString.split('<')[0];
		}

		var classDescriptor = PolymodInterpEx.findScriptClassDescriptor(extendString);
		if (classDescriptor != null)
		{
			var abstractSuperClass:PolymodAbstractScriptClass = new PolymodScriptClass(classDescriptor, args);
			superClass = abstractSuperClass;
		}
		else
		{
			var clsToCreate:Class<Dynamic> = null;

			if (scriptClassOverrides.exists(extendString)) {
				clsToCreate = scriptClassOverrides.get(extendString);

				if (clsToCreate == null)
				{
					@:privateAccess _interp.errorEx(EClassUnresolvedSuperclass(extendString, 'WHY?'));
				}
			} else if (_c.imports.exists(extendString)) {
				clsToCreate = _c.imports.get(extendString).cls;

				if (clsToCreate == null)
				{
					@:privateAccess _interp.errorEx(EClassUnresolvedSuperclass(extendString, 'target class blacklisted'));
				}
			} else {
				@:privateAccess _interp.errorEx(EClassUnresolvedSuperclass(extendString, 'missing import'));
			}
			
			superClass = Type.createInstance(clsToCreate, args);
		}
	}

	public function reportError(err:hscript.Expr.Error, fnName:String = null)
	{
		var errEx = PolymodExprEx.ErrorExUtil.toErrorEx(err);
		reportErrorEx(errEx, fnName);
	}

	public function reportErrorEx(err:PolymodExprEx.ErrorEx, fnName:String = null):Void
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
			default:
				Polymod.error(SCRIPT_RUNTIME_EXCEPTION,
					'Error while executing function ${className}.${fnName}()#${errLine}: ' + '\n' + 'An unknown error occurred: ${err}');
		}
	}

	public function callFunction(fnName:String, args:Array<Dynamic> = null):Dynamic
	{
		// trace('Calling function ${name} on scripted class.');
		var field = findField(fnName);
		var r:Dynamic = null;

		if (field != null)
		{
			// trace('  Override found on class!');
			var fn = findFunction(fnName);
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
					value = _interp.expr(a.value);
				}

				if (_interp.variables.exists(a.name))
				{
					previousValues.set(a.name, _interp.variables.get(a.name));
				}
				_interp.variables.set(a.name, value);
				i++;
			}

			try
			{
				r = _interp.executeEx(fn.expr);
			}
			catch (err:PolymodExprEx.ErrorEx)
			{
				reportErrorEx(err, fnName);
				return null;
			}
			catch (err:hscript.Expr.Error)
			{
				reportError(err, fnName);
				return null;
			}
			catch (err:Dynamic)
			{
				throw err;
			}

			for (a in fn.args)
			{
				if (previousValues.exists(a.name))
				{
					_interp.variables.set(a.name, previousValues.get(a.name));
				}
				else
				{
					_interp.variables.remove(a.name);
				}
			}
		}
		else
		{
			// trace('  No override found on class, time to call the superclass!');
			var fixedArgs = [];
			// OVERRIDE CHANGE: Use __super_ when calling superclass
			var fixedName = '__super_${fnName}';
			for (a in args)
			{
				if (Std.isOfType(a, PolymodScriptClass))
				{
					fixedArgs.push(cast(a, PolymodScriptClass).superClass);
				}
				else
				{
					fixedArgs.push(a);
				}
			}
			var fn = Reflect.field(superClass, fixedName);
			if (fn == null)
			{
				Polymod.error(SCRIPT_RUNTIME_EXCEPTION,
					'Error while calling function super.${fnName}(): EInvalidAccess' + '\n' +
					'InvalidAccess error: Super function "${fnName}" does not exist! Define it or call the correct superclass function.');
			}
			r = Reflect.callMethod(superClass, fn, fixedArgs);
		}
		return r;
	}

	private var _c:PolymodClassDeclEx;
	private var _interp:PolymodInterpEx;

	public var superClass:Dynamic = null;

	public var className(get, null):String;

	private function get_className():String
	{
		var name = "";
		if (_c.pkg != null)
		{
			name += _c.pkg.join(".");
		}
		name += _c.name;
		return name;
	}

	private function superConstructor(arg0:Dynamic = Unused, arg1:Dynamic = Unused, arg2:Dynamic = Unused, arg3:Dynamic = Unused)
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
		createSuperClass(args);
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

	private inline function callFunction5(name:String, arg0:Dynamic, arg1:Dynamic, arg2:Dynamic, arg3:Dynamic, arg4:Dynamic):Dynamic
	{
		return callFunction(name, [arg0, arg1, arg2, arg3, arg4]);
	}

	private inline function callFunction6(name:String, arg0:Dynamic, arg1:Dynamic, arg2:Dynamic, arg3:Dynamic, arg4:Dynamic, arg5:Dynamic):Dynamic
	{
		return callFunction(name, [arg0, arg1, arg2, arg3, arg4, arg5]);
	}

	private inline function callFunction7(name:String, arg0:Dynamic, arg1:Dynamic, arg2:Dynamic, arg3:Dynamic, arg4:Dynamic, arg5:Dynamic,
			arg6:Dynamic):Dynamic
	{
		return callFunction(name, [arg0, arg1, arg2, arg3, arg4, arg5, arg6]);
	}

	private inline function callFunction8(name:String, arg0:Dynamic, arg1:Dynamic, arg2:Dynamic, arg3:Dynamic, arg4:Dynamic, arg5:Dynamic, arg6:Dynamic,
			arg7:Dynamic):Dynamic
	{
		return callFunction(name, [arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7]);
	}

	private function findFunction(name:String):FunctionDecl
	{
		if (_cachedFunctionDecls != null)
		{
			return _cachedFunctionDecls.get(name);
		}

		for (f in _c.fields)
		{
			if (f.name == name)
			{
				switch (f.kind)
				{
					case KFunction(fn):
						return fn;
					case _:
				}
			}
		}

		return null;
	}

	private function findVar(name:String):VarDecl
	{
		if (_cachedVarDecls != null)
		{
			_cachedVarDecls.get(name);
		}

		for (f in _c.fields)
		{
			if (f.name == name)
			{
				switch (f.kind)
				{
					case KVar(v):
						return v;
					case _:
				}
			}
		}

		return null;
	}

	private function findField(name:String):FieldDecl
	{
		if (_cachedFieldDecls != null)
		{
			return _cachedFieldDecls.get(name);
		}

		for (f in _c.fields)
		{
			if (f.name == name)
			{
				return f;
			}
		}
		return null;
	}

	public function listFunctions():Map<String, FunctionDecl>
	{
		return _cachedFunctionDecls;
	}

	private var _cachedFieldDecls:Map<String, FieldDecl> = null;
	private var _cachedFunctionDecls:Map<String, FunctionDecl> = null;
	private var _cachedVarDecls:Map<String, VarDecl> = null;

	private function buildCaches()
	{
		_cachedFieldDecls = [];
		_cachedFunctionDecls = [];
		_cachedVarDecls = [];

		for (f in _c.fields)
		{
			_cachedFieldDecls.set(f.name, f);
			switch (f.kind)
			{
				case KFunction(fn):
					_cachedFunctionDecls.set(f.name, fn);
				case KVar(v):
					_cachedVarDecls.set(f.name, v);
					if (v.expr != null)
					{
						var varValue = this._interp.expr(v.expr);
						this._interp.variables.set(f.name, varValue);
					}
			}
		}
	}
}
#end
