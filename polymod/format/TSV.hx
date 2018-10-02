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

package polymod.format;

/**
 * A simple TSV (tab separated values) structure
 * @author Lars Doucet
 */

class TSV extends CSV
{
	/**
	 * Parses TSV formatted string into a useable data structure
	 * Endline format will be auto-detected: a single "\r\n" will make it split lines based on windows
	 * style endlines, otherwise it will attempt splitting based on unix-style "\n" endlines.
	 * @param	input tsv-formatted string
	 */
	
	public static function parse(input:String):TSV
	{
		var endline:String = "\n";
        if(input.indexOf("\r\n") != -1) endline = "\r\n";
        var lines = input.split(endline);
        var fieldLine = lines.shift();
        var fields = fieldLine.split("\t");
        var grid = [];
        for(line in lines)
        {
        	while (line.charAt(line.length - 1) == "\t")		//trim trailing tabs
			{
				line = line.substr(0, line.length - 1);
			}
        	var cells = line.split("\t");
			grid.push(cells);
        }
    	var tsv = new TSV();
    	tsv.fields = fields;
    	tsv.grid = grid;
    	return tsv;
	}
	
	function new()
	{
		super();
	}
}