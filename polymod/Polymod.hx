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

import haxe.Json;
import haxe.io.Bytes;
import polymod.Polymod.ModMetadata;
import polymod.fs.PolymodFileSystem;
import polymod.util.SemanticVersion;
import polymod.util.Util;
import polymod.format.JsonHelp;
import polymod.format.ParseRules;
import polymod.backends.IBackend;
import polymod.backends.PolymodAssets;
import polymod.backends.PolymodAssetLibrary;
import polymod.backends.PolymodAssets.PolymodAssetType;

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
     * (optional) the Haxe framework you're using (OpenFL, HEAPS, Kha, NME, etc..). If not provided, Polymod will attempt to determine this automatically
     */
    ?framework:Framework,
    
    /**
     * (optional) any specific settings for your particular Framework
     */
     ?frameworkParams:FrameworkParams,

    /**
     * (optional) semantic version of your game's Modding API (will generate errors & warnings)
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
     * (optional) parsing rules for various data formats
     */
    ?parseRules:ParseRules,

    /**
     * (optional) list of filenames to ignore in mods
     */
    ?ignoredFiles:Array<String>,

    /**
     * (optional) your own custom backend for handling assets
     */
    ?customBackend:Class<IBackend>,

    /**
     * (optional) a map that tells Polymod which assets are of which type. This ensures e.g. text files with unfamiliar extensions are handled properly.
     */
    ?extensionMap:Map<String,PolymodAssetType>,
}

/**
 * Any framework-specific settings
 * Right now this is only used to specify asset library paths for the Lime/OpenFL framework but we'll add more framework-specific settings here as neeeded
 */
typedef FrameworkParams = {

     /**
      * (optional) if you're using Lime/OpenFL AND you're using custom or non-default asset libraries, then you must provide a key=>value store mapping the name of each asset library to a path prefix in your mod structure
      */
     ?assetLibraryPaths:Map<String,String>
}

enum Framework
{
    NME;
    LIME;
    OPENFL;
    HEAPS;
    KHA;
    CUSTOM;
    UNKNOWN;
}

/**
 * ...
 * @author
 */
class Polymod
{
    public static var onError:PolymodError->Void = null;
    private static var library:PolymodAssetLibrary = null;
    
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
        var apiVersion:SemanticVersion = null;
        try
        {
            var apiStr = params.apiVersion;
            if(apiStr == null || apiStr == "")
            {
                apiStr = "*.*.*";
            }
            apiVersion = SemanticVersion.fromString(apiStr);
        }
        catch(msg:Dynamic)
        {
            error(PARSE_API_VERSION,"Error parsing api version: ("+Std.string(msg)+")", INIT);
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
                    error(PARAM_MOD_VERSION,"There was an error with one of the mod version patterns you provided: " + msg, INIT);
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
                dirs[i] = Util.pathJoin(modRoot,dirs[i]);
                var meta:ModMetadata = getMetadata(dirs[i]);

                if(meta != null)
                {
                    meta.id = origDir;
                    var apiScore = meta.apiVersion.checkCompatibility(apiVersion);
                    if(apiScore < 3)
                    {
                        error(VERSION_CONFLICT_API, "Mod \""+origDir+"\" was built for incompatible API version " + meta.apiVersion.toString() + ", current API version is " + params.apiVersion.toString(), INIT);
                    }
					else
					{
						if (apiVersion.major == 0)
						{
							//if we're in pre-release
							if (apiVersion.minor != meta.apiVersion.minor)
							{
								warning(
									VERSION_PRERELEASE_API, 
									"Modding API is in pre-release, some things might have changed!\n" + "Mod \"" + origDir + "\" was built for API version " + meta.apiVersion.toString() + ", current API version is " + apiVersion.toString(),
									INIT
								);
							}
						}
					}
					var modVer = modVers.length > i ? modVers[i] : null;
                    if(modVer != null)
                    {
                        var score = modVer.checkCompatibility(meta.modVersion);
                        if(score < 3)
                        {
                            error(VERSION_CONFLICT_MOD, "Mod pack wants version " + modVer.toString() + " of mod("+meta.id+"), found incompatible version " + meta.modVersion.toString() + " instead", INIT);
                        }
                    }
                    modMeta.push(meta);
                }
            }
        }

        library = PolymodAssets.init({
            framework:params.framework,
            dirs:dirs,
            parseRules:params.parseRules,
            ignoredFiles:params.ignoredFiles,
            customBackend:params.customBackend,
            extensionMap:params.extensionMap,
            frameworkParams:params.frameworkParams
        });

        if (library == null) {
          return null;
        }

        if(PolymodAssets.exists(("_polymod_pack.txt")))
        {
            initModPack(params);
        }

        return modMeta;
    }
    
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
            error(PARSE_API_VERSION,"Error parsing api version: ("+Std.string(msg)+")", SCAN);
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
                        error(
							VERSION_CONFLICT_API,
							"Mod \"" + origDir + "\" was built for incompatible API version " + meta.apiVersion.toString() + ", current API version is " + apiVersion.toString(),
							SCAN
						);
                    }
					else
					{
						if (apiVersion.major == 0)
						{
							//if we're in pre-release
							if (apiVersion.minor != meta.apiVersion.minor)
							{
								warning(
									VERSION_PRERELEASE_API, 
									"Modding API is in pre-release, some things might have changed!\n" + "Mod \"" + origDir + "\" was built for API version " + meta.apiVersion.toString() + ", current API version is " + apiVersion.toString(),
									SCAN
								);
							}
						}
					}
                    modMeta.push(meta);
                }
            }
        }

        return modMeta;
    }

    public static function error(code:PolymodErrorCode, message:String, origin:PolymodErrorOrigin=UNKNOWN)
    {
        if(onError != null)
        {
            onError(new PolymodError(PolymodErrorType.ERROR, code, message, origin));
        }
    }

    public static function warning(code:PolymodErrorCode, message:String, origin:PolymodErrorOrigin=UNKNOWN)
    {
        if(onError != null)
        {
            onError(new PolymodError(PolymodErrorType.WARNING, code, message, origin));
        }
    }

    public static function notice(code:PolymodErrorCode, message:String, origin:PolymodErrorOrigin=UNKNOWN)
    {
        if(onError != null)
        {
            onError(new PolymodError(PolymodErrorType.NOTICE, code, message, origin));
        }
    }

    private static function getFileSystem()
    {
        #if sys
        return new polymod.fs.SysFileSystem();
        #end
        return null;
    }

    private static function getMetadata(dir:String):ModMetadata
    {
        if(PolymodFileSystem.exists(dir))
        {
            var meta:ModMetadata = null;

            var metaFile = Util.pathJoin(dir,"_polymod_meta.json");
            var iconFile = Util.pathJoin(dir,"_polymod_icon.png");
            var packFile = Util.pathJoin(dir,"_polymod_pack.txt");
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
                var iconBytes = PolymodFileSystem.getFileBytes(iconFile);
                meta.icon = iconBytes;
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

    /**
     * Provide a list of assets included in or modified by the mod(s)
     * @param type the type of asset you want (lime.utils.PolymodAssetType)
     * @return Array<String> a list of assets of the matching type
     */
    public static function listModFiles(type:PolymodAssetType=null):Array<String>
    {
        if(library != null)
        {
            return library.listModFiles(type);
        }
        return [];
    }

    /***PRIVATE***/

    private static function initModPack(params:PolymodParams)
    {
        var polymodpack:String = PolymodAssets.getText("_polymod_pack.txt");
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
    public var icon:Bytes;
    public var isModPack:Bool;
    public var modPack:{mods:Array<String>, versions:Array<String>};
    public var metaData:Map<String,String>;

    public function new(){}

    public function toJsonStr():String
    {
        var json = {};
		Reflect.setField(json, "title", title);
		Reflect.setField(json, "description", description);
		Reflect.setField(json, "author", author);
		Reflect.setField(json, "api_version", apiVersion.toString());
		Reflect.setField(json, "mod_version", modVersion.toString());
		Reflect.setField(json, "license", license);
		Reflect.setField(json, "license_ref", licenseRef);
		var meta = {};
		for (key in metaData.keys()){
			Reflect.setField(meta, key, metaData.get(key));
		}
		Reflect.setField(json, "metadata", meta);
		return Json.stringify(json, null, "    ");
    }

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
            Polymod.error(PARSE_MOD_API_VERSION,"Error parsing api version: ("+Std.string(msg)+") _polymod_meta.json was : " + str);
            return null;
        }
        try
        {
            m.modVersion = SemanticVersion.fromString(modVersionStr);
        }
        catch(msg:Dynamic)
        {
            Polymod.error(PARSE_MOD_VERSION,"Error parsing mod version: ("+Std.string(msg)+") _polymod_meta.json was : " + str);
            return null;
        }
        m.license = JsonHelp.str(json, "license");
        m.licenseRef = JsonHelp.str(json, "license_ref");
        m.metaData = JsonHelp.mapStr(json, "metadata");
        return m;
    }
}

class PolymodError
{
    public var severity:PolymodErrorType;
    public var code:String;
    public var message:String;
	public var origin:PolymodErrorOrigin;

    public function new(severity:PolymodErrorType, code:PolymodErrorCode, message:String, origin:PolymodErrorOrigin)
    {
        this.severity = severity;
        this.code = code;
        this.message = message;
		this.origin = origin;
    }
}

@:enum abstract PolymodErrorOrigin(String) from String to String
{
	var SCAN:String = "scan";
	var INIT:String = "init";
	var UNKNOWN:String = "unknown";
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
    var VERSION_PRERELEASE_API:String = "version_prerelease_api";
    var PARAM_MOD_VERSION:String = "param_mod_version";
    var FRAMEWORK_AUTODETECT:String = "framework_autodetect";
    var FRAMEWORK_INIT:String = "framework_init";
    var UNDEFINED_CUSTOM_BACKEND:String = "undefined_custom_backend";
    var FAILED_CREATE_BACKEND:String = "failed_create_backend";
    var MERGE:String = "merge_error";
    var APPEND:String = "append_error";
    var LIME_MISSING_ASSET_LIBRARY_INFO = "lime_missing_asset_library_info";
    var LIME_MISSING_ASSET_LIBRARY_REFERENCE = "lime_missing_asset_library_reference";
}
