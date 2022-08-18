package polymod.fs;

// import format.zip.Reader;
import haxe.ds.StringMap;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.Path;
import haxe.zip.InflateImpl;
import polymod.fs.PolymodFileSystem.IFileSystem;
import polymod.fs.PolymodFileSystem.PolymodFileSystemParams;
import polymod.util.Util;

#if html5
class MemoryZipFileSystem extends StubFileSystem
{
	public function new(params:PolymodFileSystemParams)
	{
		super(params);
		Polymod.warning(FUNCTIONALITY_NOT_IMPLEMENTED, "This file system not supported for this platform, and is only intended for use in html5");
	}
}
#else

/**
 * An implementation of an IFileSystem that can access files from an un-compressed zip archive.
 * Useful for loading mods from zip files.
 * Currently does not support compressed zip files. Recommended for use in html5 only.
 */
class MemoryZipFileSystem extends MemoryFileSystem
{
	public function new(params:ZipFileSystemParams)
	{
		super(params);
	}

	#if !debug
	/**
	 * Prints the metadata of a ZIP file entry. Used for debugging.
	 */
	function printEntry(e:haxe.zip.Entry)
	{
		trace('
			datasize: ${e.dataSize},
			data: ${e.data.length},
			crc32: ${e.crc32},
			filename: ${e.fileName},
			filesize: ${e.fileSize}
			fileTime: ${e.fileTime},
			compressed: ${e.compressed},
			extraFields: ${e.extraFields.toString()}');
	}
	#end

	/**
	 * Extracts the contents of a zip file (provided as bytes) and stores the contents in the MemoryFileSystem.
	 * 
	 * @see https://github.com/HaxeFoundation/haxe.org-comments/issues/41#issuecomment-845576836
	 */
	public function addZipFile(zipName:String, zipBytes:Bytes)
	{
		var bytesInput = new haxe.io.BytesInput(zipBytes);
		var reader = new haxe.zip.Reader(bytesInput);

		// Read the zip file entries.
		var entries:List<haxe.zip.Entry> = reader.read();
		for (zipEntry in entries)
		{
			var entryData = haxe.zip.Reader.unzip(zipEntry);
			if (zipEntry.fileName.substring(zipEntry.fileName.lastIndexOf('/') + 1) == '' && _entry.data.toString() == '')
			{
				// This is a directory entry.
			}
			else
			{
				// This is a file entry! Register it in the MemoryFileSystem.
				addFileBytes('mods/${zipEntry.fileName}', entryData);
			}
		}
	}
}
#end
