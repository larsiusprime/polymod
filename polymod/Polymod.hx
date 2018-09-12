package polymod;
import lime.utils.AssetLibrary;
import lime.utils.AssetType;
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
	 * @param	modRoot	root directory of all mods
	 * @param	dirs	directory names of one or more mods, relative to modRoot
	 */
	public static function init(modRoot:String, dirs:Array<String>)
	{
		trace("Polymod.init("+modRoot+","+dirs+")");
		if (modRoot == null || dirs == null || dirs.length == 0)
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
		
		for(i in 0...dirs.length) {
			if(dirs[i] != null){
				dirs[i] = modRoot + "/" + dirs[i];
			}
		}
		modLibrary = new ModAssetLibrary(null, defaultLibrary, dirs);
		LimeAssets.registerLibrary("default", modLibrary);

		if(Assets.exists("_polymodpack.txt"))
		{
			initModPack(modRoot);
		}
	}

	/**
	 * Get the asset library that Polymod uses as a fallback for assets your
	 * mod doesn't provide
	 * @return AssetLibrary
	 */
	public static function getDefaultLibrary():AssetLibrary
	{
		return defaultLibrary;
	}

	/**
	 * Get the mod asset library that Polymod sets as your default asset library
	 * @return ModAssetLibrary
	 */
	public static function getModLibrary():ModAssetLibrary
	{
		return modLibrary;
	}

	/**
	 * Provide a list of assets included in or modified by the mod(s)
	 * @param type the type of asset you want (lime.utils.AssetType)
	 * @return Array<String> a list of assets of the matching type
	 */
	public static function listModFiles(type:AssetType=null):Array<String>
	{
		if(modLibrary != null)
		{
			return modLibrary.listModFiles(type);
		}
		return [];
	}

	/***PRIVATE***/

	private static function initModPack(modRoot:String)
	{
		var polymodpack:String = Assets.getText("_polymodpack.txt");
		if(polymodpack != null)
		{
			var mods = polymodpack.split(",");
			if(mods == null || mods.length == 0)
			{
				return;
			}
			init(modRoot, mods);
		}
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