package polymod.fs;

import polymod.fs.MemoryZipFileSystem.ZipFileSystemParams;

class SysZipFileSystem extends MemoryFileSystem
{
    public function new(params:ZipFileSystemParams)
    {
        super(params);
        var zipname = (params.zipName != null) params.zipName : "";
        var zippath = (params.zipPath != null) params.zipPath : "";
        initFileSystem(zippath, zipname);
    }

	public override function exists(path:String):Bool
    {
        return null;
    }
    
	public override function isDirectory(path:String):Bool
    {
        return false;
    }

	public override function readDirectory(path:String):Array<String>
    {
        return null;
    }

	public override function readDirectoryRecursive(path:String):Array<String>
    {
        return null;
    }

	public override function getFileContent(path:String):Null<String>
    {
        return null;
    }

	public override function getFileBytes(path:String):Null<Bytes>
    {
        return null;
    }

	public override function scanMods(?apiVersionRule:VersionRule):Array<ModMetadata>
    {
        return null;
    }

	public override function getMetadata(modId:String):Null<ModMetadata>
    {
        return null;
    }

    public function initFileSystem(zippath:String, zipname:String)
    {
        
    }
}