package polymod.library;

import polymod.PolymodAssets.AssetType;
import polymod.PolymodAssets.Framework;
import polymod.PolymodAssets.ModAssetLibraryParams;

class PolymodAssetLibrary
{
    private var backend:IBackend;
	private var fallback:Dynamic;

    private var type(default, null) = new Map<String, AssetType>();

	private var dir:String;
	private var dirs:Array<String> = null;
	private var fallBackToDefault:Bool = true;
	private var fallback:AssetLibrary = null;
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
        //fallback = params.fallback;
        mergeRules = params.mergeRules;
        ignoredFiles = params.ignoredFiles != null ? params.ignoredFiles.copy() : [];
        fallbackToDefault = fallback != null;
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

    public function getText(id:String):String { return backend.getText(id); }
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