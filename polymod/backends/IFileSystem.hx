package polymod.backends;

interface IFileSystem
{
    public function exists(id:String):Bool;
    public function getBytes(id:String):Bytes;
    public function getText(id:String):String;
}