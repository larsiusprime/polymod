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
		// This destroys the bitmap cache completely, so we don't need to iterate with .
		openfl.Assets.cache.clear();
	}
}
#end
#end
