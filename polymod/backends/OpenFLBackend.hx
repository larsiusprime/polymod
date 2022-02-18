package polymod.backends;

#if (!openfl || nme)
class OpenFLBackend extends StubBackend
{
	public function new()
	{
		super();
		Polymod.error(FAILED_CREATE_BACKEND, "OpenFLBackend requires the openfl library, did you forget to install it?");
	}
}
#else
#if !nme
class OpenFLBackend extends LimeBackend
{
	public override function clearCache()
	{
		super.clearCache();

		for (key in openfl.Assets.cache.getBitmapKeys())
		{
			openfl.Assets.cache.removeBitmapData(key);
		}
		for (key in openfl.Assets.cache.getFontKeys())
		{
			openfl.Assets.cache.removeFont(key);
		}
		for (key in openfl.Assets.cache.getSoundKeys())
		{
			openfl.Assets.cache.removeSound(key);
		}
	}
}
#end
#end
