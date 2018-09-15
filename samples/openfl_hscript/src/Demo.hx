package;
import flash.display.DisplayObject;
import flash.text.TextFieldType;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.Sprite;
import openfl.display.Stage;
import openfl.text.TextField;
import openfl.text.TextFormatAlign;
import openfl.utils.AssetType;
import openfl.events.Event;
import polymod.library.ModAssetLibrary;
import sys.FileSystem;

/**
 * ...
 * @author 
 */
class Demo extends Sprite
{
	private var bees:Array<Bee>;
	private var flowers:Array<Flower>;
	private var home:Home;
	private var time:Float=0;
	private var score:TextField;
	
	public var numBees:Int = 10;
	public var numFlowers:Int = 10;

	public function new() 
	{
		super();
		bees = [];
		flowers = [];

		var minX:Float = 40;
		var maxX:Float = 800-40;

		var minY:Float = 40;
		var maxY:Float = 480-40;

		var cX:Float = 800/2;
		var cY:Float = 480/2;

		for(i in 0...numFlowers)
		{
			for(j in 0...3)
			{
				var x = cX;
				var y = cY;
				while(distTest(x,y,cX,cY,100))
				{
					x = minX + (Math.random() * (maxX-minX));
					y = minY + (Math.random() * (maxY-minY));
				}
				makeFlower(j+1, x, y);
			}
		}

		home = makeHome(cX,cY);

		for(i in 0...numBees)
		{
			var x = minX + (Math.random() * (maxX-minX));
			var y = minY + (Math.random() * (maxY-minY));
			makeBee(x, y);
		}

		score = new TextField();
		addChild(score);
		score.text = "Honey collected: 0";

		Lib.current.stage.addEventListener(Event.ENTER_FRAME, onEnterFrame, false, 0, true);
	}

	private function updateScore(f:Float)
	{
		score.text = "Honey collected: " + Std.string(Std.int(f*100)/100);
	}

	public function destroy()
	{
		Lib.current.stage.removeEventListener(Event.ENTER_FRAME, onEnterFrame);
		for(i in 0...numChildren)
		{
			removeChildAt(0);
		}
		bees = null;
		flowers = null;
	}

	private function onEnterFrame(e:Event)
	{
		var now = Lib.getTimer();
		var elapsed:Float = (now-time)/1000;
		time = now;
		
		for(bee in bees)
		{
			updateBee(bee, elapsed);
		}

		for(flower in flowers)
		{
			updateFlower(flower, elapsed);
		}
	}

	private function updateFlower(flower:Flower, elapsed:Float)
	{
		if(flower.cooldown > 0)
		{
			flower.cooldown -= elapsed;

			var p = (flower.maxCooldown-flower.cooldown)/flower.maxCooldown;
			
			flower.alpha = 0.33 + (0.5 * p);
			
			if(flower.cooldown <= 0)
			{
				flower.cooldown = 0;
				flower.pollen = flower.maxPollen;
				flower.alpha = 1.0;
			}
		}
	}

	private function updateBee(bee:Bee, elapsed:Float)
	{
		if(bee.x < 0 || bee.x > 800 || bee.y < 0 || bee.y > 480)
		{
			bee.x = 100 + Math.random() * 700;
			bee.y = 50 + Math.random() * 380;
		}
		if(bee.pollen > 0)
		{
			if(!isTouching(bee, home))
			{
				moveToward(bee, home, elapsed);
				if(isTouching(bee, home))
				{
					home.honey += bee.pollen;
					bee.pollen = 0;
					updateScore(home.honey);
				}
			}
			return;
		}
		
		if(bee.flower == null)
		{
			bee.turnsSearching++;
			bee.flower = getClosestFlower(bee.x,bee.y,true);
			
			if(bee.flower != null && bee.flower.pollen == 0)
			{
				bee.flower == null;
			}

			if(bee.turnsSearching > 2)
			{
				bee.flower = getRandomFlower();
				bee.turnsSearching = 0;
			}

			if(bee.flower != null && bee.flower.pollen > 0)
			{
				bee.turnsSearching = 0;
			}
		}
		if(bee.flower != null)
		{
			moveToward(bee, bee.flower, elapsed);
			if(isTouching(bee, bee.flower))
			{
				if(bee.flower.pollen > 0)
				{
					bee.pollen = bee.flower.pollen;
					emptyFlower(bee.flower);
				}
				bee.flower = null;
			}
		}
	}

	private function emptyFlower(flower:Flower)
	{
		flower.pollen = 0;
		flower.cooldown = flower.maxCooldown;
		flower.alpha = 0.25;
	}

	private function distTest(x1:Float,y1:Float,x2:Float,y2:Float,r:Float):Bool
	{
		var dx = (x1-x2);
		var dy = (y1-y2);
		var d2 = (dx*dx)+(dy*dy);
		
		if(d2 <= r*r) return true;
		return false;
	}

	private function isTouching(obj1:Sprite, obj2:Sprite):Bool
	{
		if(distTest(obj1.x+obj1.width/2,obj1.y+obj1.height/2,obj2.x+obj2.width/2,obj2.y+obj2.height/2,obj1.width/3))
		{
			return true;
		}
		return false;
	}

	private function moveToward(mover:Mover, target:Sprite, elapsed:Float)
	{
		mover.move.x = target.x-mover.x;
		mover.move.y = target.y-mover.y;
		mover.move.normalize(1.0);
		
		var targetRotation = Math.atan2(mover.move.y,mover.move.x) * 180 / Math.PI;

		mover.rotation = lerp(mover.rotation, targetRotation + 90, 5.0*elapsed);
		
		mover.x += mover.move.x * mover.speed * elapsed;
		mover.y += mover.move.y * mover.speed * elapsed;
	}

	private function lerp(a:Float, b:Float, amt:Float):Float
	{
		var aAmt = 1.0-amt;
		var bAmt = amt;
		return a*aAmt + b*bAmt;
	}

	private function getClosestFlower(x:Float, y:Float, withMostPollen:Bool=false):Flower
	{
		var bestd2:Float = Math.POSITIVE_INFINITY;
		var bestFlower:Flower = null;
		for(flower in flowers)
		{
			var dx = flower.x-x;
			var dy = flower.y-y;
			var d2 = dx*dx+dy*dy;
			if(d2 <= bestd2) 
			{
				if(withMostPollen)
				{
					if(bestFlower == null || flower.pollen >= bestFlower.pollen)
					{
						bestd2 = d2;
						bestFlower = flower;
					}
				}
				else
				{
					bestd2 = d2;
					bestFlower = flower;
				}
			}
		}
		return bestFlower;
	}
	
	private function getRandomFlower():Flower
	{
		var i:Int = Std.int(Math.random() * flowers.length);
		return flowers[i];
	}

	public function makeHome(x:Float, y:Float):Home
	{
		var home = new Home();
		addChild(home);
		home.x = x - home.width/2;
		home.y = y - home.height/2;
		return home;
	}

	public function makeBee(x:Float, y:Float):Bee
	{
		var bee = new Bee();
		bees.push(bee);
		addChild(bee);
		bee.x = x - bee.width/2;
		bee.y = y - bee.height/2;
		return bee;
	}

	public function makeFlower(i:Int, x:Float, y:Float):Flower
	{
		if(i < 0 || i > 3) return null;
		var flower = new Flower(i);
		flowers.push(flower);
		addChild(flower);
		flower.x = x - flower.width/2;
		flower.y = y - flower.height/2;
		return flower;
	}
	
}