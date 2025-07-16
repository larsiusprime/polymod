package polymod.util;

/**
 * Utility class for working with string arrays in a case-insensitive manner
 */
class InsensitiveArrayTools
{
    public static function indexOfInsens(arr:Array<String>, x:String, ?fromIndex:Int, ignoreConfig:Bool = false):Int
    {
        if (!PolymodConfig.caseInsensitiveZipLoading && !ignoreConfig) return arr.indexOf(x, fromIndex);
        x = x.toLowerCase();
        for (i => s in arr)
        {
            if (s.toLowerCase() == x) return i;
        }
        return -1;
    }

    public inline static function containsInsens(arr:Array<String>, x:String, ignoreConfig:Bool = false):Bool
    {
        return indexOfInsens(arr, x, ignoreConfig) != -1;
    }
}
