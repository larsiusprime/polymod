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

import nme.text.TextField;
import nme.display.Sprite;
import nme.display.Bitmap;
import nme.display.BitmapData;
import nme.display.DisplayObject;
import nme.display.DisplayObjectContainer;
import nme.events.MouseEvent;
import nme.text.TextFormatAlign;

/**
 * ...
 * @author 
 */
class CheapButton extends Sprite
{
	public function new(str:String, callback:Void->Void=null)
	{
		super();
		
		this.callback = callback;
		
		var img = new BitmapData(72, 32, false, 0xC0C0C0);
		var img2 = new BitmapData(72, 32, false, 0xD0D0F0);
		var img3 = new BitmapData(72, 32, false, 0x000000);
		
		up = new Sprite();
		over = new Sprite();
		down = new Sprite();
		
		var upB = new Bitmap(img);
		var overB = new Bitmap(img2);
		var downB = new Bitmap(img3);
		
		up.addChild(upB);
		over.addChild(overB);
		down.addChild(downB);
		
		var upT = text();
		var overT = text();
		var downT = text();
		
		upT.text = str;
		overT.text = str;
		downT.text = str;
		
		overT.textColor = 0xFFFFFF;
		downT.textColor = 0xFFFFFF;
		
		up.addChild(upT);
		over.addChild(overT);
		down.addChild(downT);
		
		addChild(up);
		addChild(down);
		addChild(over);
		
		mouseEnabled = true;
		buttonMode = true;
		
		if (this.down == null)
		{
			this.down = this.up;
		}
		
		addEventListener(MouseEvent.MOUSE_OVER, onOver);
		addEventListener(MouseEvent.MOUSE_OUT, onUp);
		addEventListener(MouseEvent.MOUSE_DOWN, onDown);
		addEventListener(MouseEvent.MOUSE_UP, onUp);
		addEventListener(MouseEvent.CLICK, onClick);
		
		onUp(null);
	}
	
	public function destroy()
	{
		removeEventListener(MouseEvent.MOUSE_OVER, onOver);
		removeEventListener(MouseEvent.MOUSE_OUT, onUp);
		removeEventListener(MouseEvent.MOUSE_DOWN, onDown);
		removeEventListener(MouseEvent.MOUSE_UP, onUp);
		removeEventListener(MouseEvent.CLICK, onClick);
		removeChildren();
		callback = null;
	}
	
	private function onUp(m:MouseEvent)
	{
		down.visible = over.visible = false;
		up.visible = true;
	}
	
	private function onClick(m:MouseEvent)
	{
		onOver(m);
	}
	
	private function onOver(m:MouseEvent)
	{
		down.visible = up.visible = false;
		over.visible = true;
	}
	
	private function onDown(m:MouseEvent)
	{
		over.visible = up.visible = false;
		down.visible = true;
		if (callback != null) callback();
	}
	
	private function text():TextField
	{
		var t:TextField = new TextField();
		t.width = 72;
		t.height = 32;
		var dtf = t.defaultTextFormat;
		dtf.size = 18;
		dtf.align = TextFormatAlign.CENTER;
		t.setTextFormat(dtf);
		t.selectable = false;
		return t;
	}
	
	private var callback:Void->Void = null;
	private var up:DisplayObjectContainer;
	private var down:DisplayObjectContainer;
	private var over:DisplayObjectContainer;
	
}