package polymod.fs;

class StubFileSystem {
    public static inline function exists( path: String )
        return false;

    public static inline function isDirectory( path: String )
        return false;

    public static inline function readDirectory( path: String ) : Array<String>
        return [];

    public static inline function getFileContent( path: String )
        return null;

    public static inline function readDirectoryRecursive( path: String )
        return [];
}
