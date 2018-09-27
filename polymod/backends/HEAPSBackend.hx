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
import polymod.Polymod.PolymodError;
import polymod.fs.PolymodFileSystem;
import polymod.util.Util;
import polymod.util.Util.MergeRules;
import polymod.backends.PolymodAssetLibrary;
import polymod.backends.PolymodAssets.PolymodAssetType;
#if unifill
import unifill.Unifill;
#end
#if heaps
    import heaps.hxd.Res.Loader;
    import heaps.hxd.FileSystem;
#end

#if !heaps
class HEAPSBackend extends StubBackend
{
    public function new()
    {
        super();
        Polymod.error(FAILED_CREATE_BACKEND,"HEAPSBackend requires the heaps library, did you forget to install it?"); 
    }
}
#else
class HeapsBackend implements IBackend
{
    //STATIC:
    private static var defaultLoader:Loader = null;
    private static function getDefaultLoader()
    {
        if(defaultLoader == null)
        {
            var loader = Res.loader;
            if(Std.is(loader, HEAPSModLoader) == false)
            {
                defaultLoader = load;
            }
        }
        return defaultLoader;
    }

    private static function restoreDefaultLoader()
    {
        if(defaultLoader != null)
        {
            Res.loader = defaultLoader;
        }
    }

    //Instance:
    public var polymodLibrary:PolymodAssetLibrary;
    public var modLoader(default, null):Loader;
    public var fallback(default, null):Loader;
    
    public function new (){}

    public function init()
    {
        fallback = getDefaultLoader();
        modLoader = new HEAPSModLoader(this);
        Res.loader = modLoader;
    }

    public function exists(id:String, type:PolymodAssetType):Bool
    {
        return modLibrary.exists(id, HEAPSModLoader.PolyToHEAPS(type));
    }

    public function getPath(id:String):String
    {
        return modLibrary.getPath(id);
    }

    public function getBytes(id:String):Bytes
    {
        return modLibrary.getBytes(id);
    }

    public function getText(id:String):String
    {
        return modLibrary.getText(id);
    }

    public function clearCache()
    {
        if(defaultLoader != null)
        {
            defaultLoader.cleanCache();
        }
        /*
        if (defaultAssetLibrary != null)
        {
            for (key in LimeAssets.cache.audio.keys())
            {
                LimeAssets.cache.audio.remove(key);
            }
            for (key in LimeAssets.cache.font.keys())
            {
                LimeAssets.cache.font.remove(key);
            }
            for (key in LimeAssets.cache.image.keys())
            {
                LimeAssets.cache.image.remove(key);
            }
        }
        openfl.Assets.cache.clear();
        */
    }
}

class HEAPSModLoader extends Loader
{
    public static function HEAPSToPoly(type:ResType):PolymodAssetType
    {
        return switch(type)
        {
            case ResType.BYTES: PolymodAssetType.BYTES;
            case ResType.MODEL: PolymodAssetType.MODEL;
            case ResType.TEXTURE: PolymodAssetType.TEXTURE;
            case ResType.TILE: PolymodAssetType.TILE;
            case ResType.TEXT: PolymodAssetType.TEXT;
            case ResType.IMAGE: PolymodAssetType.IMAGE;
            case ResType.SOUND: PolymodAssetType.AUIDO_GENERIC;
            case ResType.PREFAB: PolymodAssetType.PREFAB;
            default: PolymodAssetType.UNKNOWN;
        }
    }

    public static function PolyToLime(type:PolymodAssetType):AssetType
    {
        return switch(type)
        {
            case PolymodAssetType.BYTES: ResType.BYTES;
            case PolymodAssetType.MODEL: ResType.MODEL;
            case PolymodAssetType.TEXTURE: ResType.TEXTURE;
            case PolymodAssetType.TILE: ResType.TILE;
            case PolymodAssetType.TEXT: ResType.TEXT;
            case PolymodAssetType.IMAGE : ResType.IMAGE;
            case PolymodAssetType.AUDIO_SOUND : ResType.SOUND;
            case PolymodAssetType.AUDIO_MUSIC : ResType.SOUND;
            case PolymodAssetType.AUDIO_GENERIC : ResType.SOUND;
            case PolymodAssetType.PREFAB : ResType.PREFAB;
            default: ResType.UNKNOWN;
        }
    }

    var b:HEAPSBackend;
    var p:PolymodAssetLibrary;
    var fallback:Loader;
    var hasFallback:Bool;
    var type(default, null):Map<String,ResType>;
    
    public function new(backend:HEAPSBackend)
    {
        b = backend;
        p = b.polymodLibrary;
        fallback = b.fallback;
        hasFallback = fallback != null;
        var fileSystem = new HEAPSModFileSystem();
        super(fs);
    }


    /*
    public override function getAsset(id:String, type:String):Dynamic
    {
        var e = p.check(id, HEAPSToPoly(cast type));
        if (!e && hasFallback)
        {
            return fallback.getAsset(id, type);
        }
        return super.getAsset(id,type);
    }

    public override function exists (id:String, type:String):Bool
    {
        var e = p.check(id, HEAPSToPoly(cast type));
        if (!e && hasFallback) return fallback.exists(id, type);
        return e;
    }

    public override function getAudioBuffer (id:String):AudioBuffer
    {
        if (p.check(id))
            return AudioBuffer.fromBytes(PolymodFileSystem.getFileBytes(p.file(id)));
        else if(hasFallback)
            return fallback.getAudioBuffer(id);
        return null;
    }

    public override function getBytes (id:String):Bytes
    {
        var file = p.file(id);
        if (p.check(id))
            return PolymodFileSystem.getFileBytes(p.file(id));
        else if(hasFallback)
            return fallback.getBytes(id);
        return null;
    }

    public override function getFont (id:String):Font
    {
        if (p.check(id))
            return Font.fromBytes(PolymodFileSystem.getFileBytes(p.file(id)));
        else if(hasFallback)
            return fallback.getFont(id);
        return null;
    }

    public override function getImage (id:String):Image
    {
        if (p.check(id))
            return Image.fromBytes(PolymodFileSystem.getFileBytes(p.file(id)));
        else if(hasFallback)
            return fallback.getImage(id);
        return null;
    }

    public override function getPath (id:String):String
    {
        if (p.check(id))
            return p.file(id);
        else if(hasFallback)
            return fallback.getPath(id);
        return null;
    }

    public override function getText (id:String):String
    {
        var modText = null;
        if (p.check(id))
        {
            modText = super.getText(id);
        }
        else if(hasFallback)
            modText = fallback.getText(id);
        
        if (modText != null)
        {
            modText = p.mergeAndAppendText(id, modText);
        }
        
        return modText;
    }

    public override function loadBytes (id:String):Future<Bytes> 
    {
        //TODO: filesystem
        if (p.check(id))
        {
            return Bytes.loadFromFile (p.file(id));
        }
        else if(hasFallback)
        {
            return fallback.loadBytes(id);
        }
        return Bytes.loadFromFile("");
    }

    public override function loadFont(id:String):Future<Font>
    {
        //TODO: filesystem
        if (p.check(id))
        {
            #if (js && html5)
            return Font.loadFromName (paths.get (p.file(id)));
            #else
            return Font.loadFromFile (paths.get (p.file(id)));
            #end
        }
        else if(hasFallback)
        {
            return fallback.loadFont(id);
        }
        #if (js && html5)
        return Font.loadFromName (paths.get (""));
        #else
        return Font.loadFromFile (paths.get (""));
        #end
    }

    public override function loadImage(id:String):Future<Image>
    {
        //TODO: filesystem
        if (p.check(id))
        {
            return Image.loadFromFile(p.file(id));
        }
        else if(hasFallback)
        {
            return fallback.loadImage(id);
        }
        return Image.loadFromFile("");
    }

    public override function loadAudioBuffer(id:String)
    {
        //TODO: filesystem
        if (p.check(id))
        {
            //return 
            if (pathGroups.exists(p.file(id)))
            {
                return AudioBuffer.loadFromFiles (pathGroups.get(p.file(id)));
            }
            else
            {
                return AudioBuffer.loadFromFile(paths.get(p.file(id)));
            }
        }
        else if(hasFallback)
        {
            return fallback.loadAudioBuffer(id);
        }
        return AudioBuffer.loadFromFile("");
    }

    public override function loadText(id:String):Future<String>
    {
        //TODO: FileSystem
        if (p.check(id))
        {
            var request = new HTTPRequest<String> ();
            return request.load (paths.get (p.file(id)));
        }
        else if(hasFallback)
        {	
            return fallback.loadText(id);
        }
        var request = new HTTPRequest<String> ();
        return request.load ("");
    }

    public override function isLocal (id:String, type:String):Bool
    {
        if (p.check(id))
            return true;
        else if(hasFallback)
            return fallback.isLocal(id, type);
        return false;
    }

    public override function list (type:String):Array<String>
    {
        var otherList = hasFallback ? fallback.list(type) : [];
        
        var requestedType = type != null ? cast (type, AssetType) : null;
        var items = [];
        
        for (id in p.type.keys ())
        {
            if (id.indexOf("_append") == 0 || id.indexOf("_merge") == 0) continue;
            if (requestedType == null || exists (id, requestedType))
            {
                items.push (id);
            }
        }
        
        for (otherId in otherList)
        {
            if (items.indexOf(otherId) == -1)
            {
                if (requestedType == null || fallback.exists(otherId, type))
                {
                    items.push(otherId);
                }
            }
        }
        
        return items;
    }
    */
}

class HEAPSModFileSystem implements FileSystem
{
    super();
}

@:enum abstract ResType(String) from String to String
{
    var BYTES = "BYTES";
    var MODEL = "MODEL";
    var TEXTURE = "TEXTURE";
    var TEXT = "TEXT";
    var TILE = "TILE";
    var IMAGE = "IMAGE";
    var SOUND = "SOUND";
    var PREFAB = "PREFAB";
    var UNKNOWN = "UNKNOWN";

    public static function fromString(str:String):ResType
    {
        str = str.toUpperCase();
        switch(str)
        {
            case BYTES, MODEL, TEXTURE, TEXT, TILE, IMAGE, SOUND, PREFAB, UNKNOWN: return str;
            default: return UNKNOWN;
        }
        return UNKNOWN;
    }
}
#end