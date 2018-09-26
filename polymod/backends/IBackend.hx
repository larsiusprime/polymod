package polymod.backends;

import polymod.PolymodAssets.PolymodAssetType;

interface IBackend
{
    //Check if the base asset set has a type defined for this asset
    
    public function checkType(id:String, useFallback:Fallback):Bool;
    public function exists(id:String, type:AssetType, useFallback:Fallback):Bool;
    public function getPath(id:String, useFallback:Fallback):String;
    public function isLocal(id:String, type:AssetType, useFallback:Fallback):Bool;
    public function list(id:String, type:AssetType, useFallback:Fallback):Bool;
    
    //Synchronous asset fetch from modified set:
    public function getText(id:String, useFallback:Fallback):String;
    public function getBytes(id:String, useFallback:Fallback);
    public function getImage(id:String, useFallback:Fallback);
    public function getFont(id:String, useFallback:Fallback);
    public function getAudio(id:String, useFallback:Fallback);
    public function getVideo(id:String, useFallback:Fallback);

    public function getImageFromBytes(bytes:Bytes);
    public function getFontFromBytes(bytes:Bytes);
    public function getAudioFromBytes(bytes:Bytes);
    public function getVideoFromBytes(bytes:Bytes);

    public function clearCache();
    
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

@:enum abstract Fallback(Bool) to Bool
{
    var FALLBACK = true;
    var DEFAULT = false;
}