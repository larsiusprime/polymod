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

package polymod.fs;

#if sys
import polymod.Polymod.ModMetadata;
import polymod.util.Util;

/**
 * An implementation of IFileSystem which accesses files from the local directory.
 */
class SysFileSystem implements IFileSystem
{
	public var modRoot(default, null):String;

	public function new(modRoot:String)
	{
		this.modRoot = modRoot;
	}

	public inline function exists(path:String)
	{
		return sys.FileSystem.exists(path);
	}

	public inline function isDirectory(path:String)
		return sys.FileSystem.isDirectory(path);

	public inline function readDirectory(path:String)
		return sys.FileSystem.readDirectory(path);

	public inline function getFileContent(path:String)
	{
		if (!exists(path))
			return null;
		return sys.io.File.getContent(path);
	}

	public inline function getFileBytes(path:String)
	{
		if (!exists(path))
			return null;
		return sys.io.File.getBytes(path);
	}

	public function scanMods()
	{
		var dirs = readDirectory(modRoot);
		var l = dirs.length;
		for (i in 0...l)
		{
			var j = l - i - 1;
			var dir = dirs[j];
			var testDir = modRoot + "/" + dir;
			if (!isDirectory(testDir) || !exists(testDir))
			{
				dirs.splice(j, 1);
			}
		}
		return dirs;
	}

	public function getMetadata(modId:String)
	{
		if (exists(modId))
		{
			var meta:ModMetadata = null;

			var metaFile = Util.pathJoin(modId, PolymodConfig.modMetadataFile);
			var iconFile = Util.pathJoin(modId, PolymodConfig.modIconFile);
			var packFile = Util.pathJoin(modId, PolymodConfig.modPackFile);

			if (!exists(metaFile))
			{
				Polymod.warning(MISSING_META, "Could not find mod metadata file: \"" + metaFile + "\"");
			}
			else
			{
				var metaText = getFileContent(metaFile);
				meta = ModMetadata.fromJsonStr(metaText);
			}
			if (!exists(iconFile))
			{
				Polymod.warning(MISSING_ICON, "Could not find mod icon file: \"" + iconFile + "\"");
			}
			else
			{
				var iconBytes = getFileBytes(iconFile);
				meta.icon = iconBytes;
			}
			if (exists(packFile))
			{
				meta.isModPack = true;
				var packText = getFileContent(packFile);
				meta.modPack = @:privateAccess Polymod.getModPack(packText);
			}
			return meta;
		}
		else
		{
			Polymod.error(MISSING_MOD, "Could not find mod directory: \"" + modId + "\"");
		}
		return null;
	}

	public function readDirectoryRecursive(path:String):Array<String>
	{
		var all = _readDirectoryRecursive(path);
		for (i in 0...all.length)
		{
			var f = all[i];
			var stri = Util.uIndexOf(f, path + "/");
			if (stri == 0)
			{
				f = Util.uSubstr(f, Util.uLength(path + "/"), Util.uLength(f));
				all[i] = f;
			}
		}
		return all;
	}

	private function _readDirectoryRecursive(str:String):Array<String>
	{
		if (exists(str) && isDirectory(str))
		{
			var all = readDirectory(str);
			if (all == null)
				return [];
			var results = [];
			for (thing in all)
			{
				if (thing == null)
					continue;
				var pathToThing = Util.pathJoin(str, thing);
				if (isDirectory(pathToThing))
				{
					var subs = _readDirectoryRecursive(pathToThing);
					if (subs != null)
					{
						results = results.concat(subs);
					}
				}
				else
				{
					results.push(pathToThing);
				}
			}
			return results;
		}
		return [];
	}
}
#end
