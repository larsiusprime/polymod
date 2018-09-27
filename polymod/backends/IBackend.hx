package polymod.backends;

import haxe.io.Bytes;
import polymod.PolymodAssets.PolymodAssetType;
import polymod.library.PolymodAssetLibrary;

interface IBackend
{
    public var polymodLibrary:PolymodAssetLibrary;

    public function init():Void;

    public function clearCache():Void;
    public function exists(id:String, type:PolymodAssetType):Bool;

    public function getBytes(id:String):Bytes;
    public function getText(id:String):String;
    /*
    //Asynchronous asset fetch from modified set:
    public function loadText(id:String):String;
    public function loadBytes(id:String);
    public function loadImage(id:String);
    public function loadAudio(id:String);
    public function loadVideo(id:String);
    public function loadFont(id:String);
    
    //Asynchronous asset fetch from default unmodified set:
    public function loadTextFallback(id:String);
    public function loadBytesFallback(id:String);
    public function loadFontFallback(id:String);
    public function loadImageFallback(id:String);
    public function loadAudioFallback(id:String);
    public function loadVideoFallback(id:String);
    */
}

@:enum abstract Fallback(Bool) from Bool to Bool
{
    var FALLBACK = true;
    var DEFAULT = false;
}