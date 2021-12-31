package polymod;

import polymod.util.SemanticVersion;
import polymod.util.DefineUtil;

/**
 * This class provides several constants used throughout the library.
 * You can define these values in your `hxml` or `project.xml` using haxe defines,
 * or just set them in your code before you load any classes that implement HScriptable.
 */
class PolymodConfig
{
	/**
	 * If true, additional debug output will be provided by Polymod.
	 * 
	 * Set this option by setting the `POLYMOD_DEBUG` Haxe define at compile time,
	 * or by setting this value in your code.
	 * 
	 * @default `false`
	 */
	public static var debug(get, default):Null<Bool>;

	static function get_debug()
	{
		// If the value is null, retrieve the value as a Haxe define.
		if (debug == null)
			debug = DefineUtil.getDefineBool('POLYMOD_DEBUG', false);
		return debug;
	}

	/**
	 * The base path from which scripts should be accessed.
	 * 
	 * Set this option by setting the `POLYMOD_ROOT_PATH` Haxe define at compile time,
	 * or by setting this value in your code.
	 * 
	 * @default `data/`
	 */
	public static var rootPath(get, default):String;

	static function get_rootPath()
	{
		// If the value is null, retrieve the value as a Haxe define.
		if (rootPath == null)
			rootPath = DefineUtil.getDefineString('POLYMOD_ROOT_PATH', 'data/');
		return rootPath;
	}

	/**
	 * Whether script paths should, by default, be relative to the class's path or the root path.
	 * For example, if true, `demo.Simulation#updateBee` will use `data/demo/Simulation/updateBee.txt`
	 * If false, `demo.Simulation#updateBee` will use `data/updateBee.txt`
	 * 
	 * Set this option by setting the `POLYMOD_USE_NAMESPACE` Haxe define at compile time,
	 * or by setting this value in your code.
	 * 
	 * @default `true`
	 */
	public static var useNamespaceInPaths(get, default):Null<Bool>;

	static function get_useNamespaceInPaths()
	{
		// If the value is null, retrieve the value as a Haxe define.
		if (useNamespaceInPaths == null)
			useNamespaceInPaths = DefineUtil.getDefineBool('POLYMOD_USE_NAMESPACE', true);
		return useNamespaceInPaths;
	}

	/**
	 * The file extension for script files.
	 * 
	 * Set this option by setting the `POLYMOD_SCRIPT_EXT` Haxe define at compile time,
	 * or by setting this value in your code.
	 * 
	 * @default `.txt`
	 */
	public static var scriptExt(get, default):String;

	static function get_scriptExt()
	{
		// If the value is null, retrieve the value as a Haxe define.
		if (scriptExt == null)
			scriptExt = DefineUtil.getDefineString('POLYMOD_SCRIPT_EXT', '.txt');
		return scriptExt;
	}

	/**
	 * The asset library to use for loading scripts.
	 * Only relevant for Lime/OpenFL projects which use multiple asset libraries.
	 * 
	 * Set this option by setting the `POLYMOD_SCRIPT_LIBRARY` Haxe define at compile time,
	 * or by setting this value in your code.
	 * 
	 * @default `default`
	 */
	public static var scriptLibrary(get, default):String;

	static function get_scriptLibrary()
	{
		// If the value is null, retrieve the value as a Haxe define.
		if (scriptLibrary == null)
			scriptLibrary = DefineUtil.getDefineString('POLYMOD_SCRIPT_LIBRARY', 'default');
		return scriptLibrary;
	}

	/**
	 * The directory from which to read data append files.
	 * 
	 * Set this option by setting the `POLYMOD_APPEND_FOLDER` Haxe define at compile time,
	 * or by setting this value in your code.
	 * 
	 * @default `_append`
	 */
	public static var appendFolder(get, default):String;

	static function get_appendFolder()
	{
		// If the value is null, retrieve the value as a Haxe define.
		if (appendFolder == null)
			appendFolder = DefineUtil.getDefineString('POLYMOD_APPEND_FOLDER', '_append');
		return appendFolder;
	}

	/**
	 * Determines how sensitive Semantic Versioning is to version differences.
	 * 
	 * The possible values are:
	 * - `NONE`: Any version difference will be ignored. All mods will be loaded.
	 * - `MATCH_MAJOR`: The major version must match for the mod to be loaded.
	 * - `MATCH_MINOR`: The major and minor versions must match for the mod to be loaded.
	 * - `MATCH_PATCH`: The major, minor and patch versions must match for the mod to be loaded.
	 * 
	 * Set this option by setting the `POLYMOD_API_VERSION_MATCH` Haxe define at compile time,
	 * or by setting this value in your code.
	 * 
	 * @default `MATCH_PATCH`
	 */
	public static var apiVersionMatch(get, default):Null<SemanticVersionScore> = null;

	static function get_apiVersionMatch()
	{
		// If the value is null, retrieve the value as a Haxe define.
		if (apiVersionMatch == null)
			apiVersionMatch = SemanticVersionScore.fromString(DefineUtil.getDefineString('POLYMOD_API_VERSION_MATCH', 'MATCH_PATCH'));
		return apiVersionMatch;
	}

	/**
	 * Determines which HScript interpreter to use. The HScript-EX interpreter is experimental but boasts support for custom classes.
	 * 
	 * If `false`, the default HScript interpreter will be used.
	 * If `true`, the HScript-EX interpreter will be used.
	 * 
	 * @default `false`
	 */
	public static var useHScriptEX(get, default):Null<Bool> = null;

	static function get_useHScriptEX()
	{
		// If the value is null, retrieve the value as a Haxe define.
		if (useHScriptEX == null)
			useHScriptEX = DefineUtil.getDefineBool('POLYMOD_USE_HSCRIPTEX', true);
		return useHScriptEX;
	}

	/**
	 * The directory from which to read data merge files.
	 * 
	 * Set this option by setting the `POLYMOD_MERGE_FOLDER` Haxe define at compile time,
	 * or by setting this value in your code.
	 * 
	 * @default `_merge`
	 */
	public static var mergeFolder(get, default):String;

	static function get_mergeFolder()
	{
		// If the value is null, retrieve the value as a Haxe define.
		if (mergeFolder == null)
			mergeFolder = DefineUtil.getDefineString('POLYMOD_MERGE_FOLDER', '_merge');
		return mergeFolder;
	}

	/**
	 * The file where Polymod checks for modpack definitions.
	 * 
	 * Set this option by setting the `POLYMOD_MOD_PACK_FILE` Haxe define at compile time,
	 * or by setting this value in your code.
	 * 
	 * @default `_polymod_pack.txt`
	 */
	public static var modPackFile(get, default):String;

	static function get_modPackFile()
	{
		// If the value is null, retrieve the value as a Haxe define.
		if (modPackFile == null)
			modPackFile = DefineUtil.getDefineString('POLYMOD_MOD_PACK_FILE', '_polymod_pack.txt');
		return modPackFile;
	}

	/**
	 * The file where Polymod checks for mod metadata.
	 * 
	 * Set this option by setting the `POLYMOD_MOD_METADATA_FILE` Haxe define at compile time,
	 * or by setting this value in your code.
	 * 
	 * @default `_polymod_meta.json`
	 */
	public static var modMetadataFile(get, default):String;

	static function get_modMetadataFile()
	{
		// If the value is null, retrieve the value as a Haxe define.
		if (modMetadataFile == null)
			modMetadataFile = DefineUtil.getDefineString('POLYMOD_MOD_METADATA_FILE', '_polymod_meta.json');
		return modMetadataFile;
	}

	/**
	 * The file where Polymod checks for mod metadata.
	 * 
	 * Set this option by setting the `POLYMOD_MOD_ICON_FILE` Haxe define at compile time,
	 * or by setting this value in your code.
	 * 
	 * @default `_polymod_icon.png`
	 */
	public static var modIconFile(get, default):String;

	static function get_modIconFile()
	{
		// If the value is null, retrieve the value as a Haxe define.
		if (modIconFile == null)
			modIconFile = DefineUtil.getDefineString('POLYMOD_MOD_ICON_FILE', '_polymod_icon.png');
		return modIconFile;
	}

	/**
	 * The files which Polymod should ignore when loading mods.
	 * Defaults to the list of license files.
	 * 
	 * Set this option by setting the `POLYMOD_MOD_IGNORE` Haxe define at compile time,
	 * or by setting this value in your code.
	 * 
	 * @default `LICENSE.txt,ASSET_LICENSE.txt,CODE_LICENSE.txt`
	 */
	public static var modIgnoreFiles(get, default):Array<String>;

	static function get_modIgnoreFiles()
	{
		// If the value is null, retrieve the value as a Haxe define.
		if (modIgnoreFiles == null)
			modIgnoreFiles = DefineUtil.getDefineStringArray('POLYMOD_MOD_IGNORE', ['LICENSE.txt', 'ASSET_LICENSE.txt', 'CODE_LICENSE.txt']);
		return modIgnoreFiles;
	}
}
