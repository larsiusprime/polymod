package;
import flash.display.DisplayObject;
import flash.text.TextFieldType;
import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormatAlign;
import openfl.utils.AssetType;
import polymod.library.ModAssetLibrary;
import sys.FileSystem;

/**
 * ...
 * @author 
 */
class Demo extends Sprite
{
	private var widgets:Array<ModWidget>=[];
	private var callback:Array<String>->Void;
	private var stuff:Array<Dynamic> = [];
	
	public function new(callback:Array<String>->Void) 
	{
		super();
		
		this.callback = callback;
		
		makeButtons();
		drawImages();
	}
	
	public function destroy()
	{
		for (w in widgets)
		{
			w.destroy();
		}
		callback = null;
		removeChildren();
	}
	
	public function refresh()
	{
		for (thing in stuff)
		{
			removeChild(cast thing);
		}
		stuff.splice(0, stuff.length);
		drawImages();
	}
	
	private function makeButtons()
	{
		var modDir:String = "../../../mods";
		var mods = FileSystem.readDirectory(modDir);
		var xx = 10;
		var yy = 200;
		for (mod in mods)
		{
			var w = new ModWidget(mod, onWidgetMove);
			w.x = xx;
			w.y = yy;
			
			widgets.push(w);
			
			xx += Std.int(w.width) + 10;
			addChild(w);
		}
	}
	
	private function onWidgetMove(w:ModWidget, i:Int)
	{
		if (i != 0)
		{
			var temp = widgets.indexOf(w);
			var newI = temp + i;
			if (newI < 0 || newI >= widgets.length)
			{
				return;
			}
			var other = widgets[newI];
			
			var oldX = w.x;
			var oldY = w.y;
			
			widgets[newI] = w;
			widgets[temp] = other;
			
			w.x = other.x;
			w.y = other.y;
			
			other.x = oldX;
			other.y = oldY;
		}
		
		if (callback != null)
		{
			var theMods = [];
			for (w in widgets)
			{
				if (w.active)
				{
					theMods.push(w.mod);
				}
			}
			callback(theMods);
		}
	}
	
	private function drawImages()
	{
		var xx = 10;
		var yy = 10;
		
		var images = Assets.list(AssetType.IMAGE);
		images.sort(function(a:String, b:String):Int{
			if (a < b) return -1;
			if (a > b) return  1;
			return 0;
		});
		
		for (image in images)
		{
			var bData = Assets.getBitmapData(image);
			var bmp = new Bitmap(bData);
			bmp.x = xx;
			bmp.y = yy;
			
			var text = new TextField();
			text.width = bmp.width;
			var dtf = text.defaultTextFormat;
			dtf.align = TextFormatAlign.CENTER;
			text.setTextFormat(dtf);
			text.text = image;
			text.x = xx;
			text.y = bmp.y + bmp.height;
			
			addChild(bmp);
			addChild(text);
			stuff.push(bmp);
			stuff.push(text);
			
			xx += Std.int(bmp.width + 10);
		}
	}
	
}