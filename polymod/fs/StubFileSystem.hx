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

/**
 * This stub file system returns false for all requests.
 * This is used when the actual file system can't be accessed.
 */
class StubFileSystem implements IFileSystem
{
	public function new()
	{
	}

	public inline function exists(path:String)
		return false;

	public inline function isDirectory(path:String)
		return false;

	public inline function readDirectory(path:String):Array<String>
		return [];

	public inline function getFileContent(path:String)
		return null;

	public inline function getFileBytes(path:String)
		return null;

	public inline function readDirectoryRecursive(path:String)
		return [];

	public inline function scanMods()
		return [];

	public inline function getMetadata(modId:String)
		return null;
}
