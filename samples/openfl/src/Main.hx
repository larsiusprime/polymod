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
		var modRoot = "../../../mods/";
		Polymod.init({
			modRoot:modRoot,
			dirs:dirs,
			errorCallback:onError,
			ignoredFiles:Polymod.getDefaultIgnoreList()
		});
	}

	private function onError(error:PolymodError)
	{
		trace(error.severity + "(" + error.code.toUpperCase() + "):" + error.message);
	}

}
