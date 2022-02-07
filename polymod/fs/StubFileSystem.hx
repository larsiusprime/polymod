package polymod.fs;

import polymod.fs.PolymodFileSystem;

/**
 * This stub file system returns false for all requests.
 * This is the fallback used when the desired file system can't be accessed.
 *
 * Mods WILL NOT LOAD if this is used, but asset localization will still work.
 */
class StubFileSystem implements PolymodFileSystem.IFileSystem
{
	public function new(params:PolymodFileSystem.PolymodFileSystemParams)
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
