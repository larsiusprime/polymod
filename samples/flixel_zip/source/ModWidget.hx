import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.text.FlxText;

class ModWidget extends FlxTypedSpriteGroup<FlxSprite>
{
	public var isModActive(default, null):Bool;
	public var modId(default, null):String;

	public var status:FlxText;

	private var callback:ModWidget->Int->Void;

	public var button:CheapButton;
	public var moveLeft:CheapButton;
	public var moveRight:CheapButton;

	public function new(modId:String, callback:ModWidget->Int->Void = null)
	{
		super();

		this.modId = modId;

		this.callback = callback;

		status = new FlxText(0, 0, 80, 'inactive');
		status.setFormat("Arial", 12, 0xFF000000, FlxTextAlign.CENTER);

		button = new CheapButton(this.modId, onClick);
		var left = '←';
		var right = '→';
		#if mac
		left = "<--";
		right = "-->";
		#end
		moveLeft = new CheapButton(left, onMove.bind(-1));
		moveRight = new CheapButton(right, onMove.bind(1));

		add(status);
		add(button);
		add(moveLeft);
		add(moveRight);
	}

	public function fixButtons()
	{
		button.x = x;
		button.y = y;

		status.x = x;
		status.y = button.y + button.height + 10;

		moveLeft.x = x;
		moveRight.x = x;
		moveLeft.y = status.y + status.height + 10;
		moveRight.y = moveLeft.y + moveLeft.height + 4;
	}

	public function showButtons(left:Bool, right:Bool)
	{
		if (moveLeft == null)
			return;
		moveLeft.visible = left;
		moveRight.visible = right;
	}

	public override function destroy()
	{
		callback = null;

		status.destroy();
		status = null;
		button.destroy();
		button = null;
		moveLeft.destroy();
		moveLeft = null;
		moveRight.destroy();
		moveRight = null;
	}

	private function onClick()
	{
		isModActive = !isModActive;
		status.text = isModActive ? 'active' : 'inactive';
		if (callback != null)
		{
			callback(this, 0);
		}
	}

	private function onMove(i:Int)
	{
		if (callback != null)
		{
			callback(this, i);
		}
	}
}
