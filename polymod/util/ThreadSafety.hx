package polymod.util;

#if haxe_concurrent
import hx.concurrent.collection.SynchronizedMap;

// If available, make Polymod thread-safe.
// Assumes String keys.
@:forward
abstract SafeMap<V>(SynchronizedMap<String, V>) to SynchronizedMap<String, V>
{
  // Add a no-arg constructor that builds a map with the appropriate type.
  public function new() {
    @:privateAccess
    this = SynchronizedMap.newStringMap();
  }
}
#else
// If not available, use a standard Map.
typedef SafeMap<V> = Map<String, V>;
#end
