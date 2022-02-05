package polymod.fs;

/**
 * This stub file system returns false for all requests.
 * This is used when the actual file system can't be accessed.
 */
class StubFileSystem implements IFileSystem
{
	public function new()
	{
	}

	public inline function exists(path:String)
		return false;

	public inline function isDirectory(path:String)
		return false;

	public inline function readDirectory(path:String):Array<String>
		return [];

	public inline function getFileContent(path:String)
		return null;

	public inline function getFileBytes(path:String)
		return null;

	public inline function readDirectoryRecursive(path:String)
		return [];

	public inline function scanMods()
		return [];

	public inline function getMetadata(modId:String)
		return null;
}
