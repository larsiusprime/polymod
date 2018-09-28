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

import h2d.Sprite;
import h2d.Text;
import h2d.Scene;

/**
 * ...
 * @author 
 */
class ModWidget extends Sprite
{
	public var active(default, null):Bool;
	public var mod(default, null):String;
	
	public var status:Text;
	public var callback:ModWidget->Int->Void;
	
	public var button:CheapButton;
	private var moveLeft:CheapButton;
	private var moveRight:CheapButton;

	public var locX:Int;
	public var locY:Int;
	
	public function new(spr:Sprite, x:Int, y:Int, str:String, callback:ModWidget->Int->Void=null)
	{
		super(spr);
		
		mod = str;
		
		this.callback = callback;
		
		status = text(this);
		status.text = "inactive";
		
		button = new CheapButton(this, str, onClick);
		moveLeft = new CheapButton(this, "<-", onMove.bind(-1));
		moveRight = new CheapButton(this, "->", onMove.bind(1));
		
		setLoc(x, y);
	}

	public function setLoc(x:Int, y:Int)
	{
		locX = x;
		locY = y;

		button.x = moveLeft.x = moveRight.x = x;
		button.y = moveLeft.y = moveRight.y = y;

		status.x = x;
		status.maxWidth = 72;
		status.y = button.y + 32 + 10;
		
		moveLeft.y = status.y + 32 + 10;
		moveRight.y = moveLeft.y + 32 + 4;
	}

	public function swap(other:ModWidget)
	{
		var otherMod = other.mod;
		var otherCallback = other.callback;
		var otherActive = other.active;

		other.mod = mod;
		other.active = active;
		other.button.setText(other.mod);
		other.status.text = other.active ? "active" : "inactive";

		mod = otherMod;
		active = otherActive;
		button.setText(mod);
		status.text = active ? "active" : "inactive";
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
		remove();
		removeChildren();
		button.destroy();
		moveLeft.destroy();
		moveRight.destroy();
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
	
	private function text(spr:Sprite):Text
	{
		var font = hxd.Res.customFont.toFont();
		var text = new h2d.Text(font, spr);
		text.textColor = 0x000000;
		text.scale(1);
		text.textAlign = Center;
		return text;
	}
	
}