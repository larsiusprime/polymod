package polymod.backends;

#if openfl
    import flash.display.BitmapData;
    import haxe.xml.Fast;
    import haxe.xml.Printer;
    import lime.app.Future;
    import lime.utils.Assets in LimeAssets;
    import openfl.utils.Assets in OpenFLAssets;
    import openfl.display.AssetLibrary in OpenFLAssetLibrary;
    import lime.net.HTTPRequest;
    import lime.graphics.Image;
    import lime.text.Font;
    import lime.utils.Bytes;
    import openfl.errors.Error;
    import polymod.library.Util.MergeRules;
    #if sys
    import sys.FileSystem;
    #end
    #if unifill
    import unifill.Unifill;
    #end
    #if (openfl >= "8.0.0")
    import lime.utils.AssetLibrary;
    import lime.media.AudioBuffer;
    import lime.utils.AssetType;
    #else
    import lime.Assets.AssetLibrary;
    import lime.audio.AudioBuffer;
    import lime.Assets.AssetType;
    #end
#else
    typedef OpenFLAssetLibrary = Dynamic;
#end
import polymod.PolymodAssets.AssetType in PolymodAssetType;

class OpenFLBackend implements IBackend extends OpenFLAssetLibrary
{
    public var modLibrary:OpenFLAssetLibrary;
    public var fallback:OpenFLAssetLibrary;
    
    private var hasFallback:Bool = false;

    private static function limeAssetTypeToPolymod(type:AssetType):PolymodAssetType;
    {
        return switch(type)
        {
            case BINARY: PolymodAssetType.BYTES;
            case FONT: PolymodAssetType.FONT;
            case IMAGE: PolymodAssetType.IMAGE;
            case MUSIC: PolymodAssetType.AUDIO_MUSIC;
            case SOUND: PolymodAssetType.AUDIO_SOUND;
            case MANIFEST: PolymodAssetType.MANIFEST;
            case TEMPLATE: PolymodAssetType.TEMPLATE;
            case TEXT: PolymodAssetType.TEXT;
            default: PolymodAssetType.UNKNOWN;
        }
    }

    private static function polymodAssetTypeToLime(type:PolymodAssetType):AssetType;
    {
        return switch(type)
        {
            case PolymodAssetType.BYTES: BINARY;
            case PolymodAssetType.FONT : FONT;
            case PolymodAssetType.IMAGE : IMAGE;
            case PolymodAssetType.AUDIO_MUSIC : MUSIC;
            case PolymodAssetType.AUDIO_SOUND : SOUND;
            case PolymodAssetType.MANIFEST : MANIFEST;
            case PolymodAssetType.TEMPLATE : TEMPLATE;
            case PolymodAssetType.TEXT : TEXT;
            default: PolymodAssetType.UNKNOWN;
        }
    }

    public function new (fallback:OpenFLAssetLibrary) 
    {
        #if !openfl
        throw "OpenFLBackend: needs the openfl library!";
        #end
        modLibrary = new OpenFLAssetLibrary();
        this.fallback = fallback;
        hasFallback = this.fallback != null;
    }

    public function exists(id:String, type:PolymodAssetType, useFallback:Fallback=false):Bool
    {
        if(!useFallback) return modLibary.exists(id, polymodAssetTypeToLime(type));
        if(!hasFallback) return false;
        return fallback.exists(id, polymodAssetTypeToLime(type));
    }

    public function getPath(id:String, useFallback:Fallback=false):String
    {
        if(!useFallback) return modLibrary.getPath(id);
        if(!hasFallback) return false;
        return fallback.getPath(id);
    }

    public function checkType(id:String, useFallback:Fallback=false):PolymodAssetType
    {
        var type:AssetType = AssetType.BINARY;
        if(!useFallback)
        {
            type = @:privateAccess modLibrary.types.get(id);
        }
        else
        {
            if(!hasFallback) return PolymodAssetType.UNKNOWN;
            type = @:privateAccess fallback.types.get(id);
        }
        return limeAssetTypeToPolymod(type);
    }

    public function isLocal(id:String, type:PolymodAssetType, useFallback:Fallback=false):Bool
    {
        if(!useFallback) return modLibrary.isLocal(id, polymodAssetTypeToLime(type));
        if(!hasFallback) return false;
        return fallback.isLocal(id, polymodAssetTypeToLime(type));
    }

    public function getText (id:String, useFallback:Bool=false):String
    {
        if(!useFallback) return modLibrary.getText(id);
        if(!hasFallback) return false;
        return fallback.getText(id);
    }
    
    public function getBytes (id:String, useFallback:Fallback=false)
    {
        if(!useFallback) return modLibrary.getBytes(id);
        if(!hasFallback) return false;
        return fallback.getBytes(id);
    }
    
    public function getImage (id:String, useFallback:Fallback=false)
    {
        if(!useFallback) return modLibrary.getImage(id);
        if(!hasFallback) return false;
        return fallback.getImage(id);
    }

    public function getFont (id:String, useFallback:Fallback=false)
    {
        if(!useFallback) return modLibrary.getFont(id);
        if(!hasFallback) return false;
        return fallback.getFont(id);
    }

    public function getAudio (id:String, useFallback:Fallback=false)
    {
        if(!useFallback) return modLibrary.getAudioBuffer(id);
        if(!hasFallback) return false;
        return fallback.getAudioBuffer(id);
    }

    public function getVideo (id:String, useFallback:Fallback=false)
    {
        //should put a warning here probably
        if(!useFallback) return modLibrary.getBytes(id);
        if(!hasFallback) return false;
        return fallback.getBytes(id);
    }

    public function getImageFromBytes (bytes:Bytes):Image
    {
        return Image.fromBytes(bytes);
    }

    public function getFontFromBytes (bytes:Bytes):Font
    {
        return Font.fromBytes(bytes);
    }

    public function getAudioFromBytes (bytes:Bytes):AudioBuffer
    {
        return AudioBuffer.fromFile(bytes);
    }

    public function getVideoFromBytes (bytes:Bytes):Bytes
    {
        return bytes;
    }
}

