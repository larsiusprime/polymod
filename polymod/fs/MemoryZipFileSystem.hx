package polymod.fs;

// import format.zip.Reader;
import haxe.ds.StringMap;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.Path;
import haxe.zip.Entry;
import haxe.zip.InflateImpl;
import polymod.fs.PolymodFileSystem.IFileSystem;
import polymod.fs.PolymodFileSystem.PolymodFileSystemParams;
import polymod.util.Util;

typedef ZipFileSystemParams =
{
	> PolymodFileSystemParams,
	/**
	 * Name of the zip file which was read
	 */
	?zipName:String,

	/**
	 * Bytes of the zip file (only needed for html5)
	**/
	?zipBytes:Bytes,
	/**
	 * Path to the zip file (needed if you're using ZipFileSystem on a sys target)
	 */
	?zipPath:String
};

#if !html5
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
 * Recommended for use in html5 only.
 * Currently does not support compressed zip files.
 */
class MemoryZipFileSystem extends MemoryFileSystem
{
	public function new(params:ZipFileSystemParams)
	{
		super(params);
		if (params.zipBytes != null && params.zipName != null)
		{
			initFileSystem(params.zipBytes, params.zipName);
		}
		// TODO: Move below stuff into a sys-specific zip file system
		// #elseif sys
		// if (params.zipPath != null)
		// {
		// 	var i = new BytesInput(sys.io.File.getBytes(params.zipPath));
		// 	var reader = new format.zip.Reader(i);
		// 	var tmp = null;
		// 	while (true)
		// 	{
		// 		var e = reader.readEntryHeader();

		// 		if (e == null)
		// 			break;
		// 		if (e.dataSize < 0)
		// 		{
		// 			var bufSize = 65536;
		// 			if (tmp == null)
		// 				tmp = haxe.io.Bytes.alloc(bufSize);
		// 			var out = new haxe.io.BytesBuffer();
		// 			var z = new InflateImpl(i, false, false);
		// 			while (true)
		// 			{
		// 				var n = z.readBytes(tmp, 0, bufSize);
		// 				out.addBytes(tmp, 0, n);
		// 				if (n < bufSize)
		// 					break;
		// 			}
		// 			e.data = out.getBytes();

		// 			e.crc32 = i.readInt32();
		// 			if (e.crc32 == 0x08074b50)
		// 				e.crc32 = i.readInt32();
		// 			e.dataSize = i.readInt32();
		// 			e.fileSize = i.readInt32();
		// 			// set data to uncompressed
		// 			e.dataSize = e.fileSize;
		// 			e.compressed = false;
		// 		}
		// 		else
		// 			e.data = i.read(e.dataSize);
		// 		// fileMap.set(e.fileName, e);
		// 	}
		// }
		// #end
	}

	#if debug
	function printEntry(e:Entry)
	{
		var entrydata = '
        datasize: ${e.dataSize},
        data: ${e.data.length},
        crc32: ${e.crc32},
        filename: ${e.fileName},
        filesize: ${e.fileSize}
        fileTime: ${e.fileTime},
        compressed: ${e.compressed},
        extraFields: ${e.extraFields.toString()}';
		trace(entrydata);
	}
	#end

	public function initFileSystem(zipBytes:Bytes, zipName:String)
	{
		// slightly modified version of https://github.com/HaxeFoundation/haxe.org-comments/issues/41#issuecomment-845576836
		var bytesInput = new haxe.io.BytesInput(zipBytes);
		var reader = new haxe.zip.Reader(bytesInput);
		var entries:List<haxe.zip.Entry> = reader.read();
		for (_entry in entries)
		{
			var data = haxe.zip.Reader.unzip(_entry);
			if (_entry.fileName.substring(_entry.fileName.lastIndexOf('/') + 1) == '' && _entry.data.toString() == '')
			{
				// if(!directories.contains(_entry.fileName))
				//     directories.push(_entry.fileName);
			}
			else
			{
				addFileBytes('mods/${_entry.fileName}', data);
			}
		}
	}
}
#end
