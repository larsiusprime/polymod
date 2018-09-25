package polymod;

import polymod.backends.IBackend;

class PolymodAssets
{
    private static var library:PolymodAssetLibrary;

    public static function init(params:ModAssetLibraryParams)
    {
        var framework:Framework = params.framework != null ? params.framework : UNKNOWN;
        backend = switch(framework)
        {
            case NME: new NMEBackend(params);
            case LIME: new LimeBackend(params);
            case OPENFL: new OpenFLBackend(params);
            case HEAPS: new HEAPSBackend(params);
            case KHA: new KhaBackend(params);
            case CUSTOM: 
                if(params.customBackend != null)
                {
                    return Type.createInstance(params.customBackend, [params]);
                }
                else
                {
                    throw "params.customBackend was not defined!";
                }
                return null;
            default: null;
        }
        library = new PolymodAssetLibrary(backend, params);
    }

    public static function getAsset(id:String, type:AssetType) { return library.getAsset(id, type); }
    public static function getText(id:String):String { return library.getText(id); }
    public static function getBytes(id:String) { return library.getBytes(id); }
    public static function getImage(id:String) { return library.getImage(id); }
    public static function getAudio(id:String) { return library.getAudio(id); }
    public static function getVideo(id:String) { return library.getVideo(id); }
    public static function getFont(id:String) { return library.getFont(id); }
}

typedef ModAssetLibraryParams = {
   	/**
   	 * which framework you intend to use
   	 */
    ?framework:Framework,

   	/**
	 * full path to the mod's root directory
	 */
	dir:String,

	/**
	 * (optional) if we can't find something, should we try the default asset library?
	 */
	//?fallback:AssetLibrary,

	/**
	 * (optional) to combine mods, provide multiple paths to several mod's root directories.
	 * This takes precedence over the "Dir" parameter and the order matters -- mod files will load from first to last, with last taking precedence
	 */
	?dirs:Array<String>,

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
     ?customBackend:Class<IBackend>;
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
    AUDIO;
    VIDEO;
    FONT;
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