package polymod.util.zip;

#if sys
import haxe.ds.StringMap;
import haxe.io.Bytes;
import sys.io.File;
import sys.io.FileInput;

/**
 * Parses the Central Directory Headers of a ZIP file on the file system.
 * This allows individual files to be directly accessed without having to
 * decompress the entire ZIP file.
 * 
 * Only compatible with `sys` targets with native file system access.
 */
class ZipParser
{
	/**
	 * The file system path to the ZIP file.
	 */
	public var fileName:String;

	/**
	 * A handle to the ZIP file for direct reading.
	 */
	private var fileHandle:FileInput;

	/**
	 * The end-of-central-directory record, as parsed from the end of the ZIP file.
	 */
	public var endOfCentralDirectoryRecord:EndOfCentralDirectoryRecord;

	/**
	 * The central directory records, as parsed from the central directory.
	 * These contain metadata about each file in the archive.
	 */
	public var centralDirectoryRecords:StringMap<CentralDirectoryFileHeader>;

	public function new(fileName:String)
	{
		this.fileName = fileName;
		this.fileHandle = File.read(this.fileName);

		findEndOfCentralDirectoryRecord();
		getAllCentralDirectoryHeaders();
	}

	function findEndOfCentralDirectoryRecord():Void
	{
		fileHandle.seek(-22, SeekEnd); // 22 is the smallest the eocd can be, so we start here
		var tmpbuf = Bytes.alloc(4);
		fileHandle.readBytes(tmpbuf, 0, 4);
		// keep sliding backwards until we find a signature match (dunno if this is the best way to do this but it works)
		while (tmpbuf.getInt32(0) != EndOfCentralDirectoryRecord.SIGNATURE)
		{
			fileHandle.seek(-5, SeekCur);
			fileHandle.readBytes(tmpbuf, 0, 4);
		}
		this.endOfCentralDirectoryRecord = new EndOfCentralDirectoryRecord(fileHandle, -4);
	}

	function getAllCentralDirectoryHeaders():Void
	{
		this.centralDirectoryRecords = new StringMap();
		fileHandle.seek(this.endOfCentralDirectoryRecord.centralDirOffset, SeekBegin);
		for (_ in 0...this.endOfCentralDirectoryRecord.totalCdrs)
		{
			var cdh = new CentralDirectoryFileHeader(fileHandle);
			this.centralDirectoryRecords.set(cdh.fileName, cdh);
		}
	}

	public function getLocalFileHeaderOf(localFileName:String)
	{
		fileHandle = File.read(this.fileName);
		var cdfh = centralDirectoryRecords.get(localFileName);
		if (cdfh == null)
		{
			Polymod.warning(FILE_MISSING, 'The file $localFileName was not found in the zip: $fileName');
			return null;
		}
		fileHandle.seek(cdfh.localFileHeaderOffset, SeekBegin);
		var lfh = new LocalFileHeader(fileHandle);
		lfh.dataOffset = fileHandle.tell();
		// _fi.close();
		return lfh;
	}
}

enum CompressionMethod
{
	NONE;
	DEFLATE;
}

/**
 * Common functionality for all ZIP headers.
 */
private class Header
{
	private var fileInput:FileInput;

	public var signature:Bytes;

	private var tmpBuffer:Bytes;

	private function getBytesFromFile(count:Int)
	{
		if (count == 0)
			return Bytes.alloc(0);
		tmpBuffer = Bytes.alloc(count);
		var bytesRead = fileInput.readBytes(tmpBuffer, 0, count);
		if (bytesRead != count)
		{
			trace('[NOTICE] Read fewer bytes than requested ($bytesRead < $count)');
		}
		return tmpBuffer;
	}

	// Copied from haxe.zip (kinda)
	function parseMSDOSdate(lastModifiedTime:Bytes, lastModifiedDate:Bytes)
	{
		var timeNum:Int = lastModifiedTime.getUInt16(0);
		var bits_0to4 = timeNum & 0x1F;
		var bits_5to10 = (timeNum >> 5) & 0x3F;
		var bits_11to15 = (timeNum >> 11) & 0x1F;

		var hours:Int = bits_11to15 % 24;
		var minutes:Int = bits_5to10 % 60;
		var seconds:Int = bits_0to4 * 2;

		var dateNum:Int = lastModifiedDate.getUInt16(0);
		bits_0to4 = dateNum & 0x1F;
		var bits_5to8 = (dateNum >> 5) & 0xF;
		var bits_9to15 = (dateNum >> 9);

		var year = 1980 + bits_9to15;
		var month = (bits_5to8 - 1) % 12;
		var date = bits_0to4 % 31;

		return new Date(year, month, date, hours, minutes, seconds);
	}
}

/**
 * The local file header for a file in a ZIP file.
 */
class LocalFileHeader extends Header
{
	public var bytesConsumed:Int;
	public var compressedSize:Int;
	public var compressionMethod:CompressionMethod;
	public var crc32code:Bytes;
	public var dataOffset:Int = -1; // offset in the file from where to read the data
	public var extraField:Bytes;
	public var fileName:String;
	public var generalPurposeBitFlag:Bytes;
	public var lastModifiedDateTime:Date;
	public var minVersionForExtraction:Int;
	public var uncompressedSize:Int;

	public static final HEADER_SIGNATURE = 0x04034B50;

	public function new(fileInput:FileInput, ?startOffset:Int = 0)
	{
		this.fileInput = fileInput;
		this.fileInput.seek(startOffset, SeekCur);

		signature = getBytesFromFile(4);

		minVersionForExtraction = getBytesFromFile(2).getUInt16(0);
		generalPurposeBitFlag = getBytesFromFile(2);
		compressionMethod = (getBytesFromFile(2).getUInt16(0) == 0) ? NONE : DEFLATE;

		var lastModifiedTime = getBytesFromFile(2);
		var lastModifiedDate = getBytesFromFile(2);
		lastModifiedDateTime = parseMSDOSdate(lastModifiedTime, lastModifiedDate);

		crc32code = getBytesFromFile(4);

		compressedSize = getBytesFromFile(4).getInt32(0);
		uncompressedSize = getBytesFromFile(4).getInt32(0);

		var fileNameLength = getBytesFromFile(2);
		var extraFieldLength = getBytesFromFile(2);

		fileName = getBytesFromFile(fileNameLength.getUInt16(0)).toString();

		extraField = getBytesFromFile(extraFieldLength.getUInt16(0));

		bytesConsumed = 30 + fileNameLength.getUInt16(0) + extraFieldLength.getUInt16(0) - 1;
	}

	/**
	 * Reads and decompresses the bytes of the local file from the input ZIP it is associated with.
	 */
	public function readData():Bytes
	{
		fileInput.seek(dataOffset, SeekBegin);
		var bytesBuf = new haxe.io.BytesBuffer();
		
		var bytesToReturn = Bytes.alloc(compressedSize);
		var bytesRead = fileInput.readBytes(bytesToReturn, 0, compressedSize);

		if (bytesRead < compressedSize)
		{
			// trace('[WARNING] Bytes read was fewer than requested (Requested: $compressedSize, Read: $bytesRead)');
			bytesBuf.addBytes(bytesToReturn, 0, bytesRead);
			while (bytesRead < compressedSize)
			{
				bytesRead += fileInput.readBytes(bytesToReturn, 0, compressedSize - bytesRead);
				bytesBuf.addBytes(bytesToReturn, 0, compressedSize - bytesRead);
			}
			return (this.compressionMethod == DEFLATE) ? Util.unzipBytes(bytesBuf.getBytes()) : bytesBuf.getBytes();
		}

		return (this.compressionMethod == DEFLATE) ? Util.unzipBytes(bytesToReturn) : bytesToReturn;
	}

	public function isValid()
	{
		return signature.getInt32(0) == HEADER_SIGNATURE; // Std.parseInt(HEADER_SIGNATURE);
	}

	public function toString()
	{
		return '
        signature: ${signature.toHex()}
        minimum version to extract: $minVersionForExtraction
        general purpose bit flags: ${generalPurposeBitFlag.toHex()}
        compression method: $compressionMethod
        last modified date: $lastModifiedDateTime
        crc32: $crc32code
        compressed size: $compressedSize
        uncompressed size: $uncompressedSize
        file name: $fileName
        extra field bits: ${extraField.toHex()}
        bytes consumed: $bytesConsumed
        ';
	}
}

/**
 * The central directory file header for a file in a ZIP file.
 */
class CentralDirectoryFileHeader extends Header
{
	public var versionMadeBy:Int;
	public var versionToExtract:Int;

	private var generalPurposeBitFlag:Bytes;

	public var compressionMethod:CompressionMethod;
	public var lastModifiedDateTime:Date;

	private var crc32code:Bytes;

	public var compressedSize:Int;
	public var uncompressedSize:Int;

	private var fileNameLength:Int;
	private var extraFieldLength:Int;
	private var fileCommentLength:Int;

	public var diskNum:Int;

	// not sure what to do with these yet
	private var internalFileAttrib:Bytes;
	private var externalFileAttrib:Bytes;

	public var localFileHeaderOffset:Int;
	public var fileName:String;
	public var extraField:Bytes;
	public var fileComment:String;
	public var bytesConsumed:Int;

	public static final HEADER_SIGNATURE = 0x02014B50;

	public function new(fileInput:FileInput, ?startOffset:Int = 0)
	{
		this.fileInput = fileInput;
		this.fileInput.seek(startOffset, SeekCur);

		// These fields are being read in the order they are defined in the spec.
		// Do not change the order.

		signature = getBytesFromFile(4);
		versionMadeBy = getBytesFromFile(2).getUInt16(0);
		versionToExtract = getBytesFromFile(2).getUInt16(0);
		generalPurposeBitFlag = getBytesFromFile(2);
		compressionMethod = (getBytesFromFile(2).getUInt16(0) == 0) ? NONE : DEFLATE;

		var lastModifiedTime = getBytesFromFile(2);
		var lastModifiedDate = getBytesFromFile(2);
		lastModifiedDateTime = parseMSDOSdate(lastModifiedTime, lastModifiedDate);

		crc32code = getBytesFromFile(4);
		compressedSize = getBytesFromFile(4).getInt32(0);
		uncompressedSize = getBytesFromFile(4).getInt32(0);

		fileNameLength = getBytesFromFile(2).getUInt16(0);
		extraFieldLength = getBytesFromFile(2).getUInt16(0);
		fileCommentLength = getBytesFromFile(2).getUInt16(0);
		
		diskNum = getBytesFromFile(2).getUInt16(0);
		internalFileAttrib = getBytesFromFile(2);
		externalFileAttrib = getBytesFromFile(4);
		localFileHeaderOffset = getBytesFromFile(4).getInt32(0);

		fileName = getBytesFromFile(fileNameLength).toString();
		extraField = getBytesFromFile(extraFieldLength);
		fileComment = getBytesFromFile(fileCommentLength).toString();

		bytesConsumed = 46 + fileNameLength + extraFieldLength + fileCommentLength - 1;
	}

	/**
	 * Validate the header signature matches the expected value.
	 */
	public function isValid()
	{
		return signature.getInt32(0) == HEADER_SIGNATURE;
	}

	public function toString()
	{
		return '
        version made by: $versionMadeBy
        version to extract: $versionToExtract
        general purpose bit flags: ${generalPurposeBitFlag.toHex()}
        compression method: $compressionMethod
        last modified date: $lastModifiedDateTime
        crc32: ${crc32code.toHex()}
        compressed size: $compressedSize
        uncompressed size: $uncompressedSize
        disk number: $diskNum
        internal file attribute: ${internalFileAttrib.toHex()}
        external file attribute: ${externalFileAttrib.toHex()}
        local file header offset: $localFileHeaderOffset
        file name: $fileName
        extra field length (in hex): 0x${StringTools.hex(extraFieldLength)}
        extra field: 0x${extraField.toHex()}
        file comment: $fileComment
        bytes consumed: $bytesConsumed
        ';
	}
}

/**
 * The end of central directory record for a ZIP file.
 * Provides information like how many central directory records are present in the file.
 */
class EndOfCentralDirectoryRecord extends Header
{
	public var disknum:Int;
	public var diskOfCentralDirectoryStart:Int;
	public var numCdrsInCurDisk:Int;
	public var totalCdrs:Int;
	public var centralDirSize:Int;
	public var centralDirOffset:Int;

	private var commentLength:Int;

	public var comment:String;

	public static final SIGNATURE = 0x06054b50;

	public function new(fileInput:FileInput, ?startOffset:Int = 0)
	{
		this.fileInput = fileInput;
		this.fileInput.seek(startOffset, SeekCur);

		signature = getBytesFromFile(4);

		disknum = getBytesFromFile(2).getUInt16(0); // 0xffff = 65535
		diskOfCentralDirectoryStart = getBytesFromFile(2).getUInt16(0);

		numCdrsInCurDisk = getBytesFromFile(2).getUInt16(0);
		totalCdrs = getBytesFromFile(2).getUInt16(0);

		centralDirSize = getBytesFromFile(4).getInt32(0);
		centralDirOffset = getBytesFromFile(4).getInt32(0);

		commentLength = getBytesFromFile(2).getUInt16(0);
		comment = getBytesFromFile(commentLength).toString();
	}

	public function toString()
	{
		return '
	        signature: ${signature.toHex()} | ${signature.getInt32(0)}
	        disk no.: $disknum
	        disk no. where central directory starts: $diskOfCentralDirectoryStart
	        no. of central directory records on this disk: $numCdrsInCurDisk
	        size of central directory in bytes: $centralDirSize
	        offset of start of central directory, relative to start of archive: $centralDirOffset
	        comment: $comment';
	}
}
#end // #if sys
