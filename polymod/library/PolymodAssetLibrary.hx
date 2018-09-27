package polymod.library;

import polymod.backends.IBackend;
import polymod.PolymodAssets.PolymodAssetType;
import polymod.Polymod.Framework;
import polymod.library.Util.MergeRules;
import polymod.fs.PolymodFileSystem;

typedef PolymodAssetLibraryParams = {
   
	/**
	 * the backend used to fetch your default assets
	 */
	backend:IBackend,

   	/**
	 * paths to each mod's root directories.
	 * This takes precedence over the "Dir" parameter and the order matters -- mod files will load from first to last, with last taking precedence
	 */
	dirs:Array<String>,

	/**
	 * (optional) formatting rules for merging various data formats
	 */
	?mergeRules:MergeRules,

	/**
 	 * (optional) list of files it ignore in this mod asset library (get the fallback version instead)
	 */
	?ignoredFiles:Array<String>
}

class PolymodAssetLibrary
{
	public var backend(default, null):IBackend;
	
	public var type(default, null) = new Map<String, PolymodAssetType>();

	public var dirs:Array<String> = null;
	private var mergeRules:MergeRules = null;
	private var ignoredFiles:Array<String> = null;

	public function new(params:PolymodAssetLibraryParams)
	{
		backend = params.backend;
		backend.polymodLibrary = this;
		dirs = params.dirs;
		mergeRules = params.mergeRules;
		ignoredFiles = params.ignoredFiles != null ? params.ignoredFiles.copy() : [];
		backend.clearCache();
	}

	public function exists(id:String, type:PolymodAssetType)
	{
		return backend.exists(id, type);
	}

	public function mergeAndAppendText(id:String, modText:String):String
	{
		modText = Util.mergeAndAppendText(modText, id, dirs, getTextDirectly, mergeRules);
		return modText;
	}
	
	/**
	 * Get text without consideration of any modifications
	 * @param	id
	 * @param	theDir
	 * @return
	 */
	public function getTextDirectly (id:String, directory:String = ""):String
	{
		var bytes = null;
		if (checkDirectly(id, directory))
		{
			bytes = PolymodFileSystem.getFileBytes(file(id, directory));
		}
		else
		{
			bytes = backend.getBytes(id);
		}
		
		if (bytes == null)
		{
			return null;
		} 
		else
		{
			return bytes.getString (0, bytes.length);
		}
		return null;
	}

	public function getText (id:String):String
	{
		return backend.getText(id);
	}

	public function listModFiles (type:PolymodAssetType):Array<String>
	{
		var items = [];
		
		for (id in this.type.keys ())
		{
			if (id.indexOf("_append") == 0 || id.indexOf("_merge") == 0) continue;
			if (type == null || type == BYTES || backend.exists (id, type))
			{
				items.push (id);
			}
		}
		
		return items;
	}

	/**
	 * Check if the given asset exists in the file system
	 * (If using multiple mods, it will return true if ANY of the mod folders contains this file)
	 * @param	id
	 * @return
	 */
	public function check(id:String, type:PolymodAssetType=null)
	{
		if(ignoredFiles.length > 0 && ignoredFiles.indexOf(id) != -1) return false;
		var exists = false;
		id = Util.stripAssetsPrefix(id);
		for (d in dirs)
		{
			exists = PolymodFileSystem.exists(Util.pathJoin(d,id));
			{
				exists = true;
			}
		}
		if (exists && type != null && type != PolymodAssetType.BYTES)
		{
			exists = (this.type.get(id) == type);
		}
		return exists;
	}

	public function checkDirectly(id:String, dir:String):Bool
	{
		id = Util.stripAssetsPrefix(id);
		if (dir == null || dir == "")
		{
			return PolymodFileSystem.exists(id);
		}
		else
		{
			var thePath = Util.uCombine([dir, Util.sl(), id]);
			if (PolymodFileSystem.exists(thePath))
			{
				return true;
			}
		}
		return false;
	}

	/**
	 * Get the filename of the given asset id
	 * (If using multiple mods, it will check all the mod folders for this file, and return the LAST one found)
	 * @param	id
	 * @return
	 */
	public function file(id:String, theDir:String = ""):String
	{
		trace("file("+id+") theDir="+theDir);
		id = Util.stripAssetsPrefix(id);
		trace("id now " + id);
		if (theDir != "")
		{
			return Util.pathJoin(theDir,id);
		}
		
		var theFile = "";
		for (d in dirs)
		{
			var thePath = Util.pathJoin(d,id);
			trace("thePath = " + thePath);
			if(PolymodFileSystem.exists(thePath))
			{
				trace("EXISTS");
				theFile = thePath;
			}
		}
		return theFile;
	}
}