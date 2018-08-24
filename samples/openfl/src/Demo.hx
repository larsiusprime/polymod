package;
import flash.text.TextFieldType;
import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormatAlign;
import openfl.utils.AssetType;
import polymod.library.ModAssetLibrary;

/**
 * ...
 * @author 
 */
class Demo extends Sprite
{

	public function new() 
	{
		super();
		
		var xx = 10;
		var yy = 10;
		
		var library = lime.Assets.getLibrary("default");
		
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
			addChild(bmp);
			
			var text = new TextField();
			text.width = bmp.width;
			var dtf = text.defaultTextFormat;
			dtf.align = TextFormatAlign.CENTER;
			text.setTextFormat(dtf);
			text.text = image;
			text.x = xx;
			text.y = bmp.y + bmp.height;
			addChild(text);
			
			xx += Std.int(bmp.width + 10);
		}
	}
	
}