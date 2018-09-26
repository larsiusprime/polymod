package polymod.fs;

// #if sys
class SysFileSystem
{
    public function new(){};

    public static inline function exists( path: String )
        return sys.FileSystem.exists(path);

    public static inline function isDirectory( path: String )
        return sys.FileSystem.isDirectory(path);

    public static inline function readDirectory( path: String )
        return sys.FileSystem.readDirectory(path);

    public static inline function getFileContent( path: String )
        return sys.io.File.getContent(path);

    public static inline function getFileBytes( path: String )
        return sys.io.File.getBytes(path);

    public static function readDirectoryRecursive( path: String ) // TODO (DK) move Util.hx code here?
        return [];
}
// #end
