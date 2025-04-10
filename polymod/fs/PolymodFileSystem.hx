package polymod.fs;

import thx.semver.VersionRule;
import haxe.io.Bytes;
import polymod.Polymod.ModMetadata;

/**
 * Provides factory and utility functions for instantiating an IFileSystem.
 */
class PolymodFileSystem
{
	/**
	 * Constructs a new PolymodFileSystem.
	 		* @param cls An input file system. Might be an IFileSystem or a Class<IFileSystem>.
	 */
	public static function makeFileSystem(cls:Dynamic = null, params:PolymodFileSystemParams):IFileSystem
	{
		if (cls == null)
		{
			// No IFileSystem provided, choose one to use as default.
			return _detectFileSystem(params);
		}
		else if (Std.isOfType(cls, IFileSystem))
		{
			// This is an IFileSystem object, no need to instantiate.
			return cls;
		}
		else if (Std.isOfType(cls, Class))
		{
			// This is an IFileSystem class, instantiate it with the parameters.
			return cast Type.createInstance(cls, [params]);
		}
		else
		{
			Polymod.error(BAD_CUSTOM_FILESYSTEM, "Passed an unknown type for a custom filesystem. Reverting to default...");
			return makeFileSystem(null, params);
		}
	}

	/**
	 * Determine which PolymodFileSystem to create based on the current platform.
	 */
	static function _detectFileSystem(params:PolymodFileSystemParams)
	{
		#if sys
		// Sys/native file system.
		return new polymod.fs.SysFileSystem(params);
		#elseif nodefs
		// Node file system.
		return new polymod.fs.NodeFileSystem(params);
		#else
		// No compatible file system.
		// If you're on HTML5, you should use MemoryFileSystem or ZipFileSystem.
		return new polymod.fs.StubFileSystem(params);
		#end
	}
}

/**
 * A set of parameters used to initialize the Polymod file system.
 */
typedef PolymodFileSystemParams =
{
	/**
	 * The root directory which Polymod should read mods from.
	 * May not be applicable for file systems which dicatate the directory, or use no directory.
	 */
	?modRoot:String,
};
