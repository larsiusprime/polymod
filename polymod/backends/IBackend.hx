package polymod.backends;

interface IBackend
{
    public function getText(id:String):String;
    public function getBytes(id:String);
    public function getImage(id:String);
    public function getAudio(id:String);
    public function getVideo(id:String);
    public function getFont(id:String);

    public function getFallbackText(id:String):String;
    public function getFallbackBytes(id:String);
    public function getFallbackImage(id:String);
    public function getFallbackAudio(id:String);
    public function getFallbackVideo(id:String);
    public function getFallbackFont(id:String);
}