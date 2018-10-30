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

import openfl.display.Sprite;
import openfl.Lib;
import polymod.Polymod;
import polymod.Polymod.Framework;

/**
 * ...
 * @author 
 */
class Main extends Sprite 
{
	private var demo:Demo=null;
	
	public function new() 
	{
		super();
		loadDemo();
	}
	
	private function loadDemo()
	{
		demo = new Demo(onModChange);
		addChild(demo);
	}
	
	private function onModChange(arr:Array<String>)
	{
		loadMods(arr);
		demo.refresh();
	}
	
	private function loadMods(dirs:Array<String>)
	{
		var framework = Demo.usingOpenFL ? Framework.OPENFL : Framework.LIME;
		var modRoot = "../../../mods/";
		#if mac
		//account for <APPLICATION>.app/Contents/Resources
		var modRoot = "../../../../../../mods";
		#end
		var results = Polymod.init({
			modRoot:modRoot,
			dirs:dirs,
			errorCallback:onError,
			ignoredFiles:Polymod.getDefaultIgnoreList(),
			framework:framework
		});
	}

	private function onError(error:PolymodError)
	{
		trace(error.severity + "(" + error.code.toUpperCase() + "):" + error.message);
	}

}
