package polymod.hscript._internal;

/**
 * What reading a compiled script turned up.
 */
class CppiaScan
{
  /**
   * True if the file used the CPPIB binary encoding.
   */
  public var binary:Bool = false;

  /**
   * The string table. Field names live here.
   */
  public var strings:Array<String> = [];

  /**
   * The type table. Index 0 is the empty name, which means Dynamic.
   */
  public var types:Array<String> = [];

  /**
   * Whether the body was actually walked, rather than skipped as having nothing to find.
   */
  public var walked:Bool = false;

  /**
   * True if the body did not read the way a compiled script should, so nothing found here can be
   * trusted.
   */
  public var suspect:Bool = false;

  /**
   * Field references worth a closer look, flattened as classId, fieldId, classId, fieldId...
   */
  public var fieldRefs:Array<Int> = [];

  /**
   * Where each of those came from, flattened as fileStringId, line, fileStringId, line...
   */
  public var fieldSites:Array<Int> = [];

  /**
   * Calls to hxcpp builtins, flattened as nameStringId, argCount, nameStringId, argCount...
   */
  public var globalCalls:Array<Int> = [];

  /**
   * Every type this module declares, mapped to its super type id followed by the type ids of the
   * interfaces it implements.
   */
  public var ancestry:Map<Int, Array<Int>> = new Map<Int, Array<Int>>();

  /**
   * Tokens the walk did not recognise, so a change in hxcpp is easy to spot.
   */
  public var unknownTokens:Array<String> = [];

  public function new() {}
}

/**
 * Reads a compiled script without running any of it.
 */
class PolymodCppiaScanner
{
  static final FIELD_OPS:Map<String, Bool> = [
    'FSTATIC' => true,
    'CALLSTATIC' => true,
    'FNAME' => true,
    'FTHISNAME' => true,
    'FLINK' => true,
    'FTHISINST' => true,
    'CALLMEMBER' => true,
    'CALLTHIS' => true,
    'CALLSUPER' => true,
    'FENUM' => true,
    'CREATEENUM' => true
  ];

  static final BODY_TOKENS:Map<String, Bool> = [
    'FUNCTION' => true, 'VAR' => true, 'TOINTERFACE' => true, 'TODYNARRAY' => true,
    'TODATAARRAY' => true, 'TOINTERFACEARRAY' => true, 'FUN' => true, 'CAST' => true,
    'BLOCK' => true, 'BREAK' => true, 'CONTINUE' => true, 'ISNULL' => true, 'NOTNULL' => true,
    'SET' => true, 'CALL' => true, 'CALLGLOBAL' => true, 'CALLSTATIC' => true,
    'CALLMEMBER' => true, 'CALLSUPER' => true, 'CALLTHIS' => true, 'CALLSUPERNEW' => true,
    'CREATEENUM' => true, 'ADEF' => true, 'IF' => true, 'IFELSE' => true, 'FNAME' => true,
    'FSTATIC' => true, 'FTHISINST' => true, 'FLINK' => true, 'FTHISNAME' => true, 'FENUM' => true,
    'THROW' => true, 'ARRAYI' => true, '++' => true, '+++' => true, '--' => true, '---' => true,
    'NEG' => true, '~' => true, '!' => true, 'TVARS' => true, 'VARDECL' => true,
    'VARDECLI' => true, 'NEW' => true, 'RETURN' => true, 'RETVAL' => true, 'POSINFO' => true,
    'OBJDEF' => true, 'CLASSOF' => true, 'WHILE' => true, 'FOR' => true, 'ENUMI' => true,
    'SWITCH' => true, 'TRY' => true, 'IMPLDYNAMIC' => true, 'i' => true, 'f' => true,
    's' => true, 'false' => true, 'true' => true, 'NULL' => true, 'THIS' => true,
    'SUPER' => true, 'CASTINT' => true, 'CASTBOOL' => true, 'INTERFACE' => true, 'CLASS' => true,
    'N' => true, 'n' => true, 'R' => true, 'C' => true, 'ENUM' => true, 'INLINE' => true,
    'MAIN' => true, 'NOMAIN' => true, 'RESOURCES' => true, 'RESO' => true, 'NOCAST' => true,
    'V' => true, '+' => true, '*' => true, '/' => true, '-' => true, '=' => true, '==' => true,
    '!=' => true, '>=' => true, '<=' => true, '>' => true, '<' => true, '&' => true, '|' => true,
    '^' => true, '&&' => true, '||' => true, '>>' => true, '>>>' => true, '<<' => true,
    '%' => true, '...' => true, '=>' => true, '+=' => true, '*=' => true, '/=' => true,
    '-=' => true, '&=' => true, '|=' => true, '^=' => true, '&&=' => true, '||=' => true,
    '>>=' => true, '>>>=' => true, '<<=' => true, '%=' => true, 'TCAST' => true
  ];

  /**
   * Every type a compiled script references.
   * @throws String if the file is not a cppia we can read.
   */
  public static function readTypes(data:haxe.io.Bytes):Array<String>
  {
    return scan(data).types;
  }

  /**
   * Read a compiled script's header, and scan it.
   * @param data The file.
   * @param wantedFields Field names to watch for. Pass null to read the header only.
   * @param wantGlobals Whether to also record calls to hxcpp builtins.
   * @throws String if the file is not a cppia we can read.
   */
  public static function scan(data:haxe.io.Bytes, ?wantedFields:Map<String, Bool>, wantGlobals:Bool = false):CppiaScan
  {
    if (data == null || data.length == 0) throw 'empty file';

    var result:CppiaScan = new CppiaScan();
    var reader = new CppiaHeaderReader(data);

    var magic:String = reader.token();
    if (magic != 'CPPIA' && magic != 'CPPIB') throw 'not a compiled script, magic was "$magic"';

    result.binary = magic == 'CPPIB';

    var stringCount:Int = reader.int();
    if (stringCount < 0) throw 'bad string count $stringCount';
    result.strings = [for (_ in 0...stringCount) reader.string()];

    var typeCount:Int = reader.int();
    if (typeCount < 0) throw 'bad type count $typeCount';
    result.types = [for (_ in 0...typeCount) reader.string()];

    if (wantedFields == null || result.binary) return result;

    var wantedIds:Map<Int, Bool> = new Map<Int, Bool>();
    var wantedAny:Bool = false;

    for (i in 0...result.strings.length)
    {
      if (wantedFields.exists(result.strings[i]))
      {
        wantedIds.set(i, true);
        wantedAny = true;
      }
    }

    var needGlobals:Bool = false;

    if (wantGlobals)
    {
      for (name in result.strings)
      {
        if (StringTools.startsWith(name, '__hxcpp_'))
        {
          needGlobals = true;
          break;
        }
      }
    }

    // Nothing this module could name is worth looking at, so the body never has to be read.
    if (!wantedAny && !needGlobals) return result;

    walk(reader, result, wantedIds, needGlobals);
    return result;
  }

  /**
   * Read the body a token at a time, picking out the few expressions that name a field.
   */
  static function walk(reader:CppiaHeaderReader, result:CppiaScan, wantedIds:Map<Int, Bool>, wantGlobals:Bool):Void
  {
    result.walked = true;

    var fileId:Int = 0;
    var line:Int = 0;

    while (reader.hasMore())
    {
      var token:String = reader.token();
      if (token.length == 0) break;

      var number:Null<Int> = numberOf(token);
      if (number != null)
      {
        fileId = line;
        line = number;
        continue;
      }

      if (token == 'RESOURCES') break;

      if (token == 'CLASS' || token == 'INTERFACE')
      {
        var typeId:Null<Int> = reader.intOrNull();
        var superId:Null<Int> = reader.intOrNull();
        var implementCount:Null<Int> = reader.intOrNull();

        if (typeId == null || superId == null || implementCount == null || implementCount < 0)
        {
          result.suspect = true;
          return;
        }

        var count:Int = implementCount;
        var related:Array<Int> = [superId];

        for (_ in 0...count)
        {
          var implementId:Null<Int> = reader.intOrNull();
          if (implementId == null)
          {
            result.suspect = true;
            return;
          }
          related.push(implementId);
        }

        result.ancestry.set(typeId, related);
        continue;
      }

      if (token == 'ENUM')
      {
        var typeId:Null<Int> = reader.intOrNull();

        if (typeId == null)
        {
          result.suspect = true;
          return;
        }

        result.ancestry.set(typeId, []);
        continue;
      }

      if (token == 'CALLGLOBAL')
      {
        var nameId:Null<Int> = reader.intOrNull();
        var argCount:Null<Int> = reader.intOrNull();

        if (nameId == null || argCount == null)
        {
          result.suspect = true;
          return;
        }

        if (wantGlobals)
        {
          result.globalCalls.push(nameId);
          result.globalCalls.push(argCount);
        }
        continue;
      }

      if (FIELD_OPS.exists(token))
      {
        var classId:Null<Int> = reader.intOrNull();
        var fieldId:Null<Int> = reader.intOrNull();

        if (classId == null || fieldId == null)
        {
          result.suspect = true;
          return;
        }

        if (wantedIds.exists(fieldId))
        {
          result.fieldRefs.push(classId);
          result.fieldRefs.push(fieldId);
          result.fieldSites.push(fileId);
          result.fieldSites.push(line);
        }
        continue;
      }

      if (!BODY_TOKENS.exists(token) && !result.unknownTokens.contains(token)) result.unknownTokens.push(token);
    }
  }

  /**
   * The value of a token written as a decimal integer, or null if it is not one.
   */
  static function numberOf(token:String):Null<Int>
  {
    if (token == null || token.length == 0) return null;

    var start:Int = token.charCodeAt(0) == '-'.code ? 1 : 0;
    if (start >= token.length) return null;

    var value:Int = 0;

    for (i in start...token.length)
    {
      var digit:Int = token.charCodeAt(i) - '0'.code;
      if (digit < 0 || digit > 9) return null;
      value = value * 10 + digit;
    }

    return start == 1 ? -value : value;
  }
}

/**
 * Walks a `CppiaStream` to read a compiled script.
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

  /**
   * Whether anything but whitespace is left.
   */
  public function hasMore():Bool
  {
    skipWhitespace();
    return pos < data.length;
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

  /**
   * The next token as an integer, or null if it is not one.
   */
  public function intOrNull():Null<Int>
  {
    skipWhitespace();

    var result:Int = 0;
    var sign:Int = 1;
    var digits:Int = 0;
    var bad:Bool = false;

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
        if (digit < 0 || digit > 9) bad = true;
        result = result * 10 + digit;
        digits++;
      }
      pos++;
    }

    if (bad || digits == 0) return null;

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
