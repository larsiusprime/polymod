package polymod.fs;

import haxe.io.Bytes;
import haxe.io.Path;
import polymod.fs.PolymodFileSystem.IFileSystem;
import polymod.fs.PolymodFileSystem.PolymodFileSystemParams;
import polymod.util.Util;

/**
 * An implementation of an IFileSystem that can access files from an un-compressed zip archive.
 * Useful for loading mods from zip files.
 * Currently does not support compressed zip files.
 */
class ZipFileSystem extends MemoryFileSystem
{
    /**
    * Creates a ZipFileSystem from the bytes of an uncompressed zip archive
    * @param zipBytes The bytes which read from the zip archive
    * @param params The polymod filesystem paramters
    */
    public static function fromZip(zipBytes:Bytes, params:PolymodFileSystemParams)
    {
        var zipfs = new ZipFileSystem(params);

        // slightly modified version of https://github.com/HaxeFoundation/haxe.org-comments/issues/41#issuecomment-845576836
        var bytesInput = new haxe.io.BytesInput(zipBytes);
        var reader = new haxe.zip.Reader(bytesInput);
        var entries:List<haxe.zip.Entry> = reader.read();
        for (_entry in entries) {
            var data = haxe.zip.Reader.unzip(_entry);
            if (_entry.fileName.substring(_entry.fileName.lastIndexOf('/') + 1) == '' && _entry.data.toString() == '')
            {
                @:privateAccess
                if(!zipfs.directories.contains(_entry.fileName))
                    zipfs.directories.push(_entry.fileName);
            } 
            else
            {
                zipfs.addFileBytes(_entry.fileName, data);
            }
        }

        return zipfs;
    }
}