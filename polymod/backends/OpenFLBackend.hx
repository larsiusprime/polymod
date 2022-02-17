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

		for (key in openfl.utils.AssetCache.getBitmapKeys())
		{
			openfl.utils.AssetCache.removeBitmapData(key);
		}
		for (key in openfl.utils.AssetCache.getFontKeys())
		{
			openfl.utils.AssetCache.removeFont(key);
		}
		for (key in openfl.utils.AssetCache.getSoundKeys())
		{
			openfl.utils.AssetCache.removeSound(key);
		}
	}
}
#end
#end
