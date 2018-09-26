package polymod;

import polymod.backends.IBackend;

typedef PolymodAssetsParams = {
   
    /**
     * the Haxe framework you're using (OpenFL, HEAPS, Kha, NME, etc..)
     */
    framework:Framework,

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
	?ignoredFiles:Array<String>,

     /**
      * (optional) your own 
      */
    ?customBackend:Class<IBackend>
}

class PolymodAssets
{
    private static var library:PolymodAssetLibrary;

    public static function init(params:PolymodAssetsParams):PolymodAssetLibrary
    {
        var framework:Framework = params.framework != null ? params.framework : UNKNOWN;
        backend = switch(framework)
        {
            //case NME: new NMEBackend();
            //case LIME: new LimeBackend();
            case OPENFL: new OpenFLBackend();
            //case HEAPS: new HEAPSBackend();
            //case KHA: new KhaBackend();
            case CUSTOM: 
                if(params.customBackend != null)
                {
                    return Type.createInstance(params.customBackend);
                }
                else
                {
                    throw "params.customBackend was not defined!";
                }
                return null;
            default: null;
        }

        library = new PolymodAssetLibrary({
            backend:backend,
            fallback:params.fallback,
            dirs:params.dirs,
            mergeRules:params.mergeRules,
            ignoredFiles:params.ignoredFiles
        });

        return library;
    }

    public static function getAsset(id:String, type:AssetType) { return library.getAsset(id, type); }
    public static function getText(id:String):String { return library.getText(id); }
    public static function getBytes(id:String) { return library.getBytes(id); }
    public static function getImage(id:String) { return library.getImage(id); }
    public static function getAudio(id:String) { return library.getAudio(id); }
    public static function getVideo(id:String) { return library.getVideo(id); }
    public static function getFont(id:String) { return library.getFont(id); }
}

enum Framework
{
    NME;
    LIME;
    OPENFL;
    HEAPS;
    KHA;
    CUSTOM;
    UNKNOWN;
}

enum AssetType
{
    BYTES;
    TEXT;
    IMAGE;
    VIDEO;
    FONT;
    AUDIO_GENERIC;
    AUDIO_MUSIC;
    AUDIO_SOUND;
    MANIFEST;
    TEMPLATE;
    UNKNOWN;
}

enum TextFileFormat
{
    PLAINTEXT;
    LINES;
    CSV;
    TSV;
    XML;
    JSON;
}