package polymod.fs;

import polymod.library.Util;

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
