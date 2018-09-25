package polymod.backends;

interface IBackend
{
    public function getText(id:String):String;
    public function getBytes(id:String);
    public function getImage(id:String);
    public function getAudio(id:String);
    public function getVideo(id:String);
    public function getFont(id:String);
}