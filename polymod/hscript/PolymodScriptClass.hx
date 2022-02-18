package polymod.hscript;

using StringTools;

#if hscript_ex
import hscript.InterpEx;
import hscript.AbstractScriptClass;

/**
 * Provides handlers for scripted classes.
 */
class PolymodScriptClass
{
	/*
	 * STATIC VARIABLES
	 */
	private static var scriptInterp = new InterpEx();

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
		InterpEx._scriptClassDescriptors.clear();
	}

	/**
	 * Returns a list of all registered classes.
	 * @return Array<String>
	 */
	public static function listScriptClasses():Array<String>
	{
		var result = [];
		@:privateAccess
		for (key => _value in InterpEx._scriptClassDescriptors)
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
		for (key => value in InterpEx._scriptClassDescriptors)
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

	static function getSuperClasses(classDecl:hscript.ClassDeclEx):Array<String>
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
		var classDescriptor = InterpEx.findScriptClassDescriptor(extendString);

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

	public static function createScriptClassInstance(name:String, args:Array<Dynamic> = null):AbstractScriptClass
	{
		return scriptInterp.createScriptClassInstance(name, args);
	}
}
#end
