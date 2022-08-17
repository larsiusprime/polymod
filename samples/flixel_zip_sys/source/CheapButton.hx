import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.input.mouse.FlxMouseEventManager;
import flixel.text.FlxText;

class CheapButton extends FlxTypedSpriteGroup<FlxSprite>
{
	var bg:FlxSprite;
	var text:FlxText;

	private var callback:Void->Void = null;

	static final UP_COLOR = 0xFFC0C0C0;
	static final OVER_COLOR = 0xFFD0D0F0;
	static final DOWN_COLOR = 0xFF000000;

	public function new(str:String, callback:Void->Void = null)
	{
		super();

		this.callback = callback;

		bg = new FlxSprite(0, 0);
		bg.makeGraphic(72, 32, UP_COLOR);
		text = new FlxText(0, 0);
		setText(str);
		text.setFormat("Arial", 12, 0xFF000000, FlxTextAlign.CENTER);

		add(bg);
		add(text);

		addEvents();
	}

	function addEvents()
	{
		FlxMouseEventManager.add(this, onDown, onUp, onOver, onOff);
	}

	public function setText(str:String)
	{
		text.text = str;
	}

	public override function destroy()
	{
		FlxMouseEventManager.remove(this);
		callback = null;
		bg.destroy();
		bg = null;
		text.destroy();
		text = null;
	}

	private function onClick()
	{
		if (callback != null)
		{
			callback();
		}
	}

	private function onUp(sprite:CheapButton)
	{
		bg.makeGraphic(72, 32, UP_COLOR);
		onClick();
	}

	private function onOff(sprite:CheapButton)
	{
		bg.makeGraphic(72, 32, UP_COLOR);
	}

	private function onOver(sprite:CheapButton)
	{
		bg.makeGraphic(72, 32, OVER_COLOR);
	}

	private function onDown(sprite:CheapButton)
	{
		bg.makeGraphic(72, 32, DOWN_COLOR);
	}
}
