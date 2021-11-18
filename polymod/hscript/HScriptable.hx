/**
 * Copyright (c) 2018 Level Up Labs, LLC
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 * 
 */

package polymod.hscript;

import haxe.Json;
import hscript.Parser;
import hscript.Expr;
import hscript.Interp;

/**
 * This interface triggers the execution of a macro on any elements which use the `@:hscript` annotation.
 * Adding the annotation to the function will cause the associate script to be executed.
 * Adding the annotation to the class will allow specification of additional parameters which apply to all annotated functions.
 */
@:autoBuild(polymod.hscript.HScriptMacro.build())
interface HScriptable
{
}

/**
 * Used to provide additional parameters to a script function.
 * 
 * `@:hscript({context, cancellable, runBefore, pathName})` can be added to any function to make it scriptable.
 * Add constant identifiers to `context` to make values accessible to the script and use the other values to define the script's behavior.
 * 
 * For the purposes of backwards compatibility, `@:hscript(A, B, C)` can also be used, which will specify the context.
 * `@:hscript(A, B, C)` is equivalent to `@:hscript({context: [A, B, C]})` but doesn't allow modifying other parameters.
 * The new syntax should be adopted where possible.
 */
class HScriptParams
{
	/**
	 * Provide an array of constants which will be accessible by the local script.
	 * This can be global utility classes, or variables/functions local to the current class.
	 */
	public var context:Array<String> = [];

	/**
	 * If true, provides a `cancel()` function to the script.
	 * Calling it will cause the main body of the function to be ignored.
	 */
	public var cancellable:Bool = false;

	/**
	 * If true, the body of the function will run BEFORE the script does.
	 * Incompatible with `cancellable`.
	 */
	public var runBefore:Bool = false;

	/**
	 * Force a specific script path name.
	 */
	public var pathName(default, set):String = null;

	function set_pathName(newValue:String):String
	{
		if (pathNameDynId != null)
			return null;

		this.pathName = newValue;
		return pathName;
	}

	/**
	 * A dynamic identifier which will be evaluated, at function call time,
	 		* to determine the pathname of the script to run.
	 		*
	 		* This can be the name of a String variable, or of a function.
	 		* 
	 		* DON'T PASS `pathNameDynId` DIRECTLY!
	 		* Just pass an identifier into `pathName` instead of a constant.
	 */
	public var pathNameDynId(default, set):String = null;

	function set_pathNameDynId(newValue:String):String
	{
		this.pathName = null;
		this.pathNameDynId = newValue;
		return this.pathNameDynId;
	}

	public function new()
	{
	}

	/**
	 * Concatenate the provided list of constant identifiers to the existing list.
	 * @returns Self, for chaining.
	 */
	public function mergeContext(newValues:Array<String>):HScriptParams
	{
		context = context.concat(newValues);
		return this;
	}

	public function mergeCancellable(newValue:Bool):HScriptParams
	{
		if (!cancellable)
			cancellable = newValue;
		return this;
	}

	public function mergeRunBefore(newValue:Bool):HScriptParams
	{
		if (!runBefore)
			runBefore = newValue;
		return this;
	}

	public function mergePathName(newValue:String, ?newDynValue:String = null):HScriptParams
	{
		if (newDynValue != null)
		{
			pathNameDynId = newDynValue;
			pathName = null;
		}
		else
		{
			if (pathNameDynId == null)
				pathName = newValue;
		}
		return this;
	}

	/**
	 * Create a copy of this object.
	 * @return A new instance of HScriptParams.
	 */
	public function copy():HScriptParams
	{
		var result = new HScriptParams();

		result.cancellable = cancellable;
		result.context = context;
		result.pathName = pathName;
		result.pathNameDynId = pathNameDynId;
		result.runBefore = runBefore;

		return result;
	}

	/**
	 * Merge all values from the provided params into this one.
	 * @returns Self, for chaining.
	 */
	public function merge(newValue:HScriptParams)
	{
		return this.mergeContext(newValue.context)
			.mergeCancellable(newValue.cancellable)
			.mergeRunBefore(newValue.runBefore)
			.mergePathName(newValue.pathName, newValue.pathNameDynId);
	}

	public function toString():String
	{
		return Json.stringify(this);
	}
}

typedef ScriptOutput =
{
	/**
	 * The output of the script. Can be any value type.
	 */
	var script_result:Dynamic;

	/**
	 * The functions and variables created within the scope of the script.
	 */
	var script_variables:Map<String, Dynamic>;
}

class ScriptRunner
{
	private var scripts:Map<String, Script>;
	private var parser:Parser;

	public function new()
	{
		parser = new Parser();
		scripts = new Map<String, Script>();
	}

	public function load(name:String, source:String):Script
	{
		var script = new Script(source);
		scripts.set(name, script);
		return script;
	}

	public function get(name:String):Script
	{
		return scripts.get(name);
	}

	public function execute(name:String):ScriptOutput
	{
		if (!scripts.exists(name))
			return null;
		var script = scripts.get(name);
		return script.execute();
	}
}

class Script
{
	public var program:Expr;
	public var interp:Interp;

	private static var parser:Parser;

	public function new(script:String)
	{
		if (parser == null)
		{
			parser = new Parser();
			parser.allowTypes = true;
		}
		program = parser.parseString(script);
		interp = new Interp();
	}

	public function set(key:String, value:Dynamic)
	{
		interp.variables.set(key, value);
	}

	public function execute():ScriptOutput
	{
		var result:Dynamic = interp.execute(program);
		return {
			script_result: result,
			script_variables: interp.variables,
		};
	}
}
