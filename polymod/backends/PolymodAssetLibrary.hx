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
import polymod.fs.PolymodFileSystem;
import polymod.util.Util;
import polymod.backends.IBackend;
import polymod.backends.PolymodAssets.PolymodAssetType;
import polymod.format.ParseRules;
import polymod.Polymod.Framework;

typedef PolymodAssetLibraryParams = {
   
    /**
     * the backend used to fetch your default assets
     */
    backend:IBackend,

       /**
     * paths to each mod's root directories.
     * This takes precedence over the "Dir" parameter and the order matters -- mod files will load from first to last, with last taking precedence
     */
    dirs:Array<String>,

    /**
     * (optional) formatting rules for parsing various data formats
     */
    ?parseRules:ParseRules,

    /**
    * (optional) list of files it ignore in this mod asset library (get the fallback version instead)
     */
    ?ignoredFiles:Array<String>,
    
    /**
     * (optional) maps file extensions to asset types. This ensures e.g. text files with unfamiliar extensions are handled properly.
     */
    ?extensionMap:Map<String,PolymodAssetType>
}

class PolymodAssetLibrary
{
    public var backend(default, null):IBackend;
    
    public var type(default, null):Map<String, PolymodAssetType>;
    
    public var dirs:Array<String> = null;
    public var ignoredFiles:Array<String> = null;
    private var parseRules:ParseRules = null;
    private var extensions:Map<String,PolymodAssetType>;

    public function new(params:PolymodAssetLibraryParams)
    {
        backend = params.backend;
        backend.polymodLibrary = this;
        dirs = params.dirs;
        parseRules = params.parseRules;
        ignoredFiles = params.ignoredFiles != null ? params.ignoredFiles.copy() : [];
        extensions = params.extensionMap;
        backend.clearCache();
        init();
    }

    public function destroy()
    {
        if(backend != null)
        {
            backend.destroy();
        }
    }

    public function mergeAndAppendText(id:String, modText:String):String
    {
        modText = Util.mergeAndAppendText(modText, id, dirs, getTextDirectly, parseRules);
        return modText;
    }

    public function getExtensionType(ext:String):PolymodAssetType
    {
        ext = ext.toLowerCase();
        if(extensions.exists(ext) == false) return BYTES;
        return extensions.get(ext);
    }
    
    /**
     * Get text without consideration of any modifications
     * @param	id
     * @param	theDir
     * @return
     */
    public function getTextDirectly (id:String, directory:String = ""):String
    {
        var bytes = null;
        if (checkDirectly(id, directory))
        {
            bytes = PolymodFileSystem.getFileBytes(file(id, directory));
        }
        else
        {
            bytes = backend.getBytes(id);
        }
        
        if (bytes == null)
        {
            return null;
        } 
        else
        {
            return bytes.getString (0, bytes.length);
        }
        return null;
    }

    public function exists (id:String):Bool { return backend.exists(id); }
    public function getText (id:String):String { return backend.getText(id); }
    public function getBytes (id:String):Bytes { return backend.getBytes(id); }
    public function getPath(id:String):String { return backend.getPath(id); }

    public function list(type:PolymodAssetType=null):Array<String> { return backend.list(type); }

    public function listModFiles (type:PolymodAssetType=null):Array<String>
    {
        var items = [];
        
        for (id in this.type.keys ())
        {
            if (id.indexOf("_append") == 0 || id.indexOf("_merge") == 0) continue;
            if (type == null || type == BYTES || check (id, type))
            {
                items.push (id);
            }
        }
        
        return items;
    }

    /**
     * Check if the given asset exists in the file system
     * (If using multiple mods, it will return true if ANY of the mod folders contains this file)
     * @param	id
     * @return
     */
    public function check(id:String, type:PolymodAssetType=null)
    {
        var exists = _checkExists(id);
        if (exists && type != null && type != PolymodAssetType.BYTES)
        {
            var otherType = this.type.get(id);
            exists = (otherType == type || otherType == PolymodAssetType.BYTES || otherType == null || otherType == "");
        }
        return exists;
    }

    public function getType(id:String):PolymodAssetType
    {
        var exists = _checkExists(id);
        if (exists)
        {
            return this.type.get(id);
        }
        return null;
    }

    public function checkDirectly(id:String, dir:String):Bool
    {
        id = backend.stripAssetsPrefix(id);
        if (dir == null || dir == "")
        {
            return PolymodFileSystem.exists(id);
        }
        else
        {
            var thePath = Util.uCombine([dir, Util.sl(), id]);
            if (PolymodFileSystem.exists(thePath))
            {
                return true;
            }
        }
        return false;
    }

    /**
     * Get the filename of the given asset id
     * (If using multiple mods, it will check all the mod folders for this file, and return the LAST one found)
     * @param	id
     * @return
     */
    public function file(id:String, theDir:String = ""):String
    {
        id = backend.stripAssetsPrefix(id);
        if (theDir != "")
        {
            return Util.pathJoin(theDir,id);
        }
        
        var theFile = "";
        for (d in dirs)
        {
            var thePath = Util.pathJoin(d,id);
            if(PolymodFileSystem.exists(thePath))
            {
                theFile = thePath;
            }
        }
        return theFile;
    }

    private function _checkExists(id:String):Bool
    {
        if(ignoredFiles.length > 0 && ignoredFiles.indexOf(id) != -1) return false;
        var exists = false;
        id = backend.stripAssetsPrefix(id);
        for (d in dirs)
        {
            if(PolymodFileSystem.exists(Util.pathJoin(d, id)))
            {
                exists = true;
            }
        }
        return exists;
    }

    private function init()
    {
        type = new Map<String,PolymodAssetType>();
        initExtensions();
        if (parseRules == null) parseRules = ParseRules.getDefault();
        if (dirs != null)
        {
            for (d in dirs)
            {
                initMod(d);
            }
        }
    }

    private function initExtensions()
    {
        extensions = new Map<String,PolymodAssetType>();
        _extensionSet("mp3", AUDIO_GENERIC);
        _extensionSet("ogg", AUDIO_GENERIC);
        _extensionSet("wav", AUDIO_GENERIC);
        _extensionSet("jpg", IMAGE);
        _extensionSet("png", IMAGE);
        _extensionSet("gif", IMAGE);
        _extensionSet("tga", IMAGE);
        _extensionSet("bmp", IMAGE);
        _extensionSet("tif", IMAGE);
        _extensionSet("tiff", IMAGE);
        _extensionSet("txt", TEXT);
        _extensionSet("xml", TEXT);
        _extensionSet("json", TEXT);
        _extensionSet("csv", TEXT);
        _extensionSet("tsv", TEXT);
        _extensionSet("mpf", TEXT);
        _extensionSet("tsx", TEXT);
        _extensionSet("tmx", TEXT);
        _extensionSet("vdf", TEXT);
        _extensionSet("ttf", FONT);
        _extensionSet("otf", FONT);
    }

    private function _extensionSet(str:String, type:PolymodAssetType)
    {
        if(extensions.exists(str) == false)
        {
            extensions.set(str, type);
        }
    }

    private function initMod(d:String):Void
    {
        if (d == null) return;
        
        var all:Array<String> = null;
        
        if (d == "" || d == null)
        {
            all = [];
        }
        
        try
        {
            if (PolymodFileSystem.exists(d))
            {
                all = PolymodFileSystem.readDirectoryRecursive(d);
            }
            else
            {
                all = [];
            }
        }
        catch (msg:Dynamic)
        {
            throw ("ModAssetLibrary._initMod(" + d + ") failed : " + msg);
        }
        for (f in all)
        {
            var doti = Util.uLastIndexOf(f,".");
            var ext:String = doti != -1 ? f.substring(doti+1) : "";
            ext = ext.toLowerCase();
            var assetType = getExtensionType(ext);
            type.set(f,assetType);
        }
    }
}