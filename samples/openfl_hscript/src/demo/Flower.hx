package demo;

import openfl.display.Sprite;
import openfl.display.Bitmap;
import openfl.utils.Assets;

class Flower extends Sprite
{   
    public var pollen:Float = 0;
    public var maxPollen:Float = 0;

    public var cooldown:Float = 0;
    public var maxCooldown:Float = 30;

    public function new(i:Int=1)
    {
        super();
        pollen = maxPollen = i;
        var bmp = new Bitmap(Assets.getBitmapData("img/flower"+i+".png"));
        addChild(bmp);

        bmp.scaleX = 0.5;
        bmp.scaleY = 0.5;
        bmp.x -= bmp.width/2;
        bmp.y -= bmp.height/2;
        bmp.smoothing = true;
    }
}