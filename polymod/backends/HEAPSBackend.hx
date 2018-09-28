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

import haxe.io.Bytes;
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
    import hxd.Res;
    import hxd.res.Any;
    import hxd.res.Loader;
    import hxd.fs.FileEntry;
    import hxd.fs.FileSystem;
    import hxd.fs.LocalFileSystem;
    import hxd.fs.BytesFileSystem.BytesFileEntry;
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
class HEAPSBackend implements IBackend
{
    //STATIC:
    public static var defaultLoader:Loader = null;
    private static function getDefaultLoader()
    {
        if(defaultLoader == null)
        {
            var loader = Res.loader;
            if(Std.is(loader, HEAPSModLoader) == false)
            {
                defaultLoader = loader;
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
    public var modLoader(default, null):HEAPSModLoader;
    public var fallback(default, null):Loader;
    
    public function new (){}

    public function init()
    {
        trace("init heaps backend");
        fallback = getDefaultLoader();
        modLoader = new HEAPSModLoader(this);
        Res.loader = modLoader;
    }

    public function destroy()
    {
        restoreDefaultLoader();
        modLoader.destroy();
        modLoader = null;
        fallback = null;
        polymodLibrary = null;
    }

    public function getBytes(id:String):Bytes
    {
        return modLoader.load(id).entry.getBytes();
    }

    public function getText(id:String):String
    {
        return modLoader.loadText(id).toText();
    }

    public function clearCache()
    {
        if(defaultLoader != null)
        {
            defaultLoader.cleanCache();
        }
    }

    public function stripAssetsPrefix(id:String):String
    {
        return id;
    }
}

class HEAPSModLoader extends Loader
{
    var b:HEAPSBackend;
    var p:PolymodAssetLibrary;
    var fallback:Loader;
    var hasFallback:Bool;
    
    public function new(backend:HEAPSBackend)
    {
        b = backend;
        p = b.polymodLibrary;
        fallback = b.fallback;
        hasFallback = fallback != null;
        var fileSystem = new ModFileSystem(p);
        super(fileSystem);
    }

    public function destroy()
    {
        b = null;
        p = null;
        fallback = null;
    }

    public override function exists(path:String):Bool
    {
        var e = p.check(path);
        if (!e && hasFallback) return fallback.exists(path);
        return e;
    }

    public override function load(path:String):Any
    {
        trace("load("+path+")");
        if(p.getExtensionType(path) == TEXT)
        {
            return loadText(path);
        }
        var e = p.check(path);
        trace("e = " + e);
        if (!e && hasFallback)
        {
            trace("load from fallback");
            var result = fallback.load(path);
            trace('result = ' + result);
            trace("entry = " + result.entry);
            return result;
        }
        trace("load from super");
        return super.load(path);
    }

    public function loadText (path:String):Any
    {
        var modText = null;
        if (p.check(path))
        {
            modText = load(path).toText();
        }
        else if(hasFallback)
        {
            modText = fallback.load(path).toText();
        }
        
        if (modText != null)
        {
            modText = p.mergeAndAppendText(path, modText);
        }
        return new Any(this, new ModFileEntry(path, Bytes.ofString(modText)));
    }
}

class ModFileEntry extends BytesFileEntry
{
    public function new(path:String, bytes:Bytes)
    {
        var stack:String = haxe.CallStack.toString(haxe.CallStack.callStack());
        //trace("new ModFileEntry("+path+","+bytes+") caller = " + stack);
        super(path, bytes);
    }
}

class ModFileSystem implements FileSystem
{
    var p:PolymodAssetLibrary;
    var b:HEAPSBackend;

    public function new(polymodAssetLibrary:PolymodAssetLibrary)
    {
        p = polymodAssetLibrary;
        b = cast p.backend;
    }

    public function getRoot():FileEntry
    {
        return HEAPSBackend.defaultLoader.fs.getRoot();
    }

    public function get(path:String):FileEntry
    {
        trace("get("+path+") --> " + p.file(path));
        var file = p.file(path);
        var bytes = PolymodFileSystem.getFileBytes(file);
        if(bytes == null)
        {
            var entry = b.fallback.fs.get(path);
            return entry;
        }
        var modEntry = new ModFileEntry(path, bytes);
        return modEntry;
    }
    
    public function exists( path : String ) : Bool
    {
        return b.modLoader.exists(path);
    }

    public function dispose() : Void
    {
        p = null;
        b = null;
    }
}
#end