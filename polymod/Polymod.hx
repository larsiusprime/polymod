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
 
package polymod;
import lime.utils.AssetLibrary;
import lime.utils.AssetType;
import polymod.library.ModAssetLibrary;
import polymod.library.JsonHelp;
import polymod.library.SemanticVersion;
import openfl.display.BitmapData;

import lime.utils.Assets in LimeAssets;
import openfl.utils.Assets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef PolymodParams = {
	/**
	 * root directory of all mods
	 */
	var modRoot:String;

	/**
	 * directory names of one or more mods, relative to modRoot
	 */
	var dirs:Array<String>;

	/**
	 * semantic version of your game's Mod API (will generate errors & warnings)
	 */
	var version:SemanticVersion;

	/**
	 * (optional) callback for any errors generated during mod initialization
	 */
	var errorCallback:PolymodError->Void;
}

/**
 * ...
 * @author 
 */
class Polymod
{
	public static var onError:PolymodError->Void = null;
	private static var defaultLibrary:AssetLibrary = null;
	private static var modLibrary:ModAssetLibrary = null;
	
	/**
	 * Initializes the chosen mod or mods.
	 * @param	params initialization parameters
	 * @return	an array of metadata entries for successfully loaded mods
	 */
	public static function init(params:PolymodParams):Array<ModMetadata>
	{
		onError = params.errorCallback;

		var modRoot = params.modRoot;
		var dirs = params.dirs;

		if (modRoot == null || dirs == null || dirs.length == 0)
		{
			if (defaultLibrary != null)
			{
				LimeAssets.registerLibrary("default", defaultLibrary);
			}
			else
			{
				return [];
			}
		}
		
		if (defaultLibrary == null)
		{
			defaultLibrary = LimeAssets.getLibrary("default");
		}
		
		clearCache();
		
		var modMeta = [];

		for(i in 0...dirs.length)
		{
			if(dirs[i] != null)
			{
				dirs[i] = modRoot + "/" + dirs[i];
				var meta:ModMetadata = getMetadata(dirs[i]);
				if(meta != null)
				{
					if(!meta.version.isCompatibleWith(params.version))
					{
						Polymod.warning("sem_ver_conflict","Mod \""+dirs[i]+"\" has incompatible version " + meta.version.toString() + ", there could be problems! (Mod API version is " + params.version.toString()+")");
					}
					modMeta.push(meta);
				}
			}
		}
		modLibrary = new ModAssetLibrary(null, defaultLibrary, dirs);
		LimeAssets.registerLibrary("default", modLibrary);

		if(Assets.exists("_polymodpack.txt"))
		{
			initModPack(params);
		}

		return modMeta;
	}

	public static function error(type:String, message:String)
	{
		if(onError != null)
		{
			onError(new PolymodError(PolymodErrorType.ERROR, type, message));
		}
	}

	public static function warning(type:String, message:String)
	{
		if(onError != null)
		{
			onError(new PolymodError(PolymodErrorType.WARNING, type, message));
		}
	}

	public static function notice(type:String, message:String)
	{
		if(onError != null)
		{
			onError(new PolymodError(PolymodErrorType.NOTICE, type, message));
		}
	}

	private static function getMetadata(dir:String):ModMetadata
	{
		#if sys
		if(FileSystem.exists(dir))
		{
			var meta:ModMetadata = null;
			
			var metaFile = dir+"/_polymod_meta.txt";
			var iconFile = dir+"/_polymod_icon.png";
			if(!FileSystem.exists(metaFile))
			{
				warning("missing_meta","Could not find mod metadata file: \""+metaFile+"\"");
			}
			else
			{
				var metaText = File.getContent(metaFile);
				meta = ModMetadata.fromJsonStr(metaText);
			}
			if(!FileSystem.exists(iconFile))
			{
				warning("missing_icon","Could not find mod icon file: \""+iconFile+"\"");
				if(meta != null)
				{
					meta.icon = BitmapData.fromFile(iconFile);
				}
			}
			return meta;
		}
		else
		{
			error("missing_mod","Could not find mod directory: \""+dir+"\"");
		}
		#end
		return null;
	}

	/**
	 * Get the asset library that Polymod uses as a fallback for assets your
	 * mod doesn't provide
	 * @return AssetLibrary
	 */
	public static function getDefaultLibrary():AssetLibrary
	{
		return defaultLibrary;
	}

	/**
	 * Get the mod asset library that Polymod sets as your default asset library
	 * @return ModAssetLibrary
	 */
	public static function getModLibrary():ModAssetLibrary
	{
		return modLibrary;
	}

	/**
	 * Provide a list of assets included in or modified by the mod(s)
	 * @param type the type of asset you want (lime.utils.AssetType)
	 * @return Array<String> a list of assets of the matching type
	 */
	public static function listModFiles(type:AssetType=null):Array<String>
	{
		if(modLibrary != null)
		{
			return modLibrary.listModFiles(type);
		}
		return [];
	}

	/***PRIVATE***/

	private static function initModPack(params:PolymodParams)
	{
		var polymodpack:String = Assets.getText("_polymodpack.txt");
		if(polymodpack != null)
		{
			var mods = polymodpack.split(",");
			if(mods == null || mods.length == 0)
			{
				return;
			}

			params.dirs = mods;
			init(params);
		}
	}
	
	private static function clearCache()
	{
		if (defaultLibrary != null)
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
	}
}

class ModMetadata
{
	public var title:String;
	public var description:String;
	public var author:String;
	public var version:SemanticVersion;
	public var license:String;
	public var license_ref:String;
	public var icon:BitmapData;

	public function new(){}

	public static function fromJsonStr(str:String)
	{
		var m = new ModMetadata();
		var json = haxe.Json.parse(str);
		m.title = JsonHelp.str(json,"title");
		m.description = JsonHelp.str(json, "description");
		m.author = JsonHelp.str(json, "author");
		var versionStr = JsonHelp.str(json, "version");
		try
		{
			m.version = SemanticVersion.fromString(versionStr);
		}
		catch(msg:Dynamic)
		{
			Polymod.error("parse_mod_version","Error parsing mod version: ("+Std.string(msg)+") _polymod_meta.txt was : " + str);
			return null;
		}
		m.license = JsonHelp.str(json, "license");
		m.license_ref = JsonHelp.str(json, "license_ref");
		return m;
	}
}

class PolymodError
{
	public var severity:PolymodErrorType;
	public var type:String;
	public var message:String;

	public function new(severity:PolymodErrorType,type:String,message:String)
	{
		this.severity = severity;
		this.type = type;
		this.message = message;
	}
}

enum PolymodErrorType
{
	NOTICE;
	WARNING;
	ERROR;
}