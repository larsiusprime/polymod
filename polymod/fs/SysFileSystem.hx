package polymod.fs;

#if sys
import polymod.Polymod.ModMetadata;
import polymod.fs.PolymodFileSystem;
import polymod.util.Util;

/**
 * An implementation of IFileSystem which accesses files from the local directory.
 * This is the default file system for desktop platforms.
 */
class SysFileSystem implements IFileSystem
{
	public var modRoot(default, null):String;

	public function new(params:PolymodFileSystemParams)
	{
		this.modRoot = params.modRoot;
	}

	public inline function exists(path:String)
	{
		return sys.FileSystem.exists(path);
	}

	public inline function isDirectory(path:String)
		return sys.FileSystem.isDirectory(path);

	public inline function readDirectory(path:String)
		return sys.FileSystem.readDirectory(path);

	public inline function getFileContent(path:String)
	{
		if (!exists(path))
			return null;
		return sys.io.File.getContent(path);
	}

	public inline function getFileBytes(path:String)
	{
		if (!exists(path))
			return null;
		return sys.io.File.getBytes(path);
	}

	public function scanMods()
	{
		var dirs = readDirectory(modRoot);
		var l = dirs.length;
		for (i in 0...l)
		{
			var j = l - i - 1;
			var dir = dirs[j];
			var testDir = '$modRoot/$dir';
			if (!isDirectory(testDir) || !exists(testDir))
			{
				dirs.splice(j, 1);
			}
		}
		return dirs;
	}

	public function getMetadata(modId:String)
	{
		if (exists(modId))
		{
			var meta:ModMetadata = null;

			var metaFile = Util.pathJoin(modId, PolymodConfig.modMetadataFile);
			var iconFile = Util.pathJoin(modId, PolymodConfig.modIconFile);

			if (!exists(metaFile))
			{
				Polymod.warning(MISSING_META, 'Could not find mod metadata file: $metaFile');
				return null;
			}
			else
			{
				var metaText = getFileContent(metaFile);
				meta = ModMetadata.fromJsonStr(metaText);
				if (meta == null)
					return null;
			}

			if (!exists(iconFile))
			{
				Polymod.warning(MISSING_ICON, 'Could not find mod icon file: $iconFile');
			}
			else
			{
				var iconBytes = getFileBytes(iconFile);
				meta.icon = iconBytes;
			}
			return meta;
		}
		else
		{
			Polymod.error(MISSING_MOD, 'Could not find mod directory: $modId');
		}
		return null;
	}

	public function readDirectoryRecursive(path:String):Array<String>
	{
		var all = _readDirectoryRecursive(path);
		for (i in 0...all.length)
		{
			var f = all[i];
			var stri = Util.uIndexOf(f, path + '/');
			if (stri == 0)
			{
				f = Util.uSubstr(f, Util.uLength(path + '/'), Util.uLength(f));
				all[i] = f;
			}
		}
		return all;
	}

	private function _readDirectoryRecursive(str:String):Array<String>
	{
		if (exists(str) && isDirectory(str))
		{
			var all = readDirectory(str);
			if (all == null)
				return [];
			var results = [];
			for (thing in all)
			{
				if (thing == null)
					continue;
				var pathToThing = Util.pathJoin(str, thing);
				if (isDirectory(pathToThing))
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
#end
