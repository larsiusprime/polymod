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
 * -D POLYMOD_SCRIPT_EXT=".hscript"
 * ```
 * 
 * Overriding in Lime:
 * ```
 * <haxedef name="POLYMOD_SCRIPT_EXT" value=".hscript" />
 * ```
 * 
 * Each value has a default, or you can use a compiler flag to override it.
 */
class HScriptConfig
{
	/**
	 * Whether additional debug information should be output.
	 * Override with `<haxedef name="POLYMOD_DEBUG" value="true" />`
	 * @default `false`
	 */
	public static var debug(get, null):Bool;

	static function get_debug()
	{
		return DefineUtil.getDefineBool('POLYMOD_DEBUG', false);
	}

	/**
	 * The base path from which scripts should be accessed.
	 * Override with `<haxedef name="POLYMOD_ROOT_PATH" value="true" />`
	 * @default `data/`
	 */
	public static var rootPath(get, null):String;

	static function get_rootPath()
	{
		return DefineUtil.getDefineString('POLYMOD_ROOT_PATH', "data/");
	}

	/**
	 * Whether script paths should, by default, be relative to the class's path or the root path.
	 * Override with `<haxedef name="POLYMOD_USE_NAMESPACE" value="true" />`
	 * For example, if `POLYMOD_USE_NAMESPACE` is false, `demo.Simulation#updateBee` will use `data/demo/Simulation/updateBee.txt`
	 * If `POLYMOD_USE_NAMESPACE` is false, `demo.Simulation#updateBee` will use `data/updateBee.txt`
	 * @default `true`
	 */
	public static var useNamespaceInPaths(get, null):Bool;

	static function get_useNamespaceInPaths()
	{
		return DefineUtil.getDefineBool('POLYMOD_USE_NAMESPACE', true);
	}

	/**
	 * The file extension for script files.
	 * Override with `<haxedef name="POLYMOD_SCRIPT_EXT" value=".txt" />`
	 * @default `.txt`
	 */
	public static var scriptExt(get, null):String;

	static function get_scriptExt()
	{
		// Ideally, the default should be `.hscript` but that would be a breaking change.
		return DefineUtil.getDefineString('POLYMOD_SCRIPT_EXT', ".txt");
	}

	/**
	 * The asset library to use for loading scripts.
	 		* Override with `<haxedef name="POLYMOD_SCRIPT_LIBRARY" value="default" />`
	 		* @default `default`
	 */
	public static var scriptLibrary(get, null):String;

	static function get_scriptLibrary()
	{
		return DefineUtil.getDefineString('POLYMOD_SCRIPT_LIBRARY', "default");
	}
}
