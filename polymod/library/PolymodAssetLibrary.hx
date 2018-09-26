package polymod.library;

import polymod.PolymodAssets.AssetType;
import polymod.PolymodAssets.Framework;
import polymod.PolymodAssets.ModAssetLibraryParams;

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
    
    private var type(default, null) = new Map<String, AssetType>();

	private var dirs:Array<String> = null;
	private var fallBackToDefault:Bool = true;
	private var mergeRules:MergeRules = null;
	private var ignoredFiles:Array<String> = null;

    public function new(params:ModAssetLibraryParams)
    {
        backend = params.backend;
        dirs = params.dirs;
        mergeRules = params.mergeRules;
        ignoredFiles = params.ignoredFiles != null ? params.ignoredFiles.copy() : [];
        fallbackToDefault = backend.fallback != null;
        backend.clearCache();
    }

    public function exists(id:String, type:AssetType)
    {
        var e = check(id, type);
        if (!e && fallBackToDefault)
        {
            return backend.exists(id, type, FALLBACK);
        }
        return e;
    }

    public function getAudio(id:String)
    {
        //TODO: cache audio
        if (check(id))
        {
            return backend.getAudioFromBytes(PolymodFileSystem.getFileBytes(file(id));
        }
        else if (fallbackToDefault)
        {
            return backend.getAudio(id, FALLBACK);
        }
    }

    public function getBytes(id:String)
    { 
        //TODO: cache bytes
        if (check(id))
        {
            return PolymodFileSystem.getFileBytes(file(id));
        }
        else if (fallbackToDefault)
        {
            return backend.getBytes(id, FALLBACK);
        }
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
		else if (fallBackToDefault)
		{
			bytes = backend.getBytes(id, FALLBACK);
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

    public function getFont (id:String):Font
	{
        //TODO: cache font
        if (check(id))
		{
            return backend.getFontFromBytes(PolymodFileSystem.getFileBytes(file(id)));
		}
		else if (fallBackToDefault)
		{
			return backend.getFont(id, FALLBACK);
		}
		return null;
	}
    
    public function getImage(id:String)
    {
        //TODO: cache image
        if (check(id))
        {
            return backend.getImageFromFile(file(id));
        }
        else if (fallbackToDefault)
        {
            return backend.getImage(id, FALLBACK);
        }
    }

    public function getPath(id:String)
    {
        if (check(id))
        {
            return file(id);
        }
        else if (fallbackToDefault)
        {
            return backend.getPath(id, FALLBACK);
        }
    }

    public function getText(id:String):String
    {
        var modText = null;

        if (check(id))
        {
            modText = backend.getText(id);
        }
        else if(fallBackToDefault)
        {
            modText = backend.getText(id, FALLBACK);
        }

        if (modText != null)
        {
            modText = Util.mergeAndAppendText(modText, id, dirs, getTextDirectly, mergeRules);
        }
        return modText;
    }

    public function getVideo(id:String)
    {
        //TODO: cache video

        if (check(id))
        {
            return backend.getVideoFromBytes(PolymodFileSystem.getFileBytes(file(id));
        }
        else if (fallbackToDefault)
        {
            return backend.getVideo(id, FALLBACK);
        }
    }

	public function isLocal (id:String, type:String):Bool
	{
		if (check(id))
		{
			return true;
		}
		else if (fallBackToDefault)
		{
			return backend.isLocal(id, type, FALLBACK);
		}
		return false;
	}

    public function listModFiles (type:AssetType):Array<String>
	{
		var items = [];
		
		for (id in this.type.keys ())
		{
			if (id.indexOf("_append") == 0 || id.indexOf("_merge") == 0) continue;
			if (type == null || type == BINARY || backend.exists (id, type))
			{
				items.push (id);
			}
		}
		
		return items;
	}

	public override function list (type:AssetType):Array<String>
	{
		var otherList = fallBackToDefault ? backend.list(type, FALLBACK) : [];
		var items = [];
		
		for (id in this.type.keys ())
		{
			if (id.indexOf("_append") == 0 || id.indexOf("_merge") == 0) continue;
			if (type == null || type == BINARY || backend.exists (id, type))
			{
				items.push (id);
			}
		}
		
		for (otherId in otherList)
		{
			if (items.indexOf(otherId) == -1)
			{
				if (type == null || type == BINARY || backend.exists(otherId, type, FALLBACK))
				{
					items.push(otherId);
				}
			}
		}
		
		return items;
	}

    public function getAsset(id:String, type:AssetType)
    {
        return switch(type)
        {
            case TEXT: getText(id);
            case BYTES: getBytes(id);
            case IMAGE: getImage(id);
            case AUDIO: getAudio(id);
            case VIDEO: getVideo(id);
            case FONT: getFont(id);
            default: null;
        }
    }

    /**
	 * Check if the given asset exists in the file system
	 * (If using multiple mods, it will return true if ANY of the mod folders contains this file)
	 * @param	id
	 * @return
	 */
    private function check(id:String)
    {
        if(ignoredFiles.length > 0 && ignoredFiles.indexOf(id) != -1) return false;
        var exists = false;
        id = Util.stripAssetsPrefix(id);
        if (dirs == null)
        {
            exists = PolymodFileSystem.exists(dir + Util.sl() + id);
        }
        else
        {
            for (d in dirs)
            {
                exists = PolymodFileSystem.exists(d + Util.sl() + id);
                {
                    exists = true;
                }
            }
        }
        if (exists && type != null && type != BINARY)
        {
            exists = (this.type.get(id) == type);
        }
        return exists;
    }

    public function checkType(id:String):AssetType
    {
        if (this.type.exists(id))
		{
			var value = this.type.get(id);
			if (value != null)
			{
				return value;
			}
		}
		if (fallBackToDefault)
		{
            return backend.checkType(id, FALLBACK);
		}
		return null;
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
	private function file(id:String, theDir:String = ""):String
	{
		id = Util.stripAssetsPrefix(id);
		
		if (theDir != "")
		{
			return theDir + Util.sl() + id;
		}
		else if (dirs == null)
		{
			return dir + Util.sl() + id;
		}
		else
		{
			var theFile = "";
			for (d in dirs)
			{
				var thePath = d + Util.sl() + id;
				
                if(PolymodFileSystem.exists(thePath))
                {
					theFile = thePath;
				}
			}
			return theFile;
		}
		return id;
	}   
}