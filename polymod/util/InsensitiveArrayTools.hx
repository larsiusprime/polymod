package polymod.util;

/**
 * Utility class for working with string arrays in a case-insensitive manner
 */
class InsensitiveArrayTools
{
    public static function indexOfInsensitive(arr:Array<String>, value:String):Int
    {
        value = value.toLowerCase();
        for (i => s in arr)
        {
            if (s.toLowerCase() == value) return i;
        }
        return -1;
    }

    public inline static function containsInsensitive(arr:Array<String>, value:String):Bool
    {
        return indexOfInsensitive(arr, value) != -1;
    }
}
