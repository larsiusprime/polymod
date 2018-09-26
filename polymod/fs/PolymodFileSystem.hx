package polymod.fs;

class PolymodFileSystem
{
    public static inline function exists( path: String )
    {
        #if sys 
            return SysFileSystem.exists(path);
        #else
            return StubFileSystem.exists(path);
        #end
    }

    public static inline function isDirectory( path: String )
    {
        #if sys 
            return SysFileSystem.isDirectory(path);
        #else
            return StubFileSystem.isDirectory(path);
        #end
    }

    public static inline function readDirectory( path: String ) : Array<String>
    {
        #if sys 
            return SysFileSystem.readDirectory(path);
        #else
            return StubFileSystem.readDirectory(path);
        #end
    }

    public static inline function getFileContent( path: String )
    {
        #if sys 
            return SysFileSystem.getFileContent(path);
        #else
            return StubFileSystem.getFileContent(path);
        #end
    }

    public static inline function getFileBytes( path: String )
    {
        #if sys 
            return SysFileSystem.getFileBytes(path);
        #else
            return StubFileSystem.getFileBytes(path);
        #end
    }

    public static inline function readDirectoryRecursive( path: String )
    {
        #if sys 
            return SysFileSystem.readDirectoryRecursive(path);
        #else
            return StubFileSystem.readDirectoryRecursive(path);
        #end
    }
}
