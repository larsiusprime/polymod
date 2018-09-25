package polymod.library;

import polymod.PolymodAssets.AssetType;
import polymod.PolymodAssets.Framework;
import polymod.PolymodAssets.ModAssetLibraryParams;

class PolymodAssetLibrary
{
    private var backend:IBackend;

    private var type(default, null) = new Map<String, AssetType>();

	private var dir:String;
	private var dirs:Array<String> = null;
	private var fallBackToDefault:Bool = true;
	private var mergeRules:MergeRules = null;
	private var ignoredFiles:Array<String> = null;

    public function new(backend:IBackend, params:ModAssetLibraryParams)
    {
        this.backend = backend;
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
            //refactor this better
            /*
            #if (openfl >= "8.0.0")
			bytes = Bytes.fromFile (file(id, directory));
			#else
			bytes = Bytes.readFile (file(id, directory));
			#end
            */
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

    public function getBytes(id:String)
    { 
        if (check(id))
        {
            return backend.getBytes(id)
        }
        //return backend.getBytes(id);
    }
    public function getImage(id:String) { return backend.getImage(id); }
    public function getAudio(id:String) { return backend.getAudio(id); }
    public function getVideo(id:String) { return backend.getVideo(id); }
    public function getFont(id:String) { return backend.getFont(id); }
}