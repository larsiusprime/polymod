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
	private var demo:Demo=null;
	
	public function new() 
	{
		super();
		
		loadDemo();
	}
	
	private function loadDemo()
	{
		demo = new Demo(onModChange);
		addChild(demo);
	}
	
	private function onModChange(arr:Array<String>)
	{
		loadMods(arr);
		demo.refresh();
	}
	
	private function loadMods(dirs:Array<String>)
	{
		var modPath = "../../../mods/";
		var mods = [];
		for (dir in dirs)
		{
			mods.push(modPath + dir);
		}
		Polymod.init(mods);
	}

}
