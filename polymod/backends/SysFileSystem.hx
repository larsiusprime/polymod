package polymod.backends;

import sys.FileSystem;

class SysFileSystem extends IFileSystem
{
    public function exists(id:String):Bool
    {
        return FileSystem.exists(id);
    }

    public function getBytes(id:String):Bytes
    {
        return File.getBytes(id);
    }

    public function getText(id:String):String;
    {
        return getContent(id);
    }
}