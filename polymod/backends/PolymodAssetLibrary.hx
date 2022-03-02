package polymod.backends;

import polymod.hscript.PolymodScriptClass;
import haxe.io.Bytes;
import polymod.backends.IBackend;
import polymod.backends.PolymodAssets.PolymodAssetType;
import polymod.format.ParseRules;
import polymod.fs.PolymodFileSystem.IFileSystem;
import polymod.util.Util;
#if firetongue
import firetongue.FireTongue;
#end

typedef PolymodAssetLibraryParams =
{
	/**
	 * the backend used to fetch your default assets
	 */
	backend:IBackend,

	/**
	 * paths to each mod's root directories.
	 * This takes precedence over the 'Dir' parameter and the order matters -- mod files will load from first to last, with last taking precedence
	 */
	dirs:Array<String>,

	/**
	 * the file system used to fetch your mod assets from storage
	 */
	fileSystem:IFileSystem,

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
	?extensionMap:Map<String, PolymodAssetType>,
	/**
	 * (optional) if your assets folder is not named `assets/`, you can specify the proper name here
	 * This prevents some bugs when calling `Assets.list()`, among other things.
	 */
	?assetPrefix:String,

	/**
	 * (optional) a FireTongue instance for Polymod to hook into for localization support
	 */
	#if firetongue
	?firetongue:FireTongue,
	#end
}

class PolymodAssetLibrary
{
	public var backend(default, null):IBackend;
	public var fileSystem(default, null):IFileSystem;

	public var type(default, null):Map<String, PolymodAssetType>;

	public var assetPrefix(default, null):String = "assets/";
	public var dirs:Array<String> = null;
	public var ignoredFiles:Array<String> = null;

	private var parseRules:ParseRules = null;
	private var extensions:Map<String, PolymodAssetType>;

	public function new(params:PolymodAssetLibraryParams)
	{
		backend = params.backend;
		fileSystem = params.fileSystem;
		backend.polymodLibrary = this;
		dirs = params.dirs;
		parseRules = params.parseRules;
		ignoredFiles = params.ignoredFiles != null ? params.ignoredFiles.copy() : [];
		extensions = params.extensionMap;
		if (params.assetPrefix != null)
			assetPrefix = params.assetPrefix;

		#if firetongue
		tongue = params.firetongue;
		if (tongue != null)
		{
			// Call when we build the asset library then again each time we change locale.
			onFireTongueLoad();
			tongue.addFinishedCallback(onFireTongueLoad);
		}
		#end

		backend.clearCache();
		init();
	}

	#if firetongue
	private var tongue:FireTongue = null;

	/**
	 * The directory where all the FireTongue locales are stored.
	 */
	public var rawTongueDirectory(default, null):String = null;

	/**
	 * The directory where the current locale's FireTongue files are stored.
	 */
	public var localePrefix(default, null):String = null;

	/**
	 * The directory where the current locale's FireTongue localized assets are stored.
	 * 
	 * Prefix asset paths with this string to get a localized version of the asset.
	 */
	public var localeAssetPrefix(default, null):String = null;

	/**
	 * Do basic initialization based on the FireTongue instance
	 * Must be redone if the locale changes
	 */
	function onFireTongueLoad()
	{
		if (tongue == null)
			return;

		rawTongueDirectory = tongue.directory;
		localePrefix = Util.pathJoin(rawTongueDirectory, tongue.locale);
		localeAssetPrefix = Util.pathJoin(localePrefix, assetPrefix);
	}
	#end

	public function destroy()
	{
		if (backend != null)
		{
			backend.destroy();
		}
		PolymodScriptClass.clearScriptClasses();
		polymod.hscript.HScriptable.ScriptRunner.clearScripts();
	}

	public function mergeAndAppendText(id:String, modText:String):String
	{
		modText = Util.mergeAndAppendText(modText, id, dirs, getTextDirectly, fileSystem, parseRules);
		return modText;
	}

	public function getExtensionType(ext:String):PolymodAssetType
	{
		ext = ext.toLowerCase();
		if (extensions.exists(ext) == false)
			return BYTES;
		return extensions.get(ext);
	}

	/**
	 * Get text without consideration of any modifications
	 * @param	id
	 * @param	theDir
	 * @return
	 */
	public function getTextDirectly(id:String, directory:String = ''):String
	{
		var bytes = null;
		if (checkDirectly(id, directory))
		{
			bytes = fileSystem.getFileBytes(file(id, directory));
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
			return bytes.getString(0, bytes.length);
		}
		return null;
	}

	public function exists(id:String):Bool
	{
		return backend.exists(id);
	}

	public function getText(id:String):String
	{
		return backend.getText(id);
	}

	public function getBytes(id:String):Bytes
	{
		return backend.getBytes(id);
	}

	public function getPath(id:String):String
	{
		return backend.getPath(id);
	}

	public function clearCache()
	{
		backend.clearCache();
	}

	public function list(type:PolymodAssetType = null):Array<String>
	{
		return backend.list(type);
	}

	public function listModFiles(type:PolymodAssetType = null):Array<String>
	{
		var items = [];

		for (id in this.type.keys())
		{
			if (id.indexOf('_append') == 0 || id.indexOf('_merge') == 0)
				continue;
			if (type == null || type == BYTES || check(id, type))
			{
				items.push(id);
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
	public function check(id:String, type:PolymodAssetType = null)
	{
		var exists = _checkExists(id);
		if (exists && type != null && type != PolymodAssetType.BYTES)
		{
			var otherType = this.type.get(id);
			exists = (otherType == type || otherType == PolymodAssetType.BYTES || otherType == null || otherType == '');
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

	public function checkDirectly(id:String, dir:String = ''):Bool
	{
		id = stripAssetsPrefix(id);
		if (dir == null || dir == '')
		{
			return fileSystem.exists(id);
		}
		else
		{
			var thePath = Util.uCombine([dir, Util.sl(), id]);
			if (fileSystem.exists(thePath))
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
	public function file(id:String, theDir:String = ''):String
	{
		var idStripped = stripAssetsPrefix(id);
		if (theDir != '')
		{
			return Util.pathJoin(theDir, idStripped);
		}

		var result = '';
		var resultLocalized = false;
		for (modDir in dirs)
		{
			#if firetongue
			if (localeAssetPrefix != null)
			{
				var localePath = Util.pathJoin(modDir, Util.pathJoin(localeAssetPrefix, idStripped));
				if (fileSystem.exists(localePath))
				{
					result = localePath;
					resultLocalized = true;
				}
			}
			// Else, FireTongue not enabled.
			#end

			// If we have a localized result, any unlocalized result will be ignored
			if (!resultLocalized)
			{
				var filePath = Util.pathJoin(modDir, idStripped);
				if (fileSystem.exists(filePath))
					result = filePath;
			}
		}
		return result;
	}

	/**
	 * Get the filename of the given asset id,
	 * with the given locale prefix prepended.
	 * (will ignore all installed mods)
	 */
	public function fileLocale(id:String):String
	{
		#if firetongue
		if (localeAssetPrefix != null)
		{
			var idStripped = stripAssetsPrefix(id);
			return Util.pathJoin(localeAssetPrefix, idStripped);
		}
		// Else, Firetongue is not enabled.
		#end
		// Else, Firetongue is not installed.
		return null;
	}

	private function _checkExists(id:String):Bool
	{
		if (ignoredFiles.length > 0 && ignoredFiles.indexOf(id) != -1)
			return false;
		id = stripAssetsPrefix(id);
		for (d in dirs)
		{
			#if firetongue
			if (localeAssetPrefix != null)
			{
				var localePath = Util.pathJoin(d, Util.pathJoin(localeAssetPrefix, id));
				if (fileSystem.exists(localePath))
					return true;
			}
			// Else, FireTongue not enabled.
			#end
			var filePath = Util.pathJoin(d, id);
			if (fileSystem.exists(filePath))
				return true;
		}
		// The loop didn't find it.
		return false;
	}

	private function init()
	{
		type = new Map<String, PolymodAssetType>();
		initExtensions();
		if (parseRules == null)
			parseRules = ParseRules.getDefault();
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
		extensions = new Map<String, PolymodAssetType>();
		_extensionSet('mp3', AUDIO_GENERIC);
		_extensionSet('ogg', AUDIO_GENERIC);
		_extensionSet('wav', AUDIO_GENERIC);
		_extensionSet('jpg', IMAGE);
		_extensionSet('png', IMAGE);
		_extensionSet('gif', IMAGE);
		_extensionSet('tga', IMAGE);
		_extensionSet('bmp', IMAGE);
		_extensionSet('tif', IMAGE);
		_extensionSet('tiff', IMAGE);
		_extensionSet('txt', TEXT);
		_extensionSet('xml', TEXT);
		_extensionSet('json', TEXT);
		_extensionSet('csv', TEXT);
		_extensionSet('tsv', TEXT);
		_extensionSet('mpf', TEXT);
		_extensionSet('tsx', TEXT);
		_extensionSet('tmx', TEXT);
		_extensionSet('vdf', TEXT);
		_extensionSet('ttf', FONT);
		_extensionSet('otf', FONT);
		_extensionSet('webm', VIDEO);
		_extensionSet('mp4', VIDEO);
		_extensionSet('mov', VIDEO);
		_extensionSet('avi', VIDEO);
		_extensionSet('mkv', VIDEO);
	}

	private function _extensionSet(str:String, type:PolymodAssetType)
	{
		if (extensions.exists(str) == false)
		{
			extensions.set(str, type);
		}
	}

	private function initMod(d:String):Void
	{
		Polymod.notice(MOD_LOAD_PREPARE, 'Preparing to load mod $d');
		if (d == null)
			return;

		var all:Array<String> = null;

		if (d == '' || d == null)
		{
			all = [];
		}

		try
		{
			if (fileSystem.exists(d))
			{
				all = fileSystem.readDirectoryRecursive(d);
			}
			else
			{
				all = [];
			}
		}
		catch (msg:Dynamic)
		{
			Polymod.error(MOD_LOAD_FAILED, 'Failed to load mod $d : $msg');
			throw('ModAssetLibrary._initMod("$d") failed: $msg');
		}
		for (f in all)
		{
			var doti = Util.uLastIndexOf(f, '.');
			var ext:String = doti != -1 ? f.substring(doti + 1) : '';
			ext = ext.toLowerCase();
			var assetType = getExtensionType(ext);
			type.set(f, assetType);
		}
		Polymod.notice(MOD_LOAD_DONE, 'Done loading mod $d');
	}

	/**
	 * Strip the `assets/` prefix from a file path, if it is present.
	 * If your app uses a different asset path prefix, you can override this with the `assetPrefix` parameter.
	 * 
	 * @param id The path to strip.
	 * @return The modified path
	 */
	public function stripAssetsPrefix(id:String):String
	{
		if (Util.uIndexOf(id, assetPrefix) == 0)
		{
			id = Util.uSubstring(id, assetPrefix.length);
		}
		return id;
	}

	/**
	 * Add the `assets/` prefix to a file path, if it isn't present.
	 * If your app uses a different asset path prefix, you can override this with the `assetPrefix` parameter.
	 * 
	 * @param id The path to prepend
	 * @return The modified path
	 */
	public function prependAssetsPrefix(id:String):String
	{
		if (Util.uIndexOf(id, assetPrefix) == 0)
		{
			return id;
		}
		return '$assetPrefix$id';
	}
}
