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

package demo;

import openfl.display.Sprite;
import openfl.display.Bitmap;
import openfl.utils.Assets;

class Bee extends Mover
{   
    public var flower:Flower;
    public var pollen:Float;
    public var maxPollen:Float;
    public var turnsSearching:Int = 0;

    public function new()
    {
        super();

        speed = 100;

        var bmp = new Bitmap(Assets.getBitmapData("img/bee.png"));
        addChild(bmp);
        
        bmp.scaleX = 0.5;
        bmp.scaleY = 0.5;
        bmp.x -= bmp.width/2;
        bmp.y -= bmp.height/2;
        bmp.smoothing = true;
    }
}