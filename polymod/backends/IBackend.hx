package polymod.backends;

interface IBackend
{
    //Check if the base asset set has a type defined for this asset
    public function checkTypeFallback(id:String):Bool;
    
    //Synchronous asset fetch from modified set:
    public function getText(id:String):String;
    public function getBytes(id:String);
    public function getImage(id:String);
    public function getFont(id:String);
    public function getAudio(id:String);
    public function getVideo(id:String);
    
    //Synchronous asset fetch from default unmodified set:
    public function getTextFallback(id:String):String;
    public function getBytesFallback(id:String);
    public function getFontFallback(id:String);
    public function getImageFallback(id:String);
    public function getAudioFallback(id:String);
    public function getVideoFallback(id:String);
    
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