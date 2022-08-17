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
  private var _fileHandle:FileInput;

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
    this._fileHandle = File.read(this.fileName);

    findEndOfCentralDirectoryRecord();
    getAllCentralDirectoryHeaders();
  }

    function findEndOfCentralDirectoryRecord():Void
    {
      _fileHandle.seek(-22, SeekEnd); // 22 is the smallest the eocd can be, so we start here
        var tmpbuf = Bytes.alloc(4);
        _fileHandle.readBytes(tmpbuf, 0, 4);
        // keep sliding backwards until we find a signature match (dunno if this is the best way to do this but it works)
        while (tmpbuf.getInt32(0) != EndOfCentralDirectoryRecord.SIGNATURE)
        {
            _fileHandle.seek(-5, SeekCur);
            _fileHandle.readBytes(tmpbuf, 0, 4);
        }
        this.endOfCentralDirectoryRecord = new EndOfCentralDirectoryRecord(_fileHandle, -4);
    }

    function getAllCentralDirectoryHeaders():Void
    {
        this.centralDirectoryRecords = new StringMap();
        _fileHandle.seek(this.endOfCentralDirectoryRecord.centralDirOffset, SeekBegin);
        for(_ in 0...this.endOfCentralDirectoryRecord.totalCdrs)
        {
            var cdh = new CentralDirectoryFileHeader(_fileHandle);
            this.centralDirectoryRecords.set(cdh.filename, cdh);
        }
    }

    public function getLocalFileHeaderOf(localFileName:String)
    {
      _fileHandle = File.read(this.fileName);
        var cdfh = centralDirectoryRecords.get(localFileName);
        if(cdfh == null)
        {
            Polymod.warning(FILE_MISSING, 'The file $localFileName was not found in the zip: $fileName');
            return null;
        }
        _fileHandle.seek(cdfh.localfileheaderoffset, SeekBegin);
        var lfh = new LocalFileHeader(_fileHandle);
        lfh.dataoffset = _fileHandle.tell();
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
* Just the common stuff I found on all the diffrent zip headers
**/
private class Header
{
    var _tmp_buf:Bytes;
    public var signature:Bytes;
    var fileinput:FileInput;

    function _getBytesFromFile(nbytes:Int)
    {
        if(nbytes == 0)
            return Bytes.alloc(0);
        _tmp_buf = Bytes.alloc(nbytes);
        var bytesread = fileinput.readBytes(_tmp_buf, 0, nbytes);
        if(bytesread != nbytes)
        {
            trace('[NOTICE] Read fewer bytes than requested');
        }
        return _tmp_buf;
    }

    // Copied from haxe.zip (kinda)
    function parseMSDOSdate(_lastModifiedTime:Bytes, _lastModifiedDate:Bytes)
    {
        var timenum:Int = _lastModifiedTime.getUInt16(0);
        var bits_0to4 = timenum & 0x1F;
        var bits_5to10 = (timenum >> 5) & 0x3F;
        var bits_11to15 = (timenum >> 11) & 0x1F;

        var seconds:Int = bits_0to4*2;
        var minutes:Int = bits_5to10 % 60;
        var hours:Int = bits_11to15 % 24;

        var datenum:Int = _lastModifiedDate.getUInt16(0);
        bits_0to4 = datenum & 0x1F;
        var bits_5to8 = (datenum >> 5) & 0xF;
        var bits_9to15 = (datenum >> 9);

        var date = bits_0to4 % 31;
        var month = (bits_5to8-1)%12;
        var year = 1980 + bits_9to15;

        return new Date(year, month, date, hours, minutes, seconds);
    }
}

class LocalFileHeader extends Header
{
    public var minVersionForExtraction:Int;
    public var generalPurposeBitFlag:Bytes;
    public var compressionMethod:CompressionMethod;
    public var lastModifiedDateTime:Date;
    public var crc32code:Bytes;
    public var compressedSize:Int;
    public var uncompressedSize:Int;
    public var filename:String;
    public var extrafield:Bytes;
    public var bytesConsumed:Int;
    public var dataoffset:Int = -1; // offset in the file from where to read the data

    public static final HEADER_SIGNATURE = 0x04034B50;

    public function new(fi:FileInput, ?startoffset:Int = 0)
    {
        fileinput = fi;
        fileinput.seek(startoffset, SeekCur);

        signature = _getBytesFromFile(4);

        var _minVersion = _getBytesFromFile(2);
        minVersionForExtraction = _minVersion.getUInt16(0);

        generalPurposeBitFlag = _getBytesFromFile(2);

        var _compressionMethod = _getBytesFromFile(2);
        compressionMethod = (_compressionMethod.getUInt16(0) == 0) ? NONE : DEFLATE;
        
        var _lastModifiedTime = _getBytesFromFile(2);
        var _lastModifiedDate = _getBytesFromFile(2);
        lastModifiedDateTime = parseMSDOSdate(_lastModifiedTime, _lastModifiedDate);
        
        crc32code = _getBytesFromFile(4);

        var _compressedSize = _getBytesFromFile(4);
        compressedSize = _compressedSize.getInt32(0);

        var _uncompressedSize = _getBytesFromFile(4);
        uncompressedSize = _uncompressedSize.getInt32(0);

        var _filenamelen = _getBytesFromFile(2);
        var _extrafieldlen = _getBytesFromFile(2);
        
        var _filename = _getBytesFromFile(_filenamelen.getUInt16(0));
        filename = _filename.toString();
        
        extrafield = _getBytesFromFile(_extrafieldlen.getUInt16(0));
        
        bytesConsumed = 30 + _filenamelen.getUInt16(0) + _extrafieldlen.getUInt16(0) - 1;
    }

    public function readData()
    {
        // trace('fileinput is $fileinput');
        fileinput.seek(dataoffset, SeekBegin);
        var buf = Bytes.alloc(compressedSize);
        var bytesread = fileinput.readBytes(buf, 0, compressedSize);
        if(bytesread != compressedSize)
        {
            trace('[WARNING] Bytes read was fewer than requested (Requested: $compressedSize, Read: $bytesread)');
        }
        // fileinput.close();
        return buf;
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
        file name: $filename
        extra field bits: ${extrafield.toHex()}
        bytes consumed: $bytesConsumed
        ';
    }
}

class CentralDirectoryFileHeader extends Header
{
    public var versionMadeBy:Int;
    public var versionToExtract:Int;
    
    var generalPurposeBitFlag:Bytes;
    
    public var compressionMethod:CompressionMethod;
    public var lastModifiedDateTime:Date;

    var crc32code:Bytes;

    public var compressedSize:Int;
    public var uncompressedSize:Int;

    var filenamelength:Int;
    var extrafieldlength:Int;
    var filecommentLength:Int;
    
    public var disknum:Int;

    // not sure what to do with these yet
    var _internalfileattrib:Bytes;
    var _externalfileattib:Bytes;

    public var localfileheaderoffset:Int;
    public var filename:String;
    public var extrafield:Bytes;
    public var filecomment:String;
    public var bytesConsumed:Int;

    public static final HEADER_SIGNATURE = 0x02014B50;

    public function new(fi:FileInput, ?startoffset:Int = 0)
    {
        fileinput = fi;
        fileinput.seek(startoffset, SeekCur);
        signature = _getBytesFromFile(4);
        var _verMadeBy = _getBytesFromFile(2);
        versionMadeBy = _verMadeBy.getUInt16(0);
        
        var _verToExtract = _getBytesFromFile(2);
        versionToExtract = _verToExtract.getUInt16(0);
        
        generalPurposeBitFlag = _getBytesFromFile(2);
        
        var _compressionMethod = _getBytesFromFile(2);
        compressionMethod = (_compressionMethod.getUInt16(0) == 0) ? NONE : DEFLATE;
        
        var _lastModifiedTime = _getBytesFromFile(2);
        var _lastModifiedDate = _getBytesFromFile(2);
        lastModifiedDateTime = parseMSDOSdate(_lastModifiedTime, _lastModifiedDate);
        
        crc32code = _getBytesFromFile(4);
        
        var _compressedSize = _getBytesFromFile(4);
        compressedSize = _compressedSize.getInt32(0);
        
        var _uncompressedSize = _getBytesFromFile(4);
        uncompressedSize = _uncompressedSize.getInt32(0);
        
        var _filenamelength = _getBytesFromFile(2);
        filenamelength = _filenamelength.getUInt16(0);
        
        var _extrafieldlength = _getBytesFromFile(2);
        extrafieldlength = _extrafieldlength.getUInt16(0);
        
        var _filecommentlength = _getBytesFromFile(2);
        filecommentLength = _filecommentlength.getUInt16(0);
        
        var _disknum = _getBytesFromFile(2);
        disknum = _disknum.getUInt16(0);
        
        _internalfileattrib = _getBytesFromFile(2);
        _externalfileattib = _getBytesFromFile(4);
        
        var _localfileheaderoffset = _getBytesFromFile(4);
        localfileheaderoffset = _localfileheaderoffset.getInt32(0);
        
        var _filename = _getBytesFromFile(filenamelength);
        filename = _filename.toString();
        
        extrafield = _getBytesFromFile(extrafieldlength);
        
        var _filecomment = _getBytesFromFile(filecommentLength);
        filecomment = _filecomment.toString();
        
        bytesConsumed = 46 + filenamelength + extrafieldlength+ filecommentLength - 1;
    }

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
        disk number: $disknum
        internal file attribute: ${_internalfileattrib.toHex()}
        external file attribute: ${_externalfileattib.toHex()}
        local file header offset: $localfileheaderoffset
        file name: $filename
        extra field length (in hex): 0x${StringTools.hex(extrafieldlength)}
        extra field: 0x${extrafield.toHex()}
        file comment: $filecomment
        bytes consumed: $bytesConsumed
        ';
    }
}

class EndOfCentralDirectoryRecord extends Header
{
    public var disknum:Int;
    public var diskOfCentralDirectoryStart:Int;
    public var numCdrsInCurDisk:Int;
    public var totalCdrs:Int;
    public var centralDirSize:Int;
    public var centralDirOffset:Int;

    var commentlength:Int;
    public var comment:String;

    public static final SIGNATURE = 0x06054b50;
    public function new(fi:FileInput, ?startoffset:Int=0)
    {
        fileinput = fi;
        fileinput.seek(startoffset, SeekCur);

        signature = _getBytesFromFile(4);

        disknum = _getBytesFromFile(2).getUInt16(0); // 0xffff = 65535
        diskOfCentralDirectoryStart = _getBytesFromFile(2).getUInt16(0);

        numCdrsInCurDisk = _getBytesFromFile(2).getUInt16(0);
        totalCdrs = _getBytesFromFile(2).getUInt16(0);

        centralDirSize = _getBytesFromFile(4).getInt32(0);
        centralDirOffset = _getBytesFromFile(4).getInt32(0);

        commentlength = _getBytesFromFile(2).getUInt16(0);
        comment = _getBytesFromFile(commentlength).toString();
        // bytes consumed = 22 + comment.length
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
        comment: $comment
        ';
    }
}
#end // #if sys