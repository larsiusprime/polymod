package polymod.fs;

#if sys
import polymod.Polymod.ModMetadata;
import polymod.fs.PolymodFileSystem;
import polymod.util.Util;
import polymod.util.VersionUtil;
import thx.semver.VersionRule;
#if linux
using StringTools;
#end

/**
 * An implementation of IFileSystem which accesses files from folders in the local directory.
 * This is currently the default file system for native/Desktop platforms.
 */
class SysFileSystem implements IFileSystem
{
	public final modRoot:String;

	public function new(params:PolymodFileSystemParams)
	{
		this.modRoot = params.modRoot;
	}

	public function exists(path:String)
	{
		#if linux
		return getPathLike(path) != null;
		#else
		return sys.FileSystem.exists(path);
		#end
	}

	public function isDirectory(path:String)
	{
		#if linux
		path = getPathLike(path);
		#end
		return sys.FileSystem.isDirectory(path);
	}

	public function readDirectory(path:String):Array<String>
	{
		try
		{
			#if linux
			path = getPathLike(path);
			#end
			return sys.FileSystem.readDirectory(path);
		}
		catch (e)
		{
			Polymod.warning(DIRECTORY_MISSING, 'Could not find directory "${path}"');
			return [];
		}
	}

	public function getFileContent(path:String)
	{
		#if linux
		path = getPathLike(path);
		#end
		return getFileBytes(path).toString();
	}

	public function getFileBytes(path:String)
	{
		#if linux
		path = getPathLike(path);
		if(path == null) return null;
		#else
		if (!exists(path))
			return null;
		#end
		return sys.io.File.getBytes(path);
	}

	public function scanMods(?apiVersionRule:VersionRule):Array<ModMetadata>
	{
		if (apiVersionRule == null)
			apiVersionRule = VersionUtil.DEFAULT_VERSION_RULE;

		var dirs = readDirectory(modRoot);
		var result:Array<ModMetadata> = [];
		for (dir in dirs)
		{
			var fullDir = Util.pathJoin(modRoot, dir);
			if (!isDirectory(fullDir))
				continue;

			var meta:ModMetadata = this.getMetadata(dir);

			if (meta == null)
				continue;

			if (!VersionUtil.match(meta.apiVersion, apiVersionRule)) {
				Polymod.warning(MOD_API_VERSION_MISMATCH, 'Mod "${dir}" is not compatible with API version "${apiVersionRule.toString()}", got "${meta.apiVersion.toString()}"');
				continue;
			}

			result.push(meta);
		}

		return result;
	}

	public function getMetadata(modId:String)
	{
		var modPath = Util.pathJoin(modRoot, modId);
		var test = readDirectory(modRoot);
		if (exists(modPath))
		{
			var meta:ModMetadata = null;

			var metaFile = Util.pathJoin(modPath, PolymodConfig.modMetadataFile);
			var iconFile = Util.pathJoin(modPath, PolymodConfig.modIconFile);

			if (!exists(metaFile))
			{
				Polymod.warning(MISSING_META, 'Could not find mod metadata file: $metaFile');
				return null;
			}
			else
			{
				var metaText = getFileContent(metaFile);
				meta = ModMetadata.fromJsonStr(metaText);
			}

			if (meta == null)
				return null;

			meta.id = modId;
			meta.modPath = modPath;

			if (!exists(iconFile))
			{
				Polymod.warning(MISSING_ICON, 'Could not find mod icon file: $iconFile');
			}
			else
			{
				var iconBytes = getFileBytes(iconFile);
				meta.icon = iconBytes;
				meta.iconPath = iconFile;
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

	#if linux
		/**
	 * Returns a path to the existing file similar to the given one.
	 * (For instance "mod/firelight" and  "Mod/FireLight" are *similar* paths)
	 * @param path
	 * @return Null<String>
	 */
	private function getPathLike(path:String):Null<String> {

		if(sys.FileSystem.exists(path)) return path;

		var baseParts:Array<String> = path.replace('\\', '/').split('/');
		var keyParts = [];
		if (baseParts.length == 0) return null;

		while(!sys.FileSystem.exists(baseParts.join("/")) && baseParts.length != 0)
			keyParts.insert(0, baseParts.pop());

		trace(keyParts);
		return findFile(baseParts.join("/"),keyParts);
	}

	private function findFile(base_path:String,keys:Array<String>):Null<String> {
		var nextDir:String = base_path;
		for (part in keys) {
			if (part == '') continue;

			var foundNode = findNode(nextDir, part);

			if (foundNode == null) {
				return null;
			}
			nextDir = nextDir+"/"+foundNode;
		}

		return nextDir;
	}
	/**
	 * Searches a given directory and returns a name of the existing file/directory
	 * *similar* to the **key**
	 * @param dir Base directory to search
	 * @param key The file/directory you want to find
	 * @return Either a file name, or null if the one doesn't exist
	 */
	private function findNode(dir:String, key:String):Null<String> {
		try {
			var allFiles:Array<String> = sys.FileSystem.readDirectory(dir);
			var fileMap:Map<String, String> = new Map();

			for (file in allFiles) {
				fileMap.set(file.toLowerCase(), file);
			}

			return fileMap.get(key.toLowerCase());
		} catch (e:Dynamic) {
			return null;
		}
	}
	#end

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
