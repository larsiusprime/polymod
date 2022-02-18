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

import openfl.utils.AssetCache;

class OpenFLBackend extends LimeBackend
{
	var assetCache = new AssetCache();

	public override function clearCache()
	{
		super.clearCache();

		for (key in assetCache.getBitmapKeys())
		{
			assetCache.removeBitmapData(key);
		}
		for (key in assetCache.getFontKeys())
		{
			assetCache.removeFont(key);
		}
		for (key in assetCache.getSoundKeys())
		{
			assetCache.removeSound(key);
		}
	}
}
#end
#end
