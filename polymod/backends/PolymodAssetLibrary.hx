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

import polymod.backends.IBackend;
import polymod.backends.PolymodAssets.PolymodAssetType;
import polymod.Polymod.Framework;
import polymod.util.Util;
import polymod.util.Util.MergeRules;
import polymod.fs.PolymodFileSystem;

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
	 * (optional) formatting rules for merging various data formats
	 */
	?mergeRules:MergeRules,

	/**
 	 * (optional) list of files it ignore in this mod asset library (get the fallback version instead)
	 */
	?ignoredFiles:Array<String>
}

class PolymodAssetLibrary
{
	public var backend(default, null):IBackend;
	
	public var type(default, null):Map<String, PolymodAssetType>;

	public var dirs:Array<String> = null;
	private var mergeRules:MergeRules = null;
	private var ignoredFiles:Array<String> = null;

	public function new(params:PolymodAssetLibraryParams)
	{
		backend = params.backend;
		backend.polymodLibrary = this;
		dirs = params.dirs;
		mergeRules = params.mergeRules;
		ignoredFiles = params.ignoredFiles != null ? params.ignoredFiles.copy() : [];
		backend.clearCache();
		init();
	}

	public function exists(id:String, type:PolymodAssetType)
	{
		return backend.exists(id, type);
	}

	public function mergeAndAppendText(id:String, modText:String):String
	{
		modText = Util.mergeAndAppendText(modText, id, dirs, getTextDirectly, mergeRules);
		return modText;
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

	public function getText (id:String):String
	{
		return backend.getText(id);
	}

	public function listModFiles (type:PolymodAssetType):Array<String>
	{
		var items = [];
		
		for (id in this.type.keys ())
		{
			if (id.indexOf("_append") == 0 || id.indexOf("_merge") == 0) continue;
			if (type == null || type == BYTES || backend.exists (id, type))
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
		if(ignoredFiles.length > 0 && ignoredFiles.indexOf(id) != -1) return false;
		var exists = false;
		id = Util.stripAssetsPrefix(id);
		for (d in dirs)
		{
			if(PolymodFileSystem.exists(Util.pathJoin(d, id)))
			{
				exists = true;
			}
		}
		if (exists && type != null && type != PolymodAssetType.BYTES)
		{
			exists = (this.type.get(file(id)) == type);
		}
		return exists;
	}

	public function checkDirectly(id:String, dir:String):Bool
	{
		id = Util.stripAssetsPrefix(id);
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
		id = Util.stripAssetsPrefix(id);
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

	
	private function init()
	{
		type = new Map<String,PolymodAssetType>();
		if (dirs != null)
		{
			for (d in dirs)
			{
				_initMod(d);
			}
		}
	}

	private function _initMod(d:String):Void
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
			var assetType = switch(ext)
			{
				case "mp3", "ogg", "wav": PolymodAssetType.AUDIO_GENERIC;
				case "jpg", "png":PolymodAssetType.IMAGE;
				case "txt", "xml", "json", "tsv", "csv", "mpf", "tsx", "tmx", "vdf": PolymodAssetType.TEXT;
				case "ttf", "otf": PolymodAssetType.FONT;
				default: PolymodAssetType.BYTES;
			}
			type.set(f,assetType);
		}
	}
}