package polymod.fs;

import polymod.fs.PolymodFileSystem.PolymodFileSystemParams;
import polymod.fs.SysZipFileSystem;

/**
 * Same as PolymodFileSystemParams but with some parameters specific to the ZipFileSystem
 */
typedef ZipFileSystemParams =
{
	// Import properties from PolymodFileSystemParams.
	> PolymodFileSystemParams,

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
