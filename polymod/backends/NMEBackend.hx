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

import haxe.xml.Fast;
import haxe.xml.Printer;
import polymod.Polymod;
import polymod.Polymod.FrameworkParams;
import polymod.Polymod.PolymodError;
import polymod.fs.PolymodFileSystem;
import polymod.util.Util;
import polymod.backends.PolymodAssetLibrary;
import polymod.backends.PolymodAssets.PolymodAssetType;
#if unifill
import unifill.Unifill;
#end

import haxe.io.Bytes;
#if nme
import nme.Assets;
import nme.AssetType;
import nme.AssetInfo;
#end

#if !nme
class NMEBackend extends StubBackend
{
    public function new()
    {
        super();
        Polymod.error(FAILED_CREATE_BACKEND,"NMEBackend requires the nme library, did you forget to install it?"); 
    }
}
#else
class NMEBackend implements IBackend
{
    //STATIC:
   
    //Instance:
    public var polymodLibrary:PolymodAssetLibrary;
    private var modAssets:Map<String, AssetInfo>;
    private var defaultAssets:Map<String, AssetInfo>;

    public function new (){}

    public function init(?params:FrameworkParams):Bool
    {
        restoreDefaultAssets();

        var list = polymodLibrary.listModFiles();
        modAssets = new Map<String, AssetInfo>();
        defaultAssets = new Map<String, AssetInfo>();

        for(file in list)
        {
            defaultAssets.set(file, nme.Assets.info.get(file));
            modAssets.set(file, new AssetInfo(
                polymodLibrary.file(file),
                PolyToNME(polymodLibrary.getType(file)),
                false, //??
                null,
                null,
                null
            ));
        }

        for(key in modAssets.keys())
        {
            nme.Assets.info.set(key, modAssets.get(key));
        }

        for (key in nme.Assets.info.keys())
        {
            var info = nme.Assets.info.get(key);
            if(info.type == TEXT)
            {
                if(info.isResource)
                {
                    var origText = PolymodAssets.getText(key);
                    var newText = polymodLibrary.mergeAndAppendText(key, origText);
                    if(origText != newText)
                    {
                        var byteArray = nme.utils.ByteArray.fromBytes(Bytes.ofString(newText));
                        info.setCache(byteArray, true);
                        info.isResource = false;
                    }
                }
                else
                {
                    var modFile = polymodLibrary.file(key);
                    nme.Assets.byteFactory.set( info.path, function(){
                        var bytes = null;
                        if(PolymodFileSystem.exists(modFile))
                        {
                            bytes = PolymodFileSystem.getFileBytes(modFile);
                        }
                        else
                        {
                            bytes = PolymodFileSystem.getFileBytes(key);
                        }
                        var origText = Std.string(bytes);
                        var newText = polymodLibrary.mergeAndAppendText(key, origText);
                        if(origText != newText)
                        {
                            return nme.utils.ByteArray.fromBytes(Bytes.ofString(newText));
                        }
                        return nme.utils.ByteArray.fromBytes(Bytes.ofString(origText));
                    });
                }
            }
        }

        return true;
    }

    public function destroy()
    {
        restoreDefaultAssets();
        polymodLibrary = null;
        modAssets = null;
        defaultAssets = null;
    }

    private function restoreDefaultAssets()
    {
        if(modAssets == null) return;
        for(key in modAssets.keys())
        {
            var modAsset = modAssets.get(key);
            if(modAsset != null)
            {
                nme.Assets.info.remove(key);
            }
            var defaultAsset = defaultAssets.get(key);
            if(defaultAsset != null)
            {
                nme.Assets.info.set(key, defaultAsset);
            }
        }
    }

    private function PolyToNME(type:PolymodAssetType):AssetType
    {
        return switch(type)
        {
            case PolymodAssetType.BYTES: AssetType.BINARY;
            case PolymodAssetType.FONT : AssetType.FONT;
            case PolymodAssetType.IMAGE : AssetType.IMAGE;
            case PolymodAssetType.AUDIO_MUSIC : AssetType.MUSIC;
            case PolymodAssetType.AUDIO_SOUND : AssetType.SOUND;
            case PolymodAssetType.TEXT : AssetType.TEXT;
            //case PolymodAssetType.SWF : AssetType.SWF;
            //case PolymodAssetType.MOVIE_CLIP : AssetType.MOVIE_CLIP;
            default: AssetType.BINARY;
        }
    }

    public function exists(id:String):Bool
    {
        return Assets.exists(id);
    }

    public function getBytes(id:String):Bytes
    {
        return Assets.getBytes(id);
    }

    public function getText(id:String):String
    {
        return Assets.getText(id);
    }

    public function clearCache()
    {
        for(key in Assets.info.keys())
        {
            var assetInfo = Assets.info.get(key);
            if(assetInfo != null && assetInfo.type == AssetType.IMAGE)
            {
                if(assetInfo.type == AssetType.IMAGE)
                {
                    Assets.cache.removeBitmapData(assetInfo.path);
                }
                assetInfo.cache = null;
            }
        }
    }

    public function stripAssetsPrefix(id:String):String
    {
        if (Util.uIndexOf(id, "assets/") == 0 || Util.uIndexOf(id, "Assets/") == 0)
        {
            id = Util.uSubstring(id, 7);
        }
        return id;
    }
}
#end