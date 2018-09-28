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

import nme.display.Sprite;
import nme.text.TextField;
import nme.display.DisplayObjectContainer;
import nme.events.MouseEvent;
import nme.text.TextFormatAlign;

/**
 * ...
 * @author 
 */
class ModWidget extends Sprite
{
	public var active(default, null):Bool;
	public var mod(default, null):String;
	
	private var status:TextField;
	private var callback:ModWidget->Int->Void;
	
	private var button:CheapButton;
	private var moveLeft:CheapButton;
	private var moveRight:CheapButton;
	
	public function new(str:String, callback:ModWidget->Int->Void=null)
	{
		super();
		
		mod = str;
		
		this.callback = callback;
		
		status = text();
		status.text = "inactive";
		
		var button = new CheapButton(str, onClick);
		moveLeft = new CheapButton("←", onMove.bind(-1));
		moveRight = new CheapButton("→", onMove.bind(1));
		
		addChild(status);
		addChild(button);
		addChild(moveLeft);
		addChild(moveRight);
		
		status.y = button.y + button.height + 10;
		
		moveLeft.y = status.y + status.height + 10;
		moveRight.y = moveLeft.y + moveLeft.height + 4;
	}
	
	public function showButtons(left:Bool, right:Bool)
	{
		if (moveLeft == null) return;
		moveLeft.visible = left;
		moveRight.visible = right;
	}
	
	public function destroy()
	{
		callback = null;
		
		button.destroy();
		moveLeft.destroy();
		moveRight.destroy();
		
		removeChildren();
	}
	
	private function onClick()
	{
		active = !active;
		status.text = active ? "active" : "inactive";
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
	
}