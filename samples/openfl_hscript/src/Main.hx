package;

import openfl.Assets;
import openfl.display.Sprite;
import openfl.Lib;
import polymod.library.ModAssetLibrary;
import polymod.Polymod;
import openfl.events.KeyboardEvent;

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
		Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN,onKeyDown);
	}
	
	private function onKeyDown(e:KeyboardEvent)
	{
		if(String.fromCharCode(e.keyCode) == "R")
		{
			reset();
		}
	}

	private function reset()
	{
		demo.destroy();
		removeChild(demo);
		loadDemo();
	}

	private function loadDemo()
	{
		demo = new Demo();
		addChild(demo);
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
