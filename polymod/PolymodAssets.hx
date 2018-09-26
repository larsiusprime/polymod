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