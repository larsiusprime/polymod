/**
 * Copyright (c) 2013 Level Up Labs, LLC
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

package polymod.library;

/**
 * A simple TSV (tab separated values) structure
 * @author Lars Doucet
 */

class TSV extends CSV
{

	/**
	 * Parses TSV formatted string into a useable data structure
	 * @param	input tsv-formatted string
	 */
	
	public function new(input:String) 
	{
		super(input, "\t", false);
	}
	
	private override function processRows(rows:Array<String>):Void
	{
		for (i in 0...rows.length)
		{
			var row:String = rows[i];
			while (row.charAt(row.length - 1) == "\t")		//trim trailing tabs
			{
				row = row.substr(0, row.length - 1);
			}
			processCells(getCells(row), i);
		}
	}
	
	private override function getCells(row:String):Array<String>
	{
		return row.split("\t");		//Get all the cells in a much simpler way
	}
}