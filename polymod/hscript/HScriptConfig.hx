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

import haxe.macro.Type.ClassType;
import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using Lambda;

/**
 * This class provides several constants used throughout the library.
 * Since these are needed by build macros, they can be configured only through compile defines.
 * 
 * Overriding in HXML:
 * ```
 * -D POLYMOD_SCRIPT_EXT=".hx"
 * ```
 * 
 * Overriding in Lime:
 * ```
 * <haxedef name="POLYMOD_SCRIPT_EXT" value=".hx" />
 * ```
 * 
 * Each value has a default, or you can use a compiler flag to override it.
 * For example, 
 */
class HScriptConfig
{
	static macro function getStringDefine(key:String, defaultValue:String):haxe.macro.Expr
	{
		var value = Context.definedValue(key);
		Context.info('String define: ${key} : ${defaultValue} : ${value}', Context.currentPos());
		if (value == null)
			value = defaultValue;
		return macro $v{value};
	}

	static macro function getBoolDefine(key:String, defaultValue:Bool):haxe.macro.Expr
	{
		var value:String = Context.definedValue(key);
		var valueBool = (value == null) ? defaultValue : (value == 'true');
		return macro $v{valueBool};
	}

	public static var debug(default, null):Bool;

	function get_debug()
	{
		return getBoolDefine('POLYMOD_DEBUG', false);
	}

	public static var rootPath(default, null):String;

	function get_rootPath()
	{
		return getStringDefine('POLYMOD_ROOT_PATH', "data/");
	}

	public static var useNamespaceInPaths(default, null):Bool;

	function get_useNamespaceInPaths()
	{
		return getBoolDefine('POLYMOD_USE_NAMESPACE', true);
	}

	public static var scriptExt(default, null):String;

	function get_scriptExt()
	{
		return getStringDefine('POLYMOD_SCRIPT_EXT', ".txt");
	}

	public static var scriptLibrary(default, null):String;

	function get_scriptLibrary()
	{
		return getStringDefine('POLYMOD_SCRIPT_LIBRARY', "default");
	}
}