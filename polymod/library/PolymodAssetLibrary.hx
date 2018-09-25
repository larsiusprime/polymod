package polymod.library;

import polymod.PolymodAssets.AssetType;
import polymod.PolymodAssets.Framework;
import polymod.PolymodAssets.ModAssetLibraryParams;

class PolymodAssetLibrary
{
    private var backend:IBackend;
    private var fileSystem:IFileSystem;

    private var type(default, null) = new Map<String, AssetType>();

	private var dir:String;
	private var dirs:Array<String> = null;
	private var fallBackToDefault:Bool = true;
	private var mergeRules:MergeRules = null;
	private var ignoredFiles:Array<String> = null;

    public function new(params:ModAssetLibraryParams)
    {
        this.backend = params.backend;
        this.fileSystem = params.fileSystem;
        dir = params.dir;
        if (params.dirs != null)
        {
            dirs = params.dirs;
        }
        backend.fallback = params.fallback;
        mergeRules = params.mergeRules;
        ignoredFiles = params.ignoredFiles != null ? params.ignoredFiles.copy() : [];
        fallbackToDefault = backend.fallback != null;
        init();
    }

    public function exists(id:String, type:AssetType)
    {
        var e = check(id, type);
        if (!e && fallBackToDefault)
        {
            return fallback.exists(id, type);
        }
        return e;
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

    public function getText(id:String):String
    {
        var modText = null;

        if (check(id))
        {
            modText = backend.getText(id);
        }
        else if(fallBackToDefault)
        {
            modText = backend.getTextFallback(id);
        }

        if (modText != null)
        {
            var theDirs = dirs != null ? dirs : [dir];
            modText = Util.mergeAndAppendText(modText, id, theDirs, getTextDirectly, mergeRules);
        }
        return backend.getText(id);
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
		
		if (checkDirectly(directory,id))
		{
            bytes = filesystem.getText(id);
		}
		else if (fallBackToDefault)
		{
			bytes = backend.getTextFallback(id);
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
            return backend.getFontFromFile(id);
		}
		else if (fallBackToDefault)
		{
			return backend.getFontFallback(id);
		}
		return null;
	}

    public function getBytes(id:String)
    { 
        //TODO: cache bytes

        if (check(id))
        {
            return backend.getBytesFromFile(id)
        }
        else if (fallbackToDefault)
        {
            return backend.getBytesFallback(id);
        }
    }
    
    public function getImage(id:String)
    {
        //TODO: cache image

        if (check(id))
        {
            return backend.getImageFromFile(id);
        }
        else if (fallbackToDefault)
        {
            return backend.getImageFallback(id);
        }
    }

    public function getAudio(id:String)
    {
        //TODO: cache audio

        if (check(id))
        {
            return backend.getAudioFromFile(id);
        }
        else if (fallbackToDefault)
        {
            return backend.getAudioFallback(id);
        }
    }

    public function getVideo(id:String)
    {
        //TODO: cache video

        if (check(id))
        {
            return backend.getVideoFromFile(id);
        }
        else if (fallbackToDefault)
        {
            return backend.getVideoFallback(id);
        }
    }
    
    public function getFont(id:String)
    {
        //TODO: cache font

        if (check(id))
        {
            return backend.getFontFromFile(id);
        }
        else if (fallbackToDefault)
        {
            return backend.getFontFallback(id);
        }
    }

    /**
	 * Check if the given asset exists
	 * (If using multiple mods, it will return true if ANY of the mod folders contains this file)
	 * @param	id
	 * @return
	 */
    public function fileExists(id:String)
    {
        if(ignoredFiles.length > 0 && ignoredFiles.indexOf(id) != -1) return false;
        var exists = false;
        id = Util.stripAssetsPrefix(id);
        if (dirs == null)
        {
            exists = fileSystem.exists(dir + Util.sl() + id);
        }
        else
        {
            for (d in dirs)
            {
                exists = fileSystem.exists(d + Util.sl() + id);
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
            return backend.checkTypeFallback(id);
		}
		return null;
    }

    public function checkDirectly(dir:String,id:String):Bool
    {
        id = Util.stripAssetsPrefix(id);
		if (dir == null || dir == "")
		{
            return fileSystem.exists(id);
		}
		else
		{
			var thePath = Util.uCombine([dir, Util.sl(), id]);
			if (fileSystem.exists(thePath))
			{
				return true;
			}
		}
		return false;
    }
}