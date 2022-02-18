package polymod.fs;

import polymod.Polymod.ModMetadata;
import haxe.io.Path;
import haxe.io.Bytes;
import polymod.util.Util;
import polymod.fs.PolymodFileSystem;

/**
 * This simple virtual file system demonstrates that anything can be used
 * as the backend filesystem for Polymod, as long as you can fulfill the
 * IFileSystem interface.
 * 
 * Instantiate the MemoryFileSystem, call `addFileBytes` to add mod files to it,
 * then pass it to Polymod. Any mod files you add will be available to Polymod
 * as though they were accessed from the file system.
 */
class MemoryFileSystem implements PolymodFileSystem.IFileSystem
{
	var files = new Map<String, Bytes>();
	var directories = [];

	/**
	 * Receive parameters to instantiate the MemoryFileSystem.
	 */
	public function new(params:PolymodFileSystemParams)
	{
		// No-op constructor.
	}

	/**
	 * Call this function to add a text document to the virtual file system.
	 * 
	 * Example: `addFileBytes("mod1/_polymod_meta.json", "...")`
	 * 
	 * @param path The path name of the file to add.
	 * @param data The text of the document.
	 */
	public function addFileBytes(path:String, data:Bytes):Void
	{
		files.set(path, data);
		directories = directories.concat(Util.listAllParentDirs(path));
	}

	/**
	 * Call this function to remove a given file from the virtual file system.
	 */
	public function removeFile(path:String):Void
	{
		files.remove(path);
	}

	/**
	 * Call this function to clear all files from the virtual file system.
	 */
	public function clear():Void
	{
		files = new Map<String, Bytes>();
		directories = [];
	}

	public inline function exists(path:String)
	{
		return files.exists(path);
	}

	public inline function isDirectory(path:String)
	{
		return directories.indexOf(path) != -1;
	}

	/**
	 * List all files AND directories at the given path.
	 */
	public inline function readDirectory(path:String):Array<String>
	{
		var result = [];
		for (key => _v in files)
		{
			// Directory must exactly match.
			if (Path.directory(key) == path)
			{
				result.push(key);
			}
		}
		for (dir in directories)
		{
			if (Path.directory(dir) == path)
			{
				result.push(dir);
			}
		}
		return result;
	}

	public inline function getFileContent(path:String):String
	{
		return files.get(path).toString();
	}

	public inline function getFileBytes(path:String):Bytes
	{
		return files.get(path);
	}

	/**
	 * List all files at or below the given path.
	 */
	public inline function readDirectoryRecursive(path:String)
	{
		var result = [];
		for (key => _v in files)
		{
			// Directory OR PARENT must exactly match.
			if (key.indexOf(path) == 0)
			{
				result.push(key);
			}
		}
		result.concat(directories.filter(function(dir)
		{
			return dir.indexOf(path) == 0;
		}));
		return result;
	}

	public inline function scanMods():Array<String>
	{
		var dirs = readDirectory('');
		var l = dirs.length;
		for (i in 0...l)
		{
			var j = l - i - 1;
			var dir = dirs[j];
			if (!isDirectory(dir) || !exists(dir))
			{
				dirs.splice(j, 1);
			}
		}
		return dirs;
	}

	public inline function getMetadata(modId:String)
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
}
