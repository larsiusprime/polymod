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
 
package samples.heaps;

import hxd.Res;
import h2d.Sprite;
import h2d.Text;
import h2d.Scene;
import h2d.Bitmap;
import h2d.Tile;
import h2d.Interactive;

/**
 * ...
 * @author 
 */
class CheapButton extends Sprite
{
	private var callback:Void->Void = null;
	private var up:Sprite;
	private var down:Sprite;
	private var over:Sprite;
	private var upT:Text;
	private var overT:Text;
	private var downT:Text;
	
	private var isOver:Bool = false;
	private var isDown:Bool = false;

	public function new(spr:Sprite, str:String, callback:Void->Void=null)
	{
		super(spr);
		
		this.callback = callback;

		var img = Tile.fromColor(0xC0C0C0, 72, 32);
		var img2 = Tile.fromColor(0xD0D0D0, 72, 32);
		var img3 = Tile.fromColor(0x000000, 72, 32);

		up = new Sprite(this);
		over = new Sprite(this);
		down = new Sprite(this);

		var upB = new Bitmap(img, up);
		var overB = new Bitmap(img2, over);
		var downB = new Bitmap(img3, down);
		
		upT = getText(Center);
		overT = getText(Center);
		downT = getText(Center);
		
		upT.text = str;
		overT.text = str;
		downT.text = str;
		
		overT.textColor = 0xFFFFFF;
		downT.textColor = 0xFFFFFF;

		var interaction = new Interactive(72, 32, this);
		interaction.onOver = onOver;
		interaction.onClick = onClick;
		interaction.onPush = onDown;
		interaction.onRelease = onUp;
		interaction.onOut = onOut;
		
		onUp(null);
	}

	public function setText(str:String)
	{
		upT.text = overT.text = downT.text = str;
	}
	
	public function destroy()
	{
		removeChildren();
		callback = null;
	}
	
	private function onUp(event:hxd.Event)
	{
		isDown = false;
		updateButton();
	}
	
	private function onClick(event:hxd.Event)
	{
		if (callback != null) callback();
		updateButton();
	}
	
	private function onOver(event:hxd.Event)
	{
		isOver = true;
		updateButton();
	}
	
	private function onDown(event:hxd.Event)
	{
		isDown = true;
		updateButton();
	}
	
	private function onOut(event:hxd.Event)
	{
		isOver = false;
		updateButton();
	}

	private function updateButton()
	{
		if(isOver)
		{
			down.visible = up.visible = false;
			over.visible = true;
			if(isDown)
			{
				over.visible = false;
				down.visible = true;
			}
		}
		else
		{
			down.visible = over.visible = false;
			up.visible = true;
		}
	}

	private function getText(align:h2d.Text.Align):h2d.Text
	{
		var font = Res.customFont.toFont();
		var text = new Text(font, this);
		text.textColor = 0x000000;
		text.scale(1);
		text.textAlign = align;
		text.maxWidth = 72;
		text.y = 12;
		return text;
	}
}