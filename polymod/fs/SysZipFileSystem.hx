package polymod.fs;

import haxe.io.Bytes;
import haxe.io.Path;
import polymod.Polymod.ModMetadata;
import polymod.fs.MemoryZipFileSystem.ZipFileSystemParams;
import polymod.util.Util;
import thx.semver.VersionRule;
#if sys
import polymod.util.zip.ZipParser;
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
 * An implementation of an IFileSystem that can access files from an un-compressed zip archive.
 * Useful for loading mods from zip files.
 * Compatible only with native targets. Currently does not support compressed zip files.
 */
class SysZipFileSystem extends MemoryFileSystem
{
  /**
   * Specifies the name of the ZIP that contains each file.
   */
  var filesLocations:Map<String, String>;

  /**
   * The wrappers for each ZIP file that is loaded.
   */
  var zipParsers:Map<String, ZipParser>;

	public function new(params:ZipFileSystemParams) {
		super(params);
	}

  /**
   * Retrieve file bytes by pulling them from the ZIP file.
   */
	public override function getFileBytes(path:String):Null<Bytes> {
		if (!filesLocations.exists(path)) {
      // Fallback to the inner MemoryFileSystem.
      return super.getFileBytes(path);
		} else {
		  // strip the leading 'mods/' part of the file
		  if (StringTools.startsWith(path, 'mods/'))
		    path = path.substring(5);
      
      // Rather than going to the `files` map for the contents (which are empty),
      // we go directly to the zip file and extract the individual file.
		  var fileHeader = zipParser.getLocalFileHeaderOf(path);
		  var fileBytes = fileHeader.readData();
		  return fileBytes;
    }
	}

  public function addZipFileByPath(zipPath:String) {
    zipParser = new ZipParser(zipPath);
    
    // SysZipFileSystem doesn't actually use the internal `files` map.
    // We populate it here simply so we know the files are there.
		for (fileName => fileHeader in zipParser.centralDirectoryRecords) {
			if (fileHeader.compressedSize != 0 && fileHeader.uncompressedSize != 0 && !StringTools.endsWith(fileHeader.fileName, '/')) {
				trace('Adding file $fileName');
				filesLocations.set('mods/$fileName', zipPath);
			}
		}
  }

  public function addZipFileByBytes()

	public function initFileSystem(zipPath:String)
	{

	}
}
#end
