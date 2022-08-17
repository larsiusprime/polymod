package polymod.fs;

import polymod.fs.SysZipFileSystem;

// Automatically chooses between MemoryZipFileSystem and SysZipFileSystem
#if html5
typedef ZipFileSystem = MemoryZipFileSystem;
#else
typedef ZipFileSystem = SysZipFileSystem;
#end