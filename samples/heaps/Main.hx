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

import hxd.App;
import polymod.Polymod;
import polymod.Polymod.PolymodError;

class Main extends hxd.App
{
    static function main()
    {
        hxd.Res.initLocal();
        new Main();
    }

    function bkg()
    {
        var spr = new h2d.Sprite(s2d);
        spr.x = 0;
        spr.y = 0;
        var tile = h2d.Tile.fromColor(0xFFFFFF,1,1);
        tile.scaleToSize(s2d.width, s2d.height);
        var bmp = new h2d.Bitmap(tile,spr);
        bmp.x = 0;
        bmp.y = 0;
    }

    private var demo:Demo = null;

    override function init()
    {
        bkg();
        loadDemo();
    }

    private function loadDemo()
    {
        demo = new Demo(s2d, onModChange);
    }
    
    private function onModChange(arr:Array<String>)
    {
        loadMods(arr);
        demo.refresh();
    }
    
    private function loadMods(dirs:Array<String>)
    {
        var modRoot = "mods";
        Polymod.init({
            modRoot:modRoot,
            dirs:dirs,
            errorCallback:onError,
            ignoredFiles:Polymod.getDefaultIgnoreList()
        });
    }

    private function onError(error:PolymodError)
    {
        trace(error.severity + "(" + error.code.toUpperCase() + "):" + error.message);
    }
}