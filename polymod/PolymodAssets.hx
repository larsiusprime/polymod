package polymod;

import polymod.Polymod.PolymodErrorCode;
import polymod.backends.IBackend;
import polymod.Polymod.Framework;
import polymod.library.Util.MergeRules;
import polymod.library.PolymodAssetLibrary;

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
    /**PUBLIC STATIC**/

    public static function init(params:PolymodAssetsParams):PolymodAssetLibrary
    {
        var framework:Framework = params.framework;
        if(framework == null)
        {
            framework = autoDetectFramework();
            Polymod.notice(PolymodErrorCode.FRAMEWORK_AUTODETECT, " going with " + framework);
        }
        var backend = switch(framework)
        {
            //case NME: new polymod.backends.NMEBackend();
            //case LIME: new polymod.backends.LimeBackend();
            case OPENFL: new polymod.backends.OpenFLBackend();
            //case HEAPS: new polymod.backends.HEAPSBackend();
            //case KHA: new polymod.backends.KhaBackend();
            case CUSTOM: 
                if(params.customBackend != null)
                {
                    Type.createInstance(params.customBackend,[]);
                }
                else
                {
                    Polymod.error(PolymodErrorCode.UNDEFINED_CUSTOM_BACKEND, "params.customBackend was not defined!");
                    null;
                }
            default: null;
        }
        if(backend == null)
        {
            Polymod.error(PolymodErrorCode.FAILED_CREATE_BACKEND, "could not create a backend for framework("+framework+")!");
            return null;
        }

        library = new PolymodAssetLibrary({
            backend:backend,
            dirs:params.dirs,
            mergeRules:params.mergeRules,
            ignoredFiles:params.ignoredFiles
        });

        backend.init();

        return library;
    }

    public static function getText(id:String):String { return library.getText(id); }

    /**PRIVATE STATIC**/

    private static var library:PolymodAssetLibrary;

    private static function autoDetectFramework():Framework
    {
        #if heaps
        return HEAPS;
        #end
        #if nme
        return NME;
        #end
        #if openfl
        return OPENFL;
        #end
        #if lime
        return LIME;
        #end
        #if kha
        return KHA;
        #end
        return UNKNOWN;
    }

}

@:enum abstract PolymodAssetType(String) from String to String
{
    var BYTES = "BYTES";
    var TEXT = "TEXT";
    var IMAGE = "IMAGE";
    var VIDEO = "VIDEO";
    var FONT = "FONT";
    var AUDIO_GENERIC = "AUDIO_GENERIC";
    var AUDIO_MUSIC = "AUDIO_MUSIC";
    var AUDIO_SOUND = "AUDIO_SOUND";
    var MANIFEST = "MANIFEST";
    var TEMPLATE = "TEMPLATE";
    var UNKNOWN = "UNKNOWN";

    public static function fromString(str:String):PolymodAssetType
    {
        str = str.toUpperCase();
        switch(str)
        {
            case BYTES,TEXT,IMAGE,VIDEO,FONT,AUDIO_GENERIC,AUDIO_MUSIC,AUDIO_SOUND,MANIFEST,TEMPLATE,UNKNOWN: return str;
            default: return UNKNOWN;
        }
        return UNKNOWN;
    }
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