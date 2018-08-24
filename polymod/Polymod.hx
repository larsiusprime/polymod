package polymod;
import lime.utils.AssetLibrary;
import polymod.library.ModAssetLibrary;

import lime.utils.Assets;

/**
 * ...
 * @author 
 */
class Polymod
{

	private static var defaultLibrary:AssetLibrary=null;
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
			throw "Polymod.init() ERROR: both dir and dirs are empty!";
		}
		if (defaultLibrary == null)
		{
			defaultLibrary = lime.utils.Assets.getLibrary("default");
		}
		
		var modLibrary = new ModAssetLibrary(dir, defaultLibrary, dirs);
		lime.utils.Assets.registerLibrary("default", modLibrary);
	}
	
}