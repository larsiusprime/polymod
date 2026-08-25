package polymod.hscript._internal;

import polymod.hscript._internal.Expr;

@:allow(polymod.Polymod)
class PolymodEnum
{
  private static final scriptInterp = new Interp(null, null);

  private var _e:EnumDecl;

  private var _value:String;

  private var _args:Array<Dynamic>;

  public function new(e:EnumDecl, value:String, args:Array<Dynamic>)
  {
    this._e = e;

    var field = getField(value);

    if (field == null)
    {
      Polymod.error(SCRIPT_PARSE_FAILED, '${e.name}.${value} does not exist.', SCRIPT_RUNTIME);
      return;
    }

    this._value = value;

    if (args.length != field.args.length)
    {
      Polymod.error(SCRIPT_PARSE_FAILED, '${e.name}.${value} got the wrong number of arguments.', SCRIPT_RUNTIME);
      return;
    }

    this._args = args;
  }

  /**
   * Attempts to retrieve the full package of a scripted enum.
   * @param id
   */
  public static function tryResolve(id:String):Null<String>
  {
    // `id` is a package.
    if (id.indexOf('.') != -1)
    {
      // Enum exists so we can safely return the full package.
      @:privateAccess
      if (Interp._scriptEnumDescriptors.exists(id)) return id;
    }

    @:privateAccess
    for (fullEnumName => val in Interp._scriptEnumDescriptors)
    {
      var splitPkg:Array<String> = fullEnumName.split('.');
      var name:String = splitPkg[splitPkg.length - 1];

      if (name == id) return fullEnumName;
    }
    return null;
  }

  public static function clearScriptedEnums():Void
  {
    scriptInterp.clearScriptEnumDescriptors();
  }

  private function getField(name:String):Null<EnumFieldDecl>
  {
    for (field in _e.fields)
    {
      if (field.name == name)
      {
        return field;
      }
    }
    return null;
  }

  public function toString():String
  {
    var result:String = '${_e.name}.${_value}';
    if (_args.length > 0) result += '(${_args.join(',')})';
    return result;
  }
}
