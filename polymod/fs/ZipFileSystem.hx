package polymod.fs;

/**
 * Same as PolymodFileSystemParams but with additional parameters specific to the ZipFileSystem.
 */
typedef ZipFileSystemParams =
{
	// Import properties from PolymodFileSystemParams.
	> polymod.fs.PolymodFileSystem.PolymodFileSystemParams,

	/**
	 * Path to the zip file (needed if you're using ZipFileSystem on a sys target)
	 */
	?zipPath:String
};

// Automatically chooses between MemoryZipFileSystem and SysZipFileSystem
#if sys
typedef ZipFileSystem = SysZipFileSystem;
#else
typedef ZipFileSystem = MemoryZipFileSystem;
#end
