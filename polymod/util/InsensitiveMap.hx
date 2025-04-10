package polymod.util;

import haxe.ds.StringMap;
import haxe.Constraints.IMap;

/**
 * A string map which treats any letter cases the same (case insensitive).
 * Unlike other maps, if a value already exists it won't be overwritten.
 */
class InsensitiveMap<T> implements IMap<String, T> {
    var data:StringMap<T> = new StringMap();
    var originalKeys:Map<String, String> = new Map();

    public function new() {}

    public function set(key:String, value:T):Void {
      var lowerKey = key.toLowerCase();
      if (data.exists(lowerKey)) return;

      data.set(lowerKey, value);
      originalKeys.set(lowerKey, key);
    }

    public inline function get(key:String):Null<T> {
      return data.get(key.toLowerCase());
    }

    public inline function exists(key:String):Bool {
      return data.exists(key.toLowerCase());
    }

    public function remove(key:String):Bool {
      var lowerKey = key.toLowerCase();
      originalKeys.remove(lowerKey);
      return data.remove(lowerKey);
    }

    public function clear():Void {
      data.clear();
      originalKeys.clear();
    }

    public function copy():InsensitiveMap<T> {
      var res = new InsensitiveMap();
      res.data = data.copy();
      res.originalKeys = originalKeys.copy();
      return res;
    }

    public inline function keys():Iterator<String> {
      return originalKeys.iterator();
    }

    public function keyValueIterator() {
      return {
        var it = originalKeys.keys();
        return {
            hasNext: function() return it.hasNext(),
                next: function() {
                var lowerKey = it.next();
                var originalKey = originalKeys.get(lowerKey);
                return { key: originalKey, value: data.get(lowerKey) };
            }
        };
      };
  }

    public inline function iterator() {
        return data.iterator();
    }

    public function toString():String {
        var parts = [];
        for (key in keys()) {
            parts.push('$key => ${get(key)}');
        }
        return '{' + parts.join(', ') + '}';
    }
}
