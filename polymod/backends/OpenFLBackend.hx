package polymod.backends;

#if openfl
    import flash.display.BitmapData;
    import haxe.xml.Fast;
    import haxe.xml.Printer;
    import lime.app.Future;
    import lime.utils.Assets in LimeAssets;
    import openfl.utils.Assets in OpenFLAssets;
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
#end

class OpenFLBackend implements IBackend
{
    #if openfl



    function new() {}
    #else
    function new()
    {
        throw "OpenFLBackend: needs the openfl library!";
    }
    #end
}

