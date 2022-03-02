package polymod.hscript;

using StringTools;

import hscript.Expr.FieldDecl;
import hscript.Expr.FunctionDecl;
import hscript.Expr.VarDecl;
import hscript.Printer;

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
	private static var scriptInterp = new PolymodInterpEx(null, null);
	public static var scriptClassOverrides:Map<String, Class<Dynamic>> = new Map<String, Class<Dynamic>>();

	/*
	 * STATIC METHODS
	 */
	/**
	 * Register a scripted class by parsing the text of that script.
	 */
	static function registerScriptClassByString(body:String)
	{
		scriptInterp.addModule(body);
	}

	/**
	 * Register a scripted class by retrieving the script from the given path.
	 */
	static function registerScriptClassByPath(path:String)
	{
		@:privateAccess {
			var scriptBody = Polymod.assetLibrary.getText(path);
			registerScriptClassByString(scriptBody);
		}
	}

	/**
	 * Get a list of all the HScript classes, interpret them, and register any classes.
	 */
	public static function registerAllScriptClasses()
	{
		@:privateAccess {
			// Go through each script and parse any classes in them.
			for (textPath in Polymod.assetLibrary.list(TEXT))
			{
				if (textPath.endsWith(PolymodConfig.scriptClassExt))
				{
					registerScriptClassByPath(textPath);
				}
			}
		}
	}

	public static function clearScriptClasses()
	{
		@:privateAccess
		PolymodInterpEx._scriptClassDescriptors.clear();
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

	static function getSuperClasses(classDecl:polymod.hscript.PolymodClassDeclEx):Array<String>
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
		var classDescriptor:polymod.hscript.PolymodClassDeclEx = PolymodInterpEx.findScriptClassDescriptor(extendString);

		if (classDescriptor != null)
		{
			var result = [extendString];

			// Parse the parent scripted class.
			return result.concat(getSuperClasses(classDescriptor));
		}
		else
		{
			// Check if the superclass is a native class.
			var superClass = Type.resolveClass(extendString);
			if (superClass != null)
			{
				var result = [];
				// The superclass is a native class.
				while (superClass != null)
				{
					// Recursively add the other superclasses.
					result.push(Type.getClassName(superClass));

					// This returns null when the class has no superclass.
					superClass = Type.getSuperClass(superClass);
				}
				return result;
			}
			else
			{
				// The superclass is not a scripted class or native class. It doesn't exist?
				Polymod.error(SCRIPT_CLASS_NOT_FOUND, 'The superclass $extendString could not be found, is it a valid class?');
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
	public function new(c:polymod.hscript.PolymodClassDeclEx, args:Array<Dynamic>)
	{
		var targetClass:Class<Dynamic> = null;
		switch (c.extend)
		{
			case CTPath(pth, params):
				targetClass = scriptClassOverrides.get(pth.join('.'));
			default:
				trace('Could not determine target class for: ${c}');
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
				@:privateAccess _interp.error(ECustom("super() not called"));
			}
		}
		else if (_c.extend != null)
		{
			createSuperClass(args);
		}
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

		var classDescriptor = PolymodInterpEx.findScriptClassDescriptor(extendString);
		if (classDescriptor != null)
		{
			var abstractSuperClass:PolymodAbstractScriptClass = new PolymodScriptClass(classDescriptor, args);
			superClass = abstractSuperClass;
		}
		else
		{
			var clsToCreate:Class<Dynamic> = null;
			// OVERRIDE CHANGE: Add reference to scriptedClassOverrides
			@:privateAccess
			if (scriptClassOverrides.exists(extendString))
			{
				@:privateAccess
				clsToCreate = scriptClassOverrides.get(extendString);
			}
			if (clsToCreate == null)
			{
				clsToCreate = Type.resolveClass(extendString);
			}
			if (clsToCreate == null)
			{
				@:privateAccess _interp.error(ECustom("could not resolve super class: " + extendString));
			}

			superClass = Type.createInstance(clsToCreate, args);
		}
	}

	public function callFunction(name:String, args:Array<Dynamic> = null):Dynamic
	{
		// trace('Calling function ${name} on scripted class.');
		var field = findField(name);
		var r:Dynamic = null;

		if (field != null)
		{
			// trace('  Override found on class!');
			var fn = findFunction(name);
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

			r = _interp.execute(fn.expr);

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
			var fixedName = '__super_${name}';
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
			r = Reflect.callMethod(superClass, Reflect.field(superClass, fixedName), fixedArgs);
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
