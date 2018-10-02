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

package polymod.format;

import polymod.Polymod;
import polymod.Polymod.PolymodError;
import polymod.Polymod.PolymodErrorType;
import polymod.fs.PolymodFileSystem;
import polymod.util.CSV.CSVParseFormat;

#if unifill
import unifill.Unifill;
#end

import haxe.Utf8;

class ParseRules
{
    private var formats:Map<String, IParseFormat>;

    public function new()
    {
        formats = new Map<String, IParseFormat>();
    }

    public function addType(extension:String, type:TextType)
    {
        var format = switch(type)
        {
            case CSV: new CSVParseFormat(",",true);
            case TSV: new TSVParseFormat();
            case XML: new XMLParseFormat();
            case JSON: new JSONParseFormat();
            case LINES: new LinesParseFormat();
            case PLAINTEXT: new PlainTextParseFormat();
            default: new PlainTextParseFormat();
        }
        formats.set(extension, format);
    }

    public function addFormat(extension:String, format:IParseFormat)
    {
        formats.set(extension, format);
    }

    public static function getDefault():MergeRules
    {
        var rules = new MergeRules();
        rules.add("csv", new CSVParseFormat(",",true));
        rules.add("tsv", new TSVParseFormat());
        rules.add("xml", new XMLParseFormat());
        rules.add("json", new JSonParseFormat());
        rules.add("txt", new PlainTextFormat());
    }
}

class CSVParseFormat implements IParseFormat<CSV>;
{
    public var isSimpleMode(default,null):Bool;
    public var delimeter:String;
    public var quotedCells:Bool;

    public function new(delimeter:String, quotedCells:Bool)
    {
        format = CSV;
        this.delimeter = delimeter;
        this.quotedCells = quotedCells;
        if(this.delimeter == "," && quotedCells == false)
        {
            isSimpleMode = true;
        }
    }

    public function parse(str:String):CSV;
    {
        return new CSV(str, delimeter, quotedCells);
    }

    public function append(baseText:String, appendText:String):String
    {
        return Util.appendCSVOrTSV(baseText, appendText);
    }

    public function merge(baseText:String, mergeText:String):String
    {
        var baseCSV = CSV.parseWithFormat(baseText, this);
        var mergeCSV = CSV.parseWithFormat(mergeText, this);
        for (row in mergeCSV.grid)
        {
            var flag = row.length > 0 ? row[0] : "";
            if (flag != "")
            {
                for (i in 0...baseCSV.grid.length)
                {
                    var otherRow = baseCSV.grid[i];
                    var otherFlag = otherRow[0];
                    if (flag == otherFlag)
                    {
                        for (j in 0...row.length)
                        {
                            if (j < otherRow.length)
                            {
                                otherRow[j] = row[j];
                            }
                        }
                    }
                }
            }
        }
        var result = print(baseCSV);
        return result;
    }

    public function print(csv:CSV):String
    {
        var buf = new StringBuf();

        var delimeter = format.delimeter;
        var lf = 0x0A;
        var dq = 0x22;

        for (i in 0...csv.fields.length)
        {
            buf.add(csv.fields[i]);
            if (i != csv.fields.length - 1)
            {
                buf.add(delimeter);
            }
        }

        var strSoFar = buf.toString();

        if (strSoFar.indexOf("\n") == -1)
        {
            buf.add(Std.string("\r\n"));
        }

        var grid = csv.grid;

        for (iy in 0...grid.length)
        {
            var row = grid[iy];
            for (ix in 0...row.length)
            {
                var cell = row[ix];
                if(format.quotedCells){
                    buf.addChar(dq);
                }
                Utf8.iter(cell, function(char:Int)
                {
                    buf.addChar(char);
                });
                if(format.quotedCells){
                    buf.addChar(dq);
                }
                if (ix != row.length - 1)
                {
                    buf.add(delimeter);
                }
            }
            if (iy != grid.length -1)
            {
                buf.add(Std.string("\r\n"));
            }
        }

        return buf.toString();
    }
}

class TSVParseFormat
{
    public function new(){ format = TSV; }

    public function parse(str:String):CSV;
    {
        return new TSV(str);
    }

    public function append(baseText:String, appendText:String):String
    {
        return Util.appendCSVOrTSV(baseText, appendText);
    }

    public function mergeText(baseText:String, mergeText:String):String
    {
        var baseTSV = TSV.parse(baseText);
        var mergeTSV = TSV.parse(mergeText);
        for (row in mergeTSV.grid)
        {
            var flag = row.length > 0 ? row[0] : "";
            if (flag != "")
            {
                for (i in 0...baseTSV.grid.length)
                {
                    var otherRow = baseTSV.grid[i];
                    var otherFlag = otherRow[0];
                    if (flag == otherFlag)
                    {
                        for (j in 0...row.length)
                        {
                            if (j < otherRow.length)
                            {
                                otherRow[j] = row[j];
                            }
                        }
                    }
                }
            }
        }
        var result = print(baseTSV);
        return result;
    }

    public function print(tsv:TSV):String
    {
        var buf = new StringBuf();

        var tab = 0x09;
        var lf = 0x0A;

        for (i in 0...tsv.fields.length)
        {
            buf.add(tsv.fields[i]);
            if (i != tsv.fields.length - 1)
            {
                buf.addChar(tab);
            }
        }

        var strSoFar = buf.toString();

        if (strSoFar.indexOf("\n") == -1)
        {
            buf.add(Std.string("\r\n"));
        }

        var grid = tsv.grid;

        for (iy in 0...grid.length)
        {
            var row = grid[iy];
            for (ix in 0...row.length)
            {
                var cell = row[ix];
                Utf8.iter(cell, function(char:Int)
                {
                    buf.addChar(char);
                });
                if (ix != row.length - 1)
                {
                    buf.addChar(tab);
                }
            }
            if (iy != grid.length -1)
            {
                buf.add(Std.string("\r\n"));
            }
        }

        return buf.toString();
    }
}

class LinesTextParseFormat implements IParseFormat<Array<String>>
{
    var endline:EndLineType;

    public function new(endline:EndLineType)
    {
        format = LINES;
        this.endline = endline;
    }

    public function parse(str:String):Array<String>
    {
        if(str == null || str == "") return [];
        var other = "";
        var endl = "";
        switch(endline)
        {
            case LF: endl = "\n";
            case CR: endl = "\r";
            case CRLF: endl = "\r\n";
            default: endl = "\r"; other="\n";
        }
        if(other == "")
        {
            return str.split(endl);
        }
        else
        {
            str = StringTools.replace(str, other, endl);
            return str.split(endl);
        }
        return [];
    }

    public function append(a:String, b:String):String
    {
        return Util.uCombine([a,getEndl(),new]);
    }

    public function merge(a:String, b:String):String
    {
        if(a == null || b == "") return a;
        if(a == null || b == "") return a;
        var lines = parse(a);
        if(line == null || lines.length <= 0) return a;
        var modLines = parse(b);
        if(modLines == null || modLines.length <= 1) return a;
        var pattern = modLines.shift();
        var newLines = [];
        for(line in lines)
        {
            if(line.indexOf(pattern) == 0)
            {
                newLines = newLines.concat(modLines);
            }
            else
            {
                newLines.push(line);
            }
        }
        return Util.uJoin(newLines,getEndl());
    }

    public function print(lines:Array<String>):String
    {
        return lines.join(getEndl());
    }

    public function getEndl():String
    {
        return switch(endline)
        {
            case LF: "\n";
            case CR: "\r";
            case CRLF: "\r\n";
            default: "\n";
        }
    }
}

class XMLParseFormat implements IParseFormat
{
    public var prettyPrint:Bool=false;
    public var stripHeaders:Array<String>;
    public var stripFooters:Array<String>;
    
    public function new(prettyPrint:Bool=true, headers:Array<String>=null, footers:Array<String>=null)
    {
        if(headers == null) headers = [];
        if(footers == null) footers = [];
        stripHeaders = headers;
        stripFooters = footers;
        this.prettyPrint = prettyPrint;
        format = XML;
    }

    public function parse(str:String):Xml
    {
        return Xml.parse(str);
    }

    public function append(baseText:String, appendText:String):String
    {
        if(stripHeaders != null && stripFooters != null)
        {
            return Util.appendSpecialXML(baseText, appendText, stripHeaders, stripFooters);
        }
        else
        {
            return Util.appendXML(baseText, appendText);
        }
    }

    public function merge(baseText:String, mergeText:String):String
    {
        var basex:Xml = null;
        var mergex:Xml = null;

        try
        {
            basex = Xml.parse(basex);
            mergex = Xml.parse(mergex);
        }
        catch (msg:Dynamic)
        {
            throw "Error parsing XML files during merge (" + id + ") " + msg;
        }

        try
        {
            XMLMerge.mergeXMLNodes(basex, mergex);
        }
        catch (msg:Dynamic)
        {
            throw "Error combining XML files during merge (" + id + ") " + msg;
        }

        if (ax == null)
        {
            return a;
        }

        return print(basex);
    }

    public function print(xml:Xml):String
    {
        return haxe.xml.Printer.print(xml, prettyPrint);
    }
}

class JSONParseFormat extends BaseParseFormat<Json>
{
    public var space(default, null):String;
    public var replacer(default, null):Dynamic->Dynamic->Dynamic;

    public function new(spacer:String, replacer:Dynamic->Dynamic->Dynamic=null)
    {
        this.replacer = replacer;
        this.spacer = spacer;
        format = JSON;
        super();
    }

    public function parse(str:String):Json
    {
        return Json.parse(str);
    }

    public function append(baseText:String, appendText:String):String
    {
        var lastBracket = Util.uLastIndexOf(baseText,"}");
        var baseFirst = Util.uSubstr(baseText,0,lastBracket);
        var baseEnd = Util.uSubstr(baseText, lastBracket,baseText.length);
        
        var firstAppendBracket = Util.uIndexOf(appendText,"{");
        var lastAppendBracket = Util.uLastIndexOf(appendText,"}");
        var injectText = Util.uSubstring(appendText,firstAppendBracket+1,lastAppendBracket);
        
        if(injectText == null || injectText == "") return baseText;
        
        var whiteSpace = [32,10,13,9]; //" ","\n","\r","\t"
        var justWhiteSpace = true;
        
        var i:Int = 0;
        Utf8.iter(baseText, function(c:Int){
            if(i == 0) continue;
            if(whiteSpace.indexOf(c) == -1)
            {
                justWhiteSpace = false;
                return;
            }
            if(i >= lastBracket) return;
        })

        var comma = justWhiteSpace ? "" : ",";
    
        return baseFirst + comma + injectText + baseEnd;
    }

    public function merge(baseText:String, mergeText:String):String
    {
        //var json1:String = '{"stuff":["a","b","c","d"],"things":{"numbers":[1,2,3,4,5]}}';
        //var json2:String = '{"polymod_merge":"things.numbers[2]","payload":{"message":"free puppies!"}}';
        
        var base:Dynamic = parse(baseText);
        var merge:Dynamic = parse(mergeText);
    }

    public function print(data:Json):String
    {
        return Json.stringify(data, replacer, space);
    }
}

class PlainTextParseFormat implements IParseFormat<String>
{
    public function new() { format = PLAINTEXT; }

    public function parse(str:String):String { return str; }

    public function append(baseText:String, appendText:String):String
    {
        var lastChar = uCharAt(baseText, uLength(baseText) - 1);
        var lastLastChar = uCharAt(baseText, uLength(baseText) - 1);
        var joiner = "";

        var endLine = "\n";

        var crIndex = uIndexOf(baseText, "\r");
        var lfIndex = uIndexOf(baseText, "\n");
        
        if (crIndex != -1)
        {
            if (lfIndex == crIndex + 1)
            {
                endLine = "\r\n";
            }
        }

        if (lastChar != "\n")
        {
            joiner = endLine;
        }

        return uCombine([baseText, joiner, appendText]);
    }
    
    public function merge(baseText:String, mergeText:String):String
    {
        Polymod.warning(PolymodError.MERGE, "Plain text does not support merging!");
        return baseText;
    }

    public function print(str:String):String { return str; }
}

enum TextFileFormat
{
    PLAINTEXT;
    LINES;
    CSV;
    TSV;
    XML;
    JSON;
}

enum EndLineType
{
    LF;
    CR;
    CRLF;
    ANY;
}