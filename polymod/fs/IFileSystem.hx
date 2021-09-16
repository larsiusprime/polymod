/**
 * Copyright (c) 2021 Level Up Labs, LLC
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

import polymod.Polymod.ModMetadata;
import haxe.io.Bytes;

interface IFileSystem
{
	/**
	 * Returns whether the file or directory at the given path exists.
	 * @param path The path to check.
	 * @return Whether there is a file or directory there.
	 */
	public function exists(path:String):Bool;

	/**
	 * Returns whether the provided path is a directory.
	 * @param path The path to check.
	 * @return Whether the path is a directory.
	 */
	public function isDirectory(path:String):Bool;

	/**
	 * Returns a list of files and folders contained within the provided directory path.
	 * Does not return files in subfolders, use readDirectoryRecursive for that.
	 * @param path The path to check.
	 * @return An array of file paths and folder paths.
	 */
	public function readDirectory(path:String):Array<String>;

	/**
	 * Returns a list of files contained within the provided directory path.
	 * Checks all subfolders recursively. Returns only files.
	 * @param path The path to check.
	 * @return An array of file paths.
	 */
	public function readDirectoryRecursive(path:String):Array<String>;

	/**
	 * Returns the content of a given file as a string.
	 * Returns null if the file can't be found.
	 * @param path The file to read.
	 * @return The text content of the file.
	 */
	public function getFileContent(path:String):Null<String>;

	/**
	 * Returns the content of a given file as Bytes.
	 * Returns null if the file can't be found.
	 * @param path The file to read.
	 * @return The byte content of the file.
	 */
	public function getFileBytes(path:String):Null<Bytes>;

	/**
	 * Provide a list of valid mods for this file system to load.
	 * @return An array of mod IDs.
	 */
	public function scanMods():Array<String>;

	/**
	 * Provides the metadata for a given mod. Returns null if the mod does not exist.
	 * @param modId The ID of the mod.
	 * @return The mod metadata.
	 */
	public function getMetadata(modId:String):Null<ModMetadata>;
}
