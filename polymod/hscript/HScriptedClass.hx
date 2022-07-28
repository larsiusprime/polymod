package polymod.hscript;

import haxe.Json;
import polymod.Polymod.PolymodErrorCode;
import polymod.Polymod.PolymodErrorCode;
import polymod.Polymod;

/**
 * This interface triggers the execution of a macro which redirects all function calls to a scripted class.
 */
@:autoBuild(polymod.hscript._internal.HScriptedClassMacro.build())
interface HScriptedClass
{
	/**
	 * Call a custom function on a scripted class, by the given name, with the given arguments.
	 * 
	 * @param funcName The name of the function to call.
	 * @param funcArgs The arguments to pass to the function.
	 * @return The result of the function call.
	 */
	//public function scriptCall(funcName:String, funcArgs:Array<Dynamic>):Dynamic;

	/**
   * Returns the value of a custom field of the scripted class, by the given name.
	 * 
	 * @param fieldName The name of the field to return.
	 * @return The value of the field, if any.
	 */
	//public function scriptGet(fieldName:String):Dynamic;

	/**
	 * Sets the value of a custom field of the scripted class, by the given name.
	 * 
	 * @param fieldName The name of the field to set.
	 * @param value The value to set.
	 * @return The newly set value.
	 */
	//public function scriptSet(fieldName:String, value:Dynamic):Dynamic;
}
