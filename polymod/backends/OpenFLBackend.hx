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
    
    function new(fallback:OpenFLAssetLibrary) 
    {
        #if !openfl
        throw "OpenFLBackend: needs the openfl library!";
        #end
        modLibrary = new OpenFLAssetLibrary();
        this.fallback = fallback;
    }

    public function getText(id:String, fallback:Bool=false):String
    {
        if(fallback) return fallback.getText(id);
        return modLibrary.getText(id);
    }

    public function getBytes(id:String, fallback:Bool=false){}
    public function getImage(id:String, fallback:Bool=false){}
    public function getAudio(id:String, fallback:Bool=false){}
    public function getVideo(id:String, fallback:Bool=false){}
    public function getFont(id:String, fallback:Bool=false){}
    
    
}

