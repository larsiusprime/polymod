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

import polymod.util.Util;

// #if sys
class SysFileSystem
{
    public function new(){};

    public static inline function exists( path: String )
    {
        return sys.FileSystem.exists(path);
    }

    public static inline function isDirectory( path: String )
        return sys.FileSystem.isDirectory(path);

    public static inline function readDirectory( path: String )
        return sys.FileSystem.readDirectory(path);

    public static inline function getFileContent( path: String )
        return sys.io.File.getContent(path);

    public static inline function getFileBytes( path: String )
        return sys.io.File.getBytes(path);

    public static function readDirectoryRecursive( path: String ):Array<String>
    {
		var all = _readDirectoryRecursive(path);
		for (i in 0...all.length)
		{
			var f = all[i];
			var stri = Util.uIndexOf(f, path + "/");
			if (stri == 0)
			{
				f = Util.uSubstr(f, Util.uLength(path+"/"), Util.uLength(f));
				all[i] = f;
			}
		}
		return all;
	}

	private static function _readDirectoryRecursive(str:String):Array<String>
	{
		if (PolymodFileSystem.exists(str) && PolymodFileSystem.isDirectory(str))
		{
			var all = PolymodFileSystem.readDirectory(str);
			if (all == null) return [];
			var results = [];
			for (thing in all)
			{
				if (thing == null) continue;
				var pathToThing = Util.pathJoin(str,thing);
				if (PolymodFileSystem.isDirectory(pathToThing))
				{
					var subs = _readDirectoryRecursive(pathToThing);
					if (subs != null)
					{
						results = results.concat(subs);
					}
				}
				else
				{
					results.push(pathToThing);
				}
			}
			return results;
		}
		return [];
	}
}
// #end
