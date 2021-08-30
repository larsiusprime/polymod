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
 
package polymod.fs;
import haxe.io.Bytes;
import haxe.io.UInt8Array;
import js.Browser;
import js.html.ScriptElement;
import js.Lib;

class NodeFileSystem
{
	// hack to make sure NodeUtils.injectJSCode is called
	private static var _jsCodeInjected:Bool = injectJSCode();
	
	// -----------------------------------------------------------------------------------------------
	// -----------------------------------------------------------------------------------------------
	/**
	 * Injects JS code needed to interact with Node's file system into the head element of the HTML document.
	 * @return
	 */
	private static function injectJSCode():Bool
	{
		// array for adding JS text
		var jsCode:Array<String> = [];
		
		// get the node file system
		jsCode.push("let _nodefs = require('fs')");
		
		// utility function for getting directory contents
		jsCode.push("function getDirectoryContents(path, recursive, dirContents=null)");
		jsCode.push("{");
		jsCode.push("	if ( dirContents == null ) {");
		jsCode.push("		dirContents = [];");
		jsCode.push("	}");
		jsCode.push("	if ( isDirectory(path) ) {");
		jsCode.push("		if ( path.charAt(path.length - 1) != '/' ) {");
		jsCode.push("			path += '/';");
		jsCode.push("		}");
		jsCode.push("		var entries = _nodefs.readdirSync(path, { withFileTypes:true } );");
		jsCode.push("		for ( var i = 0; i < entries.length; ++i ) {");
		jsCode.push("			var entryPath = path + entries[i].name;");
		jsCode.push("			dirContents.push( entryPath );");
		jsCode.push("			if ( entries[i].isDirectory() && recursive ) {");
		jsCode.push("				getDirectoryContents( entryPath, true, dirContents );");
		jsCode.push("			}");
		jsCode.push("		}");
		jsCode.push("	}");
		jsCode.push("	return dirContents;");
		jsCode.push("}");
		
		// functions needed by Polymod
		jsCode.push("function exists(path) { return _nodefs.existsSync(path); }");
		jsCode.push("function getStats(path) { return exists(path) ? _nodefs.statSync(path) : null; }");
		jsCode.push("function isDirectory(path) { var stats = getStats(path); return stats != null && stats.isDirectory(); }");
		jsCode.push("function getFileContent(path) { return exists(path) ? _nodefs.readFileSync(path, {encoding:'utf8', flag:'r'}) : ''; }");
		jsCode.push("function getFileBytes(path) { return exists(path) ? Uint8Array.from( _nodefs.readFileSync(path) ) : null; }");
		jsCode.push("function readDirectory(path) { return getDirectoryContents(path, false, []) }");
		jsCode.push("function readDirectoryRecursive(path) { return getDirectoryContents(path, true, []) }");
		
		// create the script element
		var scriptElement:ScriptElement = Browser.document.createScriptElement();
		scriptElement.type = "text/javascript";
		scriptElement.text = jsCode.join("\n");
		
		// inject into the head tag
		Browser.document.head.appendChild(scriptElement);
		
		return true;
	}
	
	
	// -----------------------------------------------------------------------------------------------
	/**
	 * Pulled and modified from OpenFL's ExternalInterface implementation
	 * @param	functionName
	 * @param	arg
	 * @return
	 */
	private static function callFunc(functionName:String, arg:Dynamic = null):Dynamic
	{
		if (!~/^\(.+\)$/.match(functionName))
		{
			var thisArg = functionName.split(".").slice(0, -1).join(".");
			if (thisArg.length > 0)
			{
				functionName += '.bind(${thisArg})';
			}
		}
		
		var fn:Dynamic = Lib.eval(functionName);
		
		return fn(arg);
	}
	
	// -----------------------------------------------------------------------------------------------
    public static inline function exists( path: String ):Bool {
        return callFunc("exists", path);
	}
	
	// -----------------------------------------------------------------------------------------------
    public static inline function isDirectory( path: String ):Bool {
        return callFunc("isDirectory", path);
	}
	
	// -----------------------------------------------------------------------------------------------
    public static inline function readDirectory( path: String ):Array<String> {
        return callFunc("readDirectory", path);
	}
	
	// -----------------------------------------------------------------------------------------------
    public static inline function getFileContent( path: String ):String {
        return callFunc("getFileContent", path);
	}
	
	// -----------------------------------------------------------------------------------------------
	public static inline function getFileBytes( path: String ):Bytes {
		var intArr:UInt8Array = callFunc("getFileBytes", path);
		return intArr != null ? intArr.view.buffer : null;
	}
	
	// -----------------------------------------------------------------------------------------------
    public static inline function readDirectoryRecursive( path: String ):Array<String> {
		var arr:Array<String> = callFunc("readDirectoryRecursive", path);
		
		for ( i in 0...arr.length ) {
			arr[i] = StringTools.replace(arr[i], path, "");
			if ( arr[i].charAt(0) == "/") {
				arr[i] = arr[i].substr(1);
			}
		}
		
        return arr;
	}
}
