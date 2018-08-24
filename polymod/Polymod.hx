package polymod;
import lime.utils.AssetLibrary;
import polymod.library.ModAssetLibrary;

import lime.utils.Assets in LimeAssets;
import openfl.utils.Assets;

/**
 * ...
 * @author 
 */
class Polymod
{

	private static var defaultLibrary:AssetLibrary = null;
	private static var modLibrary:ModAssetLibrary = null;
	/**
	 * Initializes the chosen mod or mods.
	 * @param	dir	root directory of a single mod
	 * @param	dirs	root directories of several mods, in the intended loading order. <code>dir</code> is ignored if this is defined as well.
	 */
	public static function init(?dir:String, ?dirs:Array<String>)
	{
		var dirNull = dir == null || dir == "";
		var dirsNull = dirs == null || dirs.length == 0;
		if (dirNull && dirsNull)
		{
			if (defaultLibrary != null)
			{
				LimeAssets.registerLibrary("default", defaultLibrary);
			}
			else
			{
				return;
			}
		}
		
		if (defaultLibrary == null)
		{
			defaultLibrary = LimeAssets.getLibrary("default");
		}
		
		clearCache();
		
		modLibrary = new ModAssetLibrary(dir, defaultLibrary, dirs);
		LimeAssets.registerLibrary("default", modLibrary);
	}
	
	private static function clearCache()
	{
		if (defaultLibrary != null)
		{
			for (key in LimeAssets.cache.audio.keys())
			{
				LimeAssets.cache.audio.remove(key);
			}
			for (key in LimeAssets.cache.font.keys())
			{
				LimeAssets.cache.font.remove(key);
			}
			for (key in LimeAssets.cache.image.keys())
			{
				LimeAssets.cache.image.remove(key);
			}
		}
	}
}