package polymod.hscript._internal;

/**
 * Picks which compiled scripts belong to the platform the game is running on.
 * Supports desktop platforms (windows, macos, linux), mobile platforms (android, ios).
 * Also two generic tags, 'desktop' and 'mobile', which cover all desktop and mobile platforms respectively.
 *
 * Also falls back to regular .cppia files when no platform-specific one is available.
 */
class PolymodCppiaTarget
{
  /**
   * Every tag that names a platform rather than being part of a file name.
   */
  public static final KNOWN_TAGS:Array<String> = [
    'windows', 'macos', 'mac', 'linux', 'android', 'ios', 'switch', 'desktop', 'mobile'
  ];

  /**
   * The tags that fit the current platform, closest first.
   */
  public static var tags(get, default):Array<String>;

  static function get_tags():Array<String>
  {
    if (tags == null) tags = detect();
    return tags;
  }

  static function detect():Array<String>
  {
    #if android
    return ['android', 'mobile'];
    #elseif ios
    return ['ios', 'mobile'];
    #elseif windows
    return ['windows', 'desktop'];
    #elseif mac
    return ['macos', 'mac', 'desktop'];
    #elseif linux
    return ['linux', 'desktop'];
    #else
    return [];
    #end
  }

  /**
   * Keeps one compiled script per name, the one that fits this platform best.
   */
  public static function select(paths:Array<String>):Array<String>
  {
    var best:Map<String, String> = new Map<String, String>();
    var scores:Map<String, Int> = new Map<String, Int>();
    var order:Array<String> = [];

    for (path in paths)
    {
      var parts = split(path);
      var score:Int = rank(parts.tag);
      if (score < 0) continue;

      if (!best.exists(parts.base))
      {
        order.push(parts.base);
      }
      else if (score >= scores.get(parts.base))
      {
        continue;
      }

      best.set(parts.base, path);
      scores.set(parts.base, score);
    }

    return [for (base in order) best.get(base)];
  }

  /**
   * How closely a tag fits this platform. Lower is closer, -1 means it does not fit at all.
   */
  public static function rank(tag:Null<String>):Int
  {
    if (tag == null) return tags.length;
    return tags.indexOf(tag);
  }

  /**
   * Splits a path into the name it shares with its other platforms, and the tag it carried.
   */
  public static function split(path:String):{base:String, tag:Null<String>}
  {
    var ext:String = '';
    for (candidate in PolymodConfig.cppiaClassExt)
    {
      if (path.length > candidate.length && StringTools.endsWith(path, candidate) && candidate.length > ext.length) ext = candidate;
    }

    var stem:String = path.substr(0, path.length - ext.length);
    var dot:Int = stem.lastIndexOf('.');
    if (dot <= 0 || dot < stem.lastIndexOf('/') || dot < stem.lastIndexOf('\\')) return {base: path, tag: null};

    var tag:String = stem.substr(dot + 1).toLowerCase();
    if (KNOWN_TAGS.indexOf(tag) == -1) return {base: path, tag: null};

    return {base: stem.substr(0, dot) + ext, tag: tag};
  }
}
