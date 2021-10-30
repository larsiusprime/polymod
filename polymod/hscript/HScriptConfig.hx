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

import polymod.util.DefineUtil;
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
	public static var debug(get, null):Bool;

	static function get_debug()
	{
		return DefineUtil.getDefineBool('POLYMOD_DEBUG', false);
	}

	public static var rootPath(get, null):String;

	static function get_rootPath()
	{
		return DefineUtil.getDefineString('POLYMOD_ROOT_PATH', "data/");
	}

	public static var useNamespaceInPaths(get, null):Bool;

	static function get_useNamespaceInPaths()
	{
		return DefineUtil.getDefineBool('POLYMOD_USE_NAMESPACE', true);
	}

	public static var scriptExt(get, null):String;

	static function get_scriptExt()
	{
		return DefineUtil.getDefineString('POLYMOD_SCRIPT_EXT', ".txt");
	}

	public static var scriptLibrary(get, null):String;

	static function get_scriptLibrary()
	{
		return DefineUtil.getDefineString('POLYMOD_SCRIPT_LIBRARY', "default");
	}
}
