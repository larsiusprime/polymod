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
    #if sys
    /**
    * Packs a directory into an un-compressed zip file
    * The result is written into the output path
    * (Only works on sys targets)
    * @param folderpath The path to the folder whose contents need to be zipped (Eg: /my/mod/ModFolder will be compressed into a zip containing the contents of ModFolder)
    * @param outputpath The path to which the output zip file will be written (Eg: /my/folder/mymod.zip)
    */
    public static function pack(folderpath:String, outputpath:String)
    {
        folderpath = Path.addTrailingSlash(folderpath);
        var entries = getEntries(folderpath);
        var out = sys.io.File.write(outputpath, true);
        var zip = new haxe.zip.Writer(out);
        zip.write(entries);
        out.close();
    }

    // taken from the Haxe Cookbook: https://code.haxe.org/category/other/haxe-zip.html
    static function getEntries(dir:String, entries:List<haxe.zip.Entry> = null, inDir:Null<String> = null)
    {
        if (entries == null) entries = new List<haxe.zip.Entry>();
        if (inDir == null) inDir = dir;
        for(file in sys.FileSystem.readDirectory(dir)) {
            var path = haxe.io.Path.join([dir, file]);
            if (sys.FileSystem.isDirectory(path)) {
                getEntries(path, entries, inDir);
            } else {
                var bytes:haxe.io.Bytes = haxe.io.Bytes.ofData(sys.io.File.getBytes(path).getData());
                var entry:haxe.zip.Entry = {
                    fileName: StringTools.replace(path, inDir, ""), 
                    fileSize: bytes.length,
                    fileTime: Date.now(),
                    compressed: false,
                    dataSize: sys.FileSystem.stat(path).size,
                    data: bytes,
                    crc32: haxe.crypto.Crc32.make(bytes)
                };
                entries.push(entry);
            }
        }
        return entries;
    }
    #end

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
                // do nothing with plain directory entries
            } 
            else
            {
                zipfs.addFileBytes(_entry.fileName, data);
            }
        }

        return zipfs;
    }
}