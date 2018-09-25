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

class OpenFLBackend implements IBackend extends OpenFLAssetLibrary
{
    public var modLibrary:OpenFLAssetLibrary;
    public var fallback:OpenFLAssetLibrary;
    
    private var hasFallback:Bool = false;

    function new(fallback:OpenFLAssetLibrary) 
    {
        #if !openfl
        throw "OpenFLBackend: needs the openfl library!";
        #end
        modLibrary = new OpenFLAssetLibrary();
        this.fallback = fallback;
        hasFallback = this.fallback != null;
    }

    public function getText(id:String):String { return modLibrary.getText(id);}   //returns String
    public function getBytes(id:String) { return modLibrary.getBytes(id); }       //returns lime.util.Bytes (abstract over Haxe Bytes)
    public function getImage(id:String) { return modLibrary.getImage(id); }       //returns lime.graphics.Image
    public function getFont(id:String){ return modLibrary.getFont(id); }          //returns lime.text.Font
    public function getAudio(id:String) { return modLibrary.getAudioBuffer(id); } //returns lime.audio.AudioBuffer
    public function getVideo(id:String) {
        //should put a warning here probably 
        return getBytes(id);                                                      //video not supported as an asset type in OpenFL, just returns raw bytes
    }                  
        
    public function getTextFallback(id:String):String { 
        if(!hasFallback) return null;
        return fallback.getText(id);
    }
    public function getBytesFallback(id:String) { 
        if(!hasFallback) return null;
        return fallback.getBytes(id);
    }
    public function getImageFallback(id:String) { 
        if(!hasFallback) return null;
        return fallback.getImage(id);
    }
    public function getFontFallback(id:String) {
        if(!hasFallback) return null;
        return fallback.getFont(id);
    }
    public function getAudioFallback(id:String) {
        if(!hasFallback) return null;
        return fallback.getAudioBuffer(id);
    }
    public function getVideoFallback(id:String) {
        if(!hasFallback) return null;
        //should put a warning here probably 
        return fallback.getBytes(id);
    }  
}

