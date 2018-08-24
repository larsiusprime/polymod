package;

import openfl.Assets;
import openfl.display.Sprite;
import openfl.Lib;
import polymod.library.ModAssetLibrary;
import polymod.Polymod;

/**
 * ...
 * @author 
 */
class Main extends Sprite 
{

	public function new() 
	{
		super();
		
		var modPath = "..\\..\\..\\mods\\";
		Polymod.init([modPath + "mod1", modPath + "mod3"]);
		
		var demo = new Demo();
		addChild(demo);
	}
	
	private function loadMods(dirs:Array<String>)
	{
		Polymod.init(dirs);
	}

}
