package polymod.fs;

// #if sys
class SysFileSystem {
    public static inline function exists( path: String )
        return sys.FileSystem.exists(path);

    public static inline function isDirectory( path: String )
        return sys.FileSystem.isDirectory(path);

    public static inline function readDirectory( path: String )
        return sys.FileSystem.readDirectory(path);

    public static inline function getFileContent( path: String )
        return sys.File.getContent(path);

    public static function readDirectoryRecursive( path: String ) // TODO (DK) move Util.hx code here?
        return [];
}
// #end
