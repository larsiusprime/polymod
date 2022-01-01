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

package polymod.backends;

#if (!flixel)
class FlixelBackend extends StubBackend
{
	public function new()
	{
		super();
		Polymod.error(FAILED_CREATE_BACKEND, "FlixelBackend requires the flixel library, did you forget to install it?");
	}
}
#else
class FlixelBackend extends OpenFLBackend
{
	/**
	 * Special handling to ensure Flixel's aggressive Bitmap caches get cleared.
	 * Brought to you by Yoshubs.
	 */
	public override function clearCache()
	{
		@:privateAccess
		for (key in flixel.FlxG.bitmap._cache.keys())
		{
			var obj = flixel.FlxG.bitmap._cache.get(key);
			if (obj != null)
			{
				openfl.Assets.cache.cache.removeBitmapData(key);
				flixel.FlxG.bitmap._cache.remove(key);
				obj.destroy();
			}
		}
		super.clearCache();
	}
}
#end
