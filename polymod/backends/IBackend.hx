package polymod.backends;

import haxe.io.Bytes;
import polymod.Polymod.FrameworkParams;
import polymod.backends.PolymodAssets.PolymodAssetType;
import polymod.backends.PolymodAssetLibrary;

interface IBackend
{
	public var polymodLibrary:PolymodAssetLibrary;

	public function init(?params:FrameworkParams):Bool;
	public function destroy():Void;

	public function clearCache():Void;

	public function exists(id:String):Bool;
	public function getBytes(id:String):Bytes;
	public function getText(id:String):String;

	public function getPath(id:String):String;
	public function list(type:PolymodAssetType = null):Array<String>;
}
