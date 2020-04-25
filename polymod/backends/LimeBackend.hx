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
import polymod.backends.PolymodAssetLibrary;
import polymod.backends.PolymodAssets.PolymodAssetType;
#if unifill
import unifill.Unifill;
#end
#if (lime && !nme)
    import lime.app.Future;
    import lime.utils.Assets;
    import lime.net.HTTPRequest;
    import lime.graphics.Image;
    import lime.text.Font;
    import lime.utils.Bytes;
    #if (lime >= "4.0.0")
    import lime.utils.AssetLibrary;
    import lime.media.AudioBuffer;
    import lime.utils.AssetType;
    #else
    import lime.Assets.AssetType;
    import lime.Assets.AssetLibrary;
    import lime.audio.AudioBuffer;
    #end
#end

#if (!lime || nme)
class LimeBackend extends StubBackend
{
    public function new()
    {
        super();
        Polymod.error(FAILED_CREATE_BACKEND,"LimeBackend requires the lime library, did you forget to install it?"); 
    }
}
#else
#if !nme
class LimeBackend implements IBackend
{
    //STATIC:
    private static var defaultAssetLibrary:AssetLibrary = null;
    private static function getDefaultAssetLibrary()
    {
        if(defaultAssetLibrary == null)
        {
            defaultAssetLibrary = Assets.getLibrary("default");
        }
        return defaultAssetLibrary;
    }

    private static function restoreDefaultAssetLibrary()
    {
        if(defaultAssetLibrary != null)
        {
            Assets.registerLibrary("default", defaultAssetLibrary);
        }
    }

    //Instance:
    public var polymodLibrary:PolymodAssetLibrary;
    public var modLibrary(default, null):LimeModLibrary;
    public var fallback(default, null):AssetLibrary;
    
    public function new (){}

    public function init()
    {
        fallback = getDefaultAssetLibrary();
        modLibrary = new LimeModLibrary(this);
        Assets.registerLibrary("default", modLibrary);
    }

    public function destroy()
    {
        restoreDefaultAssetLibrary();
        polymodLibrary = null;
        modLibrary.destroy();
        modLibrary = null;
        fallback = null;
    }

    public function exists(id:String):Bool
    {
        return modLibrary.exists(id, null);
    }

    public function getBytes(id:String):Bytes
    {
        return modLibrary.getBytes(id);
    }

    public function getText(id:String):String
    {
        return modLibrary.getText(id);
    }

    public function getPath(id:String):String
    {
        return modLibrary.getPath(id);
    }

    public function list(type:PolymodAssetType=null):Array<String>
    {
        return modLibrary.list(type == null ? null : LimeModLibrary.PolyToLime(type));
    }

    public function clearCache()
    {
        if (defaultAssetLibrary != null)
        {
            for (key in Assets.cache.audio.keys())
            {
                Assets.cache.audio.remove(key);
            }
            for (key in Assets.cache.font.keys())
            {
                Assets.cache.font.remove(key);
            }
            for (key in Assets.cache.image.keys())
            {
                Assets.cache.image.remove(key);
            }
        }
    }

    public function stripAssetsPrefix(id:String):String
    {
        if (Util.uIndexOf(id, "assets/") == 0)
        {
            id = Util.uSubstring(id, 7);
        }
        return id;
    }
}

class LimeModLibrary extends AssetLibrary
{
    public static function LimeToPoly(type:AssetType):PolymodAssetType
    {
        return switch(type)
        {
            case AssetType.BINARY: PolymodAssetType.BYTES;
            case AssetType.FONT: PolymodAssetType.FONT;
            case AssetType.IMAGE: PolymodAssetType.IMAGE;
            case AssetType.MUSIC: PolymodAssetType.AUDIO_MUSIC;
            case AssetType.SOUND: PolymodAssetType.AUDIO_SOUND;
            case AssetType.MANIFEST: PolymodAssetType.MANIFEST;
            case AssetType.TEMPLATE: PolymodAssetType.TEMPLATE;
            case AssetType.TEXT: PolymodAssetType.TEXT;
            default: PolymodAssetType.UNKNOWN;
        }
    }

    public static function PolyToLime(type:PolymodAssetType):AssetType
    {
        return switch(type)
        {
            case PolymodAssetType.BYTES: AssetType.BINARY;
            case PolymodAssetType.FONT : AssetType.FONT;
            case PolymodAssetType.IMAGE : AssetType.IMAGE;
            case PolymodAssetType.AUDIO_MUSIC : AssetType.MUSIC;
            case PolymodAssetType.AUDIO_SOUND : AssetType.SOUND;
            case PolymodAssetType.AUDIO_GENERIC : AssetType.SOUND;
            case PolymodAssetType.MANIFEST : AssetType.MANIFEST;
            case PolymodAssetType.TEMPLATE : AssetType.TEMPLATE;
            case PolymodAssetType.TEXT : AssetType.TEXT;
            default: AssetType.BINARY;
        }
    }

    var b:LimeBackend;
    var p:PolymodAssetLibrary;
    var fallback:AssetLibrary;
    var hasFallback:Bool;
    var type(default, null):Map<String,AssetType>;
    
    public function new(backend:LimeBackend)
    {
        b = backend;
        p = b.polymodLibrary;
        fallback = b.fallback;
        hasFallback = fallback != null;
        super();
    }

    public function destroy()
    {
        b = null;
        p = null;
        fallback = null;
        type = null;
    }

    public override function getAsset(id:String, type:String):Dynamic
    {
        var e = p.check(id, LimeToPoly(cast type));
        if (type == TEXT)
        {
            return getText(id);
        }
        if (!e && hasFallback)
        {
            return fallback.getAsset(id, type);
        }
        return super.getAsset(id,type);
    }

    public override function exists (id:String, type:String):Bool
    {
        var e = p.check(id, LimeToPoly(cast type));
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
        {
            modText = fallback.getText(id);
        }
        
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
}
#end
#end