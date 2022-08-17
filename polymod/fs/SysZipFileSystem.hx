package polymod.fs;

import haxe.io.Bytes;
import haxe.io.Path;
import polymod.Polymod.ModMetadata;
import polymod.fs.MemoryZipFileSystem.ZipFileSystemParams;
import polymod.util.Util;
import thx.semver.VersionRule;
#if sys
import polymod.util.ZipParser;
import sys.io.File;
#end

#if !sys
class SysZipFileSystem extends StubFileSystem
{
	public function new(params:PolymodFileSystemParams)
	{
		super(params);
		Polymod.warning(FUNCTIONALITY_NOT_IMPLEMENTED, "This file system not supported for this platform, and is only intended for use on sys targets");
	}
}
#else
/**
 * An implementation of an IFileSystem that can access files from an un-compressed zip archive, for use on sys-targets
 * Useful for loading mods from zip files.
 * Currently does not support compressed zip files.
 */
class SysZipFileSystem extends MemoryFileSystem
{
	var zipparser:ZipParser;

	public function new(params:ZipFileSystemParams)
	{
		super(params);
		var zipname = (params.zipName != null) ? params.zipName : "";
		var zippath = (params.zipPath != null) ? params.zipPath : "";
		initFileSystem(zippath, zipname);
	}

	public override function getFileContent(path:String):Null<String>
	{
		var data:Bytes = getFileBytes(path);
		if (data == null)
		{
			return null;
		}
		return data.toString();
	}

	public override function getFileBytes(path:String):Null<Bytes>
	{
		if (!files.exists(path))
		{
			return null;
		}
		// strip the leading 'mods/' part of the file
		if (StringTools.startsWith(path, 'mods/'))
			path = path.substring(5);
		var lfh = zipparser.getLocalFileHeaderOf(path);
		var data = lfh.readData();
		return data;
	}

	public function initFileSystem(zippath:String, zipname:String)
	{
		zipparser = new ZipParser(zippath);
		for (fname => cdfh in zipparser.centraldirrecords)
		{
			if (cdfh.compressedSize != 0 && cdfh.uncompressedSize != 0 && !StringTools.endsWith(cdfh.filename, '/'))
			{
				trace('adding $fname');
				addFileBytes('mods/$fname', null); // doing this just so directories get filled up
			}
		}
	}
}
#end
