package polymod.backends;

import haxe.io.Bytes;
import polymod.backends.PolymodAssets.PolymodAssetType;
import polymod.backends.PolymodAssetLibrary;

interface IBackend
{
    public var polymodLibrary:PolymodAssetLibrary;

    public function init():Void;

    public function clearCache():Void;
    public function exists(id:String, type:PolymodAssetType):Bool;

    public function getBytes(id:String):Bytes;
    public function getText(id:String):String;
}