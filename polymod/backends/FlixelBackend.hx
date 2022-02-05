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
		#if !macro
		@:privateAccess
		for (key in flixel.FlxG.bitmap._cache.keys())
		{
			var obj = flixel.FlxG.bitmap._cache.get(key);
			if (obj != null)
			{
				openfl.Assets.cache.removeBitmapData(key);
				flixel.FlxG.bitmap._cache.remove(key);
				obj.destroy();
			}
		}
		#end
		super.clearCache();
	}
}
#end
