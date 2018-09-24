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

import polymod.library.JsonHelp;
import polymod.library.ModAssetLibrary;
import polymod.library.SemanticVersion;
import polymod.library.Util.MergeRules;

typedef PolymodParams = {
	/**
	 * root directory of all mods
	 */
	modRoot:String,

	/**
	 * directory names of one or more mods, relative to modRoot
	 */
	dirs:Array<String>,

	/**
	 * semantic version of your game's Modding API (will generate errors & warnings)
	 */
	?apiVersion:String,

	/**
	 * (optional) callback for any errors generated during mod initialization
	 */
	?errorCallback:PolymodError->Void,

	/**
	 * (optional) for each mod you're loading, a corresponding semantic version pattern to enforce (will generate errors & warnings)
	 * if not provided, no version checks will be made
	 */
	?modVersions:Array<String>,

	/**
	 * (optional) rules for merging various data formats
	 */
	?mergeRules:MergeRules,

	/**
	 * (optional) list of filenames to ignore in mods
	 */
	?ignoredFiles:Array<String>
}

/**
 * ...
 * @author
 */
class PolymodCore
{
	public static var onError:PolymodError->Void = null;
	private static var defaultLibrary:AssetLibrary = null;
	private static var modLibrary:ModAssetLibrary = null;

	public static function getDefaultIgnoreList():Array<String>
	{
		return ["_polymod_meta.json","_polymod_icon.png","_polymod_pack.txt","ASSET_LICENSE.txt","CODE_LICENSE.txt","LICENSE.txt"];
	}

	/**
	 * Scan the given directory for available mods and returns their metadata entries
	 * @param modRoot root directory of all mods
	 * @param apiVersionStr (optional) enforce a modding API version -- incompatible mods will not be returned
	 * @param errorCallback (optional) callback for any errors generated during scanning
	 * @return Array<ModMetadata>
	 */
	public static function scan(modRoot:String, ?apiVersionStr:String="*.*.*", ?errorCallback:PolymodError->Void):Array<ModMetadata>
	{
		onError = errorCallback;
		var apiVersion:SemanticVersion = null;
		try
		{
			apiVersion = SemanticVersion.fromString(apiVersionStr);
		}
		catch(msg:Dynamic)
		{
			error(PARSE_API_VERSION,"Error parsing api version: ("+Std.string(msg)+")");
			return [];
		}

		var modMeta = [];

		if(!PolymodFileSystem.exists(modRoot) || !PolymodFileSystem.isDirectory(modRoot))
		{
			return modMeta;
		}
		var dirs = PolymodFileSystem.readDirectory(modRoot);
		var l = dirs.length;
		for(i in 0...l)
		{
			var j = l-i-1;
			var dir = dirs[j];
			var testDir = modRoot+"/"+dir;
			if(!PolymodFileSystem.isDirectory(testDir) || !PolymodFileSystem.exists(testDir))
			{
				dirs.splice(j,1);
			}
		}

		for(i in 0...dirs.length)
		{
			if(dirs[i] != null)
			{
				var origDir = dirs[i];
				dirs[i] = modRoot + "/" + dirs[i];
				var meta:ModMetadata = getMetadata(dirs[i]);

				if(meta != null)
				{
					meta.id = origDir;
					var apiScore = meta.apiVersion.checkCompatibility(apiVersion);
					if(apiScore < 3)
					{
						error(VERSION_CONFLICT_API, "Mod \""+origDir+"\" was built for incompatible API version " + meta.apiVersion.toString() + ", current API version is " + apiVersion.toString());
					}
					modMeta.push(meta);
				}
			}
		}

		return modMeta;
	}

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
				PolymodAssets.registerLibrary("default", defaultLibrary);
			}
			else
			{
				return [];
			}
		}

		if (defaultLibrary == null)
		{
			defaultLibrary = PolymodAssets.getLibrary("default");
		}

		clearCache();

		var apiVersion:SemanticVersion = null;
		try
		{
			var apiStr = params.apiVersion;
			if(apiStr == null || apiStr == ""){
				apiStr = "*.*.*";
			}
			apiVersion = SemanticVersion.fromString(apiStr);
		}
		catch(msg:Dynamic)
		{
			error(PARSE_API_VERSION,"Error parsing api version: ("+Std.string(msg)+")");
			return [];
		}

		var modMeta = [];
		var modVers = [];

		if(params.modVersions != null)
		{
			for(str in params.modVersions)
			{
				var semVer = null;
				try
				{
					semVer = SemanticVersion.fromString(str);
				}
				catch(msg:Dynamic)
				{
					error(PARAM_MOD_VERSION,"There was an error with one of the mod version patterns you provided: " + msg);
					semVer = SemanticVersion.fromString("*.*.*");
				}
				modVers.push(semVer);
			}
		}

		for(i in 0...dirs.length)
		{
			if(dirs[i] != null)
			{
				var origDir = dirs[i];
				dirs[i] = modRoot + "/" + dirs[i];
				var meta:ModMetadata = getMetadata(dirs[i]);

				if(meta != null)
				{
					meta.id = origDir;
					var apiScore = meta.apiVersion.checkCompatibility(apiVersion);
					if(apiScore < 3)
					{
						error(VERSION_CONFLICT_API, "Mod \""+origDir+"\" was built for incompatible API version " + meta.apiVersion.toString() + ", current API version is " + params.apiVersion.toString());
					}
					var modVer = modVers.length > i ? modVers[i] : null;
					if(modVer != null)
					{
						var score = modVer.checkCompatibility(meta.modVersion);
						if(score < 3)
						{
							error(VERSION_CONFLICT_MOD, "Mod pack wants version " + modVer.toString() + " of mod("+meta.id+"), found incompatible version " + meta.modVersion.toString() + " instead");
						}
					}
					modMeta.push(meta);
				}
			}
		}

		modLibrary = new ModAssetLibrary({
			dir:null,
			fallback:defaultLibrary,
			dirs:dirs,
			mergeRules:params.mergeRules,
			ignoredFiles:params.ignoredFiles
		});
		PolymodAssets.registerLibrary("default", modLibrary);
		/*
		if(Assets.exists("_polymod_pack.txt"))
		{
			initModPack(params);
		}
		*/

		return modMeta;
	}

	public static function error(code:PolymodErrorCode, message:String)
	{
		if(onError != null)
		{
			onError(new PolymodError(PolymodErrorType.ERROR, code, message));
		}
	}

	public static function warning(code:PolymodErrorCode, message:String)
	{
		if(onError != null)
		{
			onError(new PolymodError(PolymodErrorType.WARNING, code, message));
		}
	}

	public static function notice(code:PolymodErrorCode, message:String)
	{
		if(onError != null)
		{
			onError(new PolymodError(PolymodErrorType.NOTICE, code, message));
		}
	}

	private static function getMetadata(dir:String):ModMetadata
	{
		if(PolymodFileSystem.exists(dir))
		{
			var meta:ModMetadata = null;

			var metaFile = dir+"/_polymod_meta.json";
			var iconFile = dir+"/_polymod_icon.png";
			var packFile = dir+"/_polymod_pack.txt";
			if(!PolymodFileSystem.exists(metaFile))
			{
				warning(MISSING_META,"Could not find mod metadata file: \""+metaFile+"\"");
			}
			else
			{
				var metaText = PolymodFileSystem.getFileContent(metaFile);
				meta = ModMetadata.fromJsonStr(metaText);
			}
			if(!PolymodFileSystem.exists(iconFile))
			{
				warning(MISSING_ICON,"Could not find mod icon file: \""+iconFile+"\"");
			}
			else
			{
				// meta.icon = BitmapData.fromFile(iconFile); // TODO (DK)
			}
			if(PolymodFileSystem.exists(packFile))
			{
				meta.isModPack = true;
				var packText = PolymodFileSystem.getFileContent(packFile);
				meta.modPack = getModPack(packText);
			}
			return meta;
		}
		else
		{
			error(MISSING_MOD,"Could not find mod directory: \""+dir+"\"");
		}
		return null;
	}

	// TODO (DK) shouldn't be publicly exposed IMO?
	/**
	 * Get the asset library that Polymod uses as a fallback for assets your
	 * mod doesn't provide
	 * @return AssetLibrary
	 */
	// public static function getDefaultLibrary():AssetLibrary
	// {
	// 	return defaultLibrary;
	// }

	// TODO (DK) shouldn't be publicly exposed IMO?
	/**
	 * Get the mod asset library that Polymod sets as your default asset library
	 * @return ModAssetLibrary
	 */
	// public static function getModLibrary():ModAssetLibrary
	// {
	// 	return modLibrary;
	// }

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

	// TODO (DK)
	private static function initModPack(params:PolymodParams)
	{
		var polymodpack:String = null;//Assets.getText("_polymod_pack.txt");
		if(polymodpack != null)
		{
			var data = getModPack(polymodpack);
			var mods:Array<String> = data.mods;
			var vers:Array<String> = data.versions;

			params.dirs = mods;
			params.modVersions = vers;
			init(params);
		}
	}

	private static function getModPack(text:String):{mods:Array<String>,versions:Array<String>}
	{
		if(text != null)
		{
			var mods = text.split(",");
			if(mods == null || mods.length == 0)
			{
				return null;
			}
			var vers = [];
			for(i in 0...mods.length)
			{
				vers[i] = "*.*.*";
				if(mods[i].indexOf(":") != -1)
				{
					var arr = mods[i].split(":");
					if(arr != null && arr.length == 2)
					{
						mods[i] = arr[0];
						vers[i] = arr[1];
					}
				}
			}
			return {mods:mods,versions:vers};
		}
		return null;
	}

	private static function clearCache()
	{
		if (defaultLibrary != null)
		{
			PolymodAssets.clearCache();
		}
	}
}

class ModMetadata
{
	public var id:String;
	public var title:String;
	public var description:String;
	public var author:String;
	public var apiVersion:SemanticVersion;
	public var modVersion:SemanticVersion;
	public var license:String;
	public var licenseRef:String;
	// public var icon:BitmapData; // TODO (DK)
	public var isModPack:Bool;
	public var modPack:{mods:Array<String>,versions:Array<String>};

	public function new(){}

	public static function fromJsonStr(str:String)
	{
		var m = new ModMetadata();
		var json = haxe.Json.parse(str);
		m.title = JsonHelp.str(json,"title");
		m.description = JsonHelp.str(json, "description");
		m.author = JsonHelp.str(json, "author");
		var apiVersionStr = JsonHelp.str(json, "api_version");
		var modVersionStr = JsonHelp.str(json, "mod_version");
		try
		{
			m.apiVersion = SemanticVersion.fromString(apiVersionStr);
		}
		catch(msg:Dynamic)
		{
			PolymodCore.error(PARSE_MOD_API_VERSION,"Error parsing api version: ("+Std.string(msg)+") _polymod_meta.json was : " + str);
			return null;
		}
		try
		{
			m.modVersion = SemanticVersion.fromString(modVersionStr);
		}
		catch(msg:Dynamic)
		{
			PolymodCore.error(PARSE_MOD_VERSION,"Error parsing mod version: ("+Std.string(msg)+") _polymod_meta.json was : " + str);
			return null;
		}
		m.license = JsonHelp.str(json, "license");
		m.licenseRef = JsonHelp.str(json, "license_ref");
		return m;
	}
}

class PolymodError
{
	public var severity:PolymodErrorType;
	public var code:String;
	public var message:String;

	public function new(severity:PolymodErrorType, code:PolymodErrorCode, message:String)
	{
		this.severity = severity;
		this.code = code;
		this.message = message;
	}
}

enum PolymodErrorType
{
	NOTICE;
	WARNING;
	ERROR;
}

@:enum abstract PolymodErrorCode(String) from String to String
{
	var PARSE_MOD_VERSION:String = "parse_mod_version";
	var PARSE_MOD_API_VERSION:String = "parse_mod_api_version";
	var PARSE_API_VERSION:String = "parse_api_version";
	var MISSING_MOD:String = "missing_mod";
	var MISSING_META:String = "missing_meta";
	var MISSING_ICON:String = "missing_icon";
	var VERSION_CONFLICT_MOD:String = "version_conflict_mod";
	var VERSION_CONFLICT_API:String = "version_conflict_api";
	var PARAM_MOD_VERSION:String = "param_mod_version";
}
