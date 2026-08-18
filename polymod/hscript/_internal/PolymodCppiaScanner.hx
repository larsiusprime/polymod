package polymod.hscript._internal;

/**
 * Reads the header of a compiled script.
 */
class PolymodCppiaScanner
{
  /**
   * Every type a compiled script references.
   * @throws String if the file is not a cppia we can read.
   */
  public static function readTypes(data:haxe.io.Bytes):Array<String>
  {
    if (data == null || data.length == 0) throw 'empty file';

    var reader = new CppiaHeaderReader(data);

    var magic:String = reader.token();
    if (magic != 'CPPIA' && magic != 'CPPIB') throw 'not a compiled script, magic was "$magic"';

    var stringCount:Int = reader.int();
    if (stringCount < 0) throw 'bad string count $stringCount';
    for (_ in 0...stringCount)
      reader.skipString();

    var typeCount:Int = reader.int();
    if (typeCount < 0) throw 'bad type count $typeCount';

    return [for (_ in 0...typeCount) reader.string()];
  }
}

/**
 * Walks a `CppiaStream` to read the header of a compiled script.
 */
private class CppiaHeaderReader
{
  final data:haxe.io.Bytes;

  var pos:Int = 0;

  public function new(data:haxe.io.Bytes)
  {
    this.data = data;
  }

  public function token():String
  {
    skipWhitespace();
    var start:Int = pos;
    while (pos < data.length && data.get(pos) > 32)
      pos++;
    return data.getString(start, pos - start);
  }

  public function int():Int
  {
    skipWhitespace();

    var result:Int = 0;
    var sign:Int = 1;
    var digits:Int = 0;

    while (pos < data.length && data.get(pos) > 32)
    {
      var c:Int = data.get(pos);
      if (c == '-'.code)
      {
        sign = -1;
      }
      else
      {
        var digit:Int = c - '0'.code;
        if (digit < 0 || digit > 9) throw 'expected a digit at byte $pos';
        result = result * 10 + digit;
        digits++;
      }
      pos++;
    }

    if (digits == 0) throw 'expected a number at byte $pos';

    return result * sign;
  }

  public function string():String
  {
    var start:Int = takeString();
    return data.getString(start, pos - start);
  }

  public function skipString():Void
  {
    takeString();
  }

  /**
   * Advance past one length prefixed string.
   * @return Where its bytes started.
   */
  function takeString():Int
  {
    var len:Int = int();
    if (len < 0) throw 'bad string length $len at byte $pos';

    // One separator byte sits between the length and the bytes.
    pos++;

    var start:Int = pos;
    pos += len;
    if (pos > data.length) throw 'ran off the end of the file';

    return start;
  }

  function skipWhitespace():Void
  {
    while (true)
    {
      while (pos < data.length && data.get(pos) <= 32)
        pos++;

      if (pos < data.length && data.get(pos) == '#'.code)
      {
        while (pos < data.length && data.get(pos) != '\n'.code)
          pos++;
      }
      else
      {
        break;
      }
    }
  }
}
