package polymod.fs;

import haxe.io.Bytes;
import haxe.io.UInt8Array;
import js.Browser;
import js.html.ScriptElement;
import js.Lib;

/**
 * An implementation of IFileSystem which accesses files from the local directory,
 * when running in Node.js via Electron.
 */
class NodeFileSystem extends BaseFileSystem
{
  // hack to make sure NodeUtils.injectJSCode is called
  static var _jsCodeInjected:Bool = injectJSCode();

  /**
   * Injects JS code needed to interact with Node's file system into the head element of the HTML document.
   * @return
   */
  static function injectJSCode():Bool
  {
    // array for adding JS text
    var jsCode:Array<String> = [];

    // get the node file system
    jsCode.push("let _nodefs = require('fs')");

    // utility function for getting directory contents
    jsCode.push('function getDirectoryContents(path, recursive, dirContents=null)');
    jsCode.push('{');
    jsCode.push('	if ( dirContents == null ) {');
    jsCode.push('		dirContents = [];');
    jsCode.push('	}');
    jsCode.push('	if ( isDirectory(path) ) {');
    jsCode.push("		if ( path.charAt(path.length - 1) != '/' ) {");
    jsCode.push("			path += '/';");
    jsCode.push('		}');
    jsCode.push('		var entries = _nodefs.readdirSync(path, { withFileTypes:true } );');
    jsCode.push('		for ( var i = 0; i < entries.length; ++i ) {');
    jsCode.push('			var entryPath = path + entries[i].name;');
    jsCode.push('			if ( entries[i].isDirectory() && recursive ) {');
    jsCode.push('				getDirectoryContents( entryPath, true, dirContents );');
    jsCode.push('			}');
    jsCode.push('			else {');
    jsCode.push('				dirContents.push( entryPath );');
    jsCode.push('			}');
    jsCode.push('		}');
    jsCode.push('	}');
    jsCode.push('	return dirContents;');
    jsCode.push('}');

    // functions needed by Polymod
    jsCode.push('function exists(path) { return _nodefs.existsSync(path); }');
    jsCode.push('function getStats(path) { return exists(path) ? _nodefs.statSync(path) : null; }');
    jsCode.push('function isDirectory(path) { var stats = getStats(path); return stats != null && stats.isDirectory(); }');
    jsCode.push('function getFileContent(path) { return exists(path) ? _nodefs.readFileSync(path, {encoding:\' utf8 \', flag:\' r \'}) : \' \'; }');
    jsCode.push('function getFileBytes(path) { return exists(path) ? Uint8Array.from( _nodefs.readFileSync(path) ) : null; }');
    jsCode.push('function readDirectory(path) { return getDirectoryContents(path, false, []) }');
    jsCode.push('function readDirectoryRecursive(path) { return getDirectoryContents(path, true, []) }');

    // create the script element
    var scriptElement:ScriptElement = Browser.document.createScriptElement();
    scriptElement.type = 'text/javascript';
    scriptElement.text = jsCode.join('\n');

    // inject into the head tag
    Browser.document.head.appendChild(scriptElement);

    return true;
  }

  /**
   * Pulled and modified from OpenFL's ExternalInterface implementation
   * @param	functionName
   * @param	arg
   * @return
   */
  function callFunc(functionName:String, ?arg:Dynamic):Dynamic
  {
    if (!~/^\(.+\)$/.match(functionName))
    {
      var thisArg = functionName.split('.').slice(0, -1).join('.');
      if (thisArg.length > 0)
      {
        functionName += '.bind(${thisArg})';
      }
    }

    var fn:Dynamic = Lib.eval(functionName);

    return fn(arg);
  }

  /**
   * Clean up directory paths by removing the base path prefix.
   * Removes leading slashes from relative paths.
   *
   * @param path The base path to remove from each directory.
   * @param directories The array of directory paths to sanitize.
   */
  public function sanitizePaths(path:String, directories:Array<String>):Void
  {
    for (i in 0...directories.length)
    {
      directories[i] = StringTools.replace(directories[i], path, '');
      if (directories[i].charAt(0) == '/')
      {
        directories[i] = directories[i].substr(1);
      }
    }
  }

  /**
   * Returns whether the file or directory at the given path exists.
   *
   * @param path The path to check.
   * @return Whether there is a file or directory there.
   */
  public inline function exists(path:String):Bool
  {
    return callFunc('exists', path);
  }

  /**
   * Returns whether the provided path is a directory.
   *
   * @param path The path to check.
   * @return Whether the path is a directory.
   */
  public inline function isDirectory(path:String):Bool
  {
    return callFunc('isDirectory', path);
  }

  /**
   * Returns a list of files and folders contained within the provided directory path.
   * Does not return files in subfolders, use readDirectoryRecursive for that.
   *
   * @param path The path to check.
   * @return An array of file paths and folder paths.
   */
  public inline function readDirectory(path:String):Array<String>
  {
    var arr:Array<String> = callFunc('readDirectory', path);
    sanitizePaths(path, arr);
    return arr;
  }

  /**
   * Returns the content of a given file as a string.
   *
   * @param path The file to read.
   * @return The text content of the file, or `null` if the file can't be found.
   */
  public override inline function getFileContent(path:String):Null<String>
  {
    return callFunc('getFileContent', path);
  }

  /**
   * Returns the content of a given file as Bytes.
   *
   * @param path The file to read.
   * @return The bytes of the file, or `null` if the file can't be found.
   */
  public inline function getFileBytes(path:String):Null<Bytes>
  {
    var intArr:UInt8Array = callFunc('getFileBytes', path);
    return intArr != null ? Bytes.ofArray(intArr) : null;
  }

  /**
   * Returns a list of files contained within the provided directory path.
   * Checks all subfolders recursively. Returns only files.
   *
   * @param path The path to check.
   * @return An array of file paths.
   */
  public inline function readDirectoryRecursive(path:String):Array<String>
  {
    var arr:Array<String> = callFunc('readDirectoryRecursive', path);
    sanitizePaths(path, arr);
    return arr;
  }
}
