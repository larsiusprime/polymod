/**
 * Copyright (c) 2018 Level Up Labs, LLC
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 * 
 */

package;

import h2d.Sprite;
import h2d.Scene;

class Demo extends Sprite
{
	private var widgets:Array<ModWidget>=[];
	private var callback:Array<String>->Void;

	public function new(scene:Scene, callback:Array<String>->Void) 
	{
		super(scene);
		this.callback = callback;
		
		makeButtons();
		drawImages();
		drawText();
	}

	public function destroy()
	{
		removeChildren();
		for (w in widgets)
		{
			w.destroy();
		}
		callback = null;
	}
	
	public function refresh()
	{
		drawImages();
		drawText();
	}
	
	private function makeButtons()
	{
		var modDir:String = "mods";
		var mods = sys.FileSystem.readDirectory(modDir);
		var xx = 10;
		var yy = 200;
		for (mod in mods)
		{
			var w = new ModWidget(this, xx, yy, mod, onWidgetMove);
			widgets.push(w);
			xx += (72 + 10);
		}
		
		updateWidgets();
	}
	
	private function updateWidgets()
	{
		if (widgets == null) return;
		for (i in 0...widgets.length)
		{
			var showLeft = i != 0;
			var showRight = i != widgets.length - 1;
			widgets[i].showButtons(showLeft, showRight);
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
			other.swap(w);
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
		
		updateWidgets();
	}

	private function list(str:String):Array<String>
	{
		var loader = hxd.Res.loader;
		var root = loader.fs.getRoot();
		var path = root.get(str);
		var files = [];
		for(asset in path)
		{
			files.push(asset.path);		
		};
		return files;
	}

	private function drawImages()
	{
		var xx = 10;
		var yy = 10;
		
		var images = list("img");	
		images.sort(function(a:String, b:String):Int{
			if (a < b) return -1;
			if (a > b) return  1;
			return 0;
		});
		for (image in images)
		{
			var spr = new h2d.Sprite(this);
			var tile = hxd.Res.loader.load(image).toTile();
			var bmp = new h2d.Bitmap(tile, spr);
			bmp.x = 0;
			bmp.y = 0;
			spr.x = xx;
			spr.y = yy;
			
			var text = getText(Center);
			
			text.maxWidth = tile.width;
			text.text = image;
			text.x = xx;
			text.y = spr.y + tile.height;
			
			xx += Std.int(tile.width + 10);
		}
	}

	private function drawText()
	{
		var xx = 350;
		var yy = 10;
		
		var texts = list("data");
		
		for (t in texts)
		{
			var isXML:Bool = false;
			var align:h2d.Text.Align = Center;
			var theWidth = 150;
			if (t.indexOf("xml") != -1)
			{
				isXML = true;
				align = Left;
				theWidth = 250;
			}
			
			var textBox = getBox(theWidth, 152, 1);
			textBox.x = xx-1;
			textBox.y = yy-1;
			
			var text = getText(align);
			text.x = xx;
			text.y = yy;
			text.maxWidth = theWidth;
			
			var str = hxd.Res.loader.load(t).toText();
			
			text.text = (str != null ? str : "null");
			
			var caption = getText(Center);
			caption.x = xx;
			caption.y = 150 + caption.textHeight;
			caption.text = t;
			caption.maxWidth = text.maxWidth;
			
			xx += Std.int(text.maxWidth + 10);
		}
	}

	private function getBox(width:Int,height:Int,border:Int,color1:Int=0x000000,color2:Int=0xFFFFFF):h2d.Sprite
	{
		var spr = new h2d.Sprite(this);
		spr.x = 0;
		spr.y = 0;
		var col1 = h2d.Tile.fromColor(color1,width,height);
		var bmp = new h2d.Bitmap(col1,spr);
		bmp.x = 0;
		bmp.y = 0;
		var col2 = h2d.Tile.fromColor(color2,width-2,height-2);
		var bmp2 = new h2d.Bitmap(col2,spr);
		bmp2.x = border;
		bmp2.y = border;
		return spr;
	}

	private function getText(align:h2d.Text.Align):h2d.Text
	{
		var font = hxd.Res.customFont.toFont();
		var text = new h2d.Text(font, this);
		text.textColor = 0x000000;
		text.scale(1);
		text.textAlign = align;
		return text;
	}
}