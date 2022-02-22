package stage;

import openfl.display.Sprite;
import openfl.display.Bitmap;
import openfl.display.BitmapData;

class Stage extends Sprite
{
  var test:Stage;

	public var stageId:String = "UNKNOWN";
	public var stageName:String = "UNKNOWN";

	public function new(id:String)
	{
    super();
    trace('Initializing Stage: $id');
		// No-op constructor.
    this.stageId = id;
	}

  static final MAGENTA = 0xFFFF00FF;
  public function create() {
    // Clear all children so we don't add a sprite twice.
    removeChildren();

    var baseBg = new Bitmap(new BitmapData(480, 360, false, MAGENTA));
    addChild(baseBg);
  }
}
