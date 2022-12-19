import flixel.FlxBasic;
import flixel.FlxGame;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import openfl.display.Sprite;
import polymod.hscript.HScriptable;

class Main extends Sprite
{
	public function new()
	{
		super();
		var test = "Ω";
		addChild(new FlxGame(0, 0, PlayState));
	}
}
