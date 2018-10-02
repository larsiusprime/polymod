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
import polymod.util.Util;

#if unifill
import unifill.Unifill;
#end

import haxe.Utf8;

class ParseRules
{
    private var formats:Map<String, BaseParseFormat>;

    public function new()
    {
        formats = new Map<String, BaseParseFormat>();
    }

    public function addType(extension:String, type:TextFileFormat)
    {
        var format:BaseParseFormat = switch(type)
        {
            case CSV: new CSVParseFormat(",",true);
            case TSV: new TSVParseFormat();
            case XML: new XMLParseFormat();
            //case JSON: new JSONParseFormat();
            case LINES: new LinesParseFormat(EndLineType.LF);
            case PLAINTEXT: new PlainTextParseFormat();
            default: new PlainTextParseFormat();
        }
        formats.set(extension, format);
    }

    public function get(extension:String):BaseParseFormat
    {
        return formats.get(extension);
    }

    public function addFormat(extension:String, format:BaseParseFormat)
    {
        formats.set(extension, format);
    }

    public static function getDefault():ParseRules
    {
        var rules = new ParseRules();
        rules.addFormat("csv", new CSVParseFormat(",",true));
        rules.addFormat("tsv", new TSVParseFormat());
        rules.addFormat("xml", new XMLParseFormat());
        //rules.addFormat("json", new JSonParseFormat());
        rules.addFormat("txt", new PlainTextParseFormat());
        return rules;
    }
}

class CSVParseFormat implements BaseParseFormat
{
    public var format(default, null):TextFileFormat;
    public var isSimpleMode(default,null):Bool;
    public var delimeter:String;
    public var quotedCells:Bool;

    public function new(delimeter:String, quotedCells:Bool)
    {
        format = TextFileFormat.CSV;
        this.delimeter = delimeter;
        this.quotedCells = quotedCells;
        if(this.delimeter == "," && quotedCells == false)
        {
            isSimpleMode = true;
        }
    }

    public function parse(str:String):CSV
    {
        return polymod.format.CSV.parse(str, delimeter, quotedCells);
    }

    public function append(baseText:String, appendText:String, id:String):String
    {
        return Util.appendCSVOrTSV(baseText, appendText, id);
    }

    public function merge(baseText:String, mergeText:String, id:String):String
    {
        var baseCSV:polymod.format.CSV;
        var mergeCSV:polymod.format.CSV;
        try
        {
            baseCSV = polymod.format.CSV.parseWithFormat(baseText, this);
            mergeCSV = polymod.format.CSV.parseWithFormat(mergeText, this);
        }
        catch(msg:Dynamic)
        {
            Polymod.error(MERGE,"CSV Merge error ("+id+") : " + msg);
            return baseText;
        }

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

    public function print(csv:polymod.format.CSV):String
    {
        var buf = new StringBuf();

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
                if(quotedCells)
                {
                    buf.addChar(dq);
                }
                Utf8.iter(cell, function(char:Int)
                {
                    buf.addChar(char);
                });
                if(quotedCells)
                {
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

class TSVParseFormat implements BaseParseFormat
{
    public var format(default, null):TextFileFormat;
    public function new(){ format = TSV; }

    public function parse(str:String)
    {
        return polymod.format.TSV.parse(str);
    }

    public function append(baseText:String, appendText:String, id:String):String
    {
        return Util.appendCSVOrTSV(baseText, appendText, id);
    }

    public function merge(baseText:String, mergeText:String, id:String):String
    {
        var baseTSV = polymod.format.TSV.parse(baseText);
        var mergeTSV = polymod.format.TSV.parse(mergeText);
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

class LinesParseFormat implements BaseParseFormat //<Array<String>>
{
    public var format(default, null):TextFileFormat;
    public var endline:EndLineType;

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

    public function append(baseText:String, appendText:String, id:String):String
    {
        return Util.uCombine([baseText,getEndl(),appendText]);
    }

    public function merge(baseText:String, mergeText:String, id:String):String
    {
        if(baseText == null || mergeText == "") return baseText;
        if(baseText == null || mergeText == "") return baseText;
        var lines = parse(baseText);
        if(lines == null || lines.length <= 0) return baseText;
        var mergeLines = parse(mergeText);
        if(mergeLines == null || mergeLines.length <= 1) return baseText;
        var pattern = mergeLines.shift();
        var newLines = [];
        for(line in lines)
        {
            if(line.indexOf(pattern) == 0)
            {
                newLines = newLines.concat(mergeLines);
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

class XMLParseFormat implements BaseParseFormat //<Xml>
{
    public var format(default, null):TextFileFormat;
    public var prettyPrint:Bool=false;
    public var stripHeaders:Array<String>;
    public var stripFooters:Array<String>;
    
    public function new(prettyPrint:Bool=false, headers:Array<String>=null, footers:Array<String>=null)
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

    public function append(baseText:String, appendText:String, id:String):String
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

    public function merge(baseText:String, mergeText:String, id:String):String
    {
        var basex:Xml = null;
        var mergex:Xml = null;

        try
        {
            basex = Xml.parse(baseText);
            mergex = Xml.parse(mergeText);
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

        return print(basex);
    }

    public function print(xml:Xml):String
    {
        return haxe.xml.Printer.print(xml, prettyPrint);
    }
}

/*
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

    public function merge(baseText:String, mergeText:String, id:String):String
    {
        //var json1:String = '{"stuff":["a","b","c","d"],"things":{"numbers":[1,2,3,4,5]}}';
        //var json2:String = '{"merge":[{"target":"things.numbers[2]","payload":{"message":"free puppies!"}},{"target":"things.extra","payload":{"alert":"free kittens!"}}]}';
        
        var base:Dynamic = parse(baseText);
        var merge:JsonMergeStruct = null;
        
        try
        {
            merge = cast parse(mergeText);
        }
        catch(msg:Dynamic)
        {
            PolymodError.error(MERGE,"JSON merge error ("+id+"): text was an unexpected format! msg: " + msg);
            return baseText;
        }
        
        var merge:Array<JsonMergeEntry> = merge.merge;
        for(entry in merge)
        {
            var target = merge.target;
            var payload = merge.payload;
            base = _mergeJson(base, entry);
        }

        print(base);
    }

    private function _mergeJson(base:Dynamic, entry:JsonMergeEntry, id:String):Dynamic
    {
        var sig = _getTargetSignature(entry.target);
        var obj = base;
        var done = false;
        var last = obj;
        var currTarget = entry.target;
        var signatureSoFar = 
        while(!done)
        {
            var next = _descend(obj, currTarget, signatureSoFar);
            if(next == last)
            {
                _inject(obj, currTarget, payload);
                done = true;
            }
            else if(next == null)
            {
                PolymodError.warning(MERGE,"JSON merge failed ("+id+")");
                done = true;
            }
            last = next;
        }
    }

    private function _inject(obj:Dynamic, target:TargetSignatureElement, payload:Dynamic, signatureSoFar:String="")
    {
        if(Reflect.hasField(obj,target.value))
        {
            var mergedValue = _mergeObjects(Reflect.field(obj,target.value), payload, signatureSoFar);
            Reflect.setField(obj, target.value, mergedValue);
        }
        else
        {
            Reflect.setField(obj, target.value, payload);
        }
    }

    private function _mergeObjects(a:Dynamic, b:Dynamic, signatureSoFar:String=""):Dynamic
    {
        for(field in Reflect.fields(b))
        {
            if(Reflect.hasField(a))
            {
                //a and b share a field in common
                var aValue = Reflect.field(a, field);
                var bValue = Reflect.field(b, field);

                if(Std.is(aValue, Array) && Std.is(bValue, Array))
                {
                    //if they are both arrays, stomp with b's values
                    Reflect.setField(a, field, bValue);
                }
                else if(!Std.is(aValue, Array) && !Std.is(bValue, Array))
                {
                    //if they are both objects, merge them recursively
                    var mergedValue = _mergeObjects(aValue, bValue, signatureSoFar+"."+field);
                    Reflect.setField(a, field, mergedValue);
                }
                else
                {
                    //if the types don't match, we can't merge this bit
                    var aArr:String = Std.is(aValue,Array) ? "array" : "object";
                    var bArr:String = Std.is(bValue,Array) ? "array" : "object";
                    Polymod.WARNING(MERGE,"Can't merge field ("+field+") @ ("+signatureSoFar+") -- a is ("+aArr+") but b is ("+bArr+")");
                }
            }
            else
            {
                //b has a field that a doesn't have, add it to a
                Reflect.setField(a, Reflect.field(b, field));
            }
        }
        return a;
    }

    private function _descend(obj:Dynamic, target:TargetSignatureElement, signatureSoFar:String=""):Dynamic
    {
        if(obj == null) return null;
        if(target == null) return null;
        if(Reflect.hasField(obj,target.value) == false)
        {
            Polymod.WARNING(MERGE,"JSON merge error : object ("+signatureSoFar+") has no field ("+target.value+")");
            return null;
        }
        var next = Reflect.field(obj,target.value);
        if(next == null) 
        {
            return obj;
        }
        if(target.arrayIndeces.length > 0)
        {
            if(Std.is(next,Array))
            {
                var arr:Array<Dynamic> = cast next;
                var arrIndex = target.arrayIndeces[0];
                var done = false;
                while(!done)
                {
                    if(arrIndex < arr.length)
                    {
                        next = arr[arrIndex];
                        if(Std.is(next,Array))
                        {
                            arr = cast next;
                            signatureSoFar += "["+arrIndex+"]";
                        }
                        else
                        {
                            Polymod.WARNING(MERGE,"JSON merge error : invalid array access ["+arrIndex+"] on an object value at signature ("+signatureSoFar+")");
                            done = true;
                        }
                    }
                }
            }
            else
            {
                return null;
            }
        }
        return null;
    }

    private function _getTargetSignature(str:String):Array<TargetSignatureElement>
    {
        var result = [];
        var arr = str.split(".");
        for(bit in arr)
        {
            if(bit.indexOf("[") != -1)
            {
                var arr2 = bit.split("[");
                var value = arr.shift();
                var arrayIndeces = [];
                while(arr.length > 0)
                {
                    var value2 = arr[1];
                    if(value2.indexOf("]") == value2.length-1)
                    {
                        value2 = value2.substr(0,value2.length-1);
                    }
                    var arrIndex = Std.parseInt(value2);
                    if(arrIndex != null && arrIndex >= 0)
                    {
                        arrayIndexes.push(arrIndex);
                    }
                    else
                    {
                        Polymod.WARNING(MERGE,"JSON merge error: found invalid array index ("+value2+") in signature ("+str+")");
                        break;
                    }
                }
                result.push({value:value,arrayIndeces:arrayIndeces});
            }
            else
            {
                result.push({value:value,arrayIndeces:[]});
            }
        }
        return result;
    }

    public function print(data:Json):String
    {
        return Json.stringify(data, replacer, space);
    }
}

typedef TargetSignatureElement = {
    value:String,
    arrayIndeces:Array<Int>
}

typedef JsonMergeEntry = {
    target:String,
    payload:Dynamic
}

typedef JsonMergeStruct = {
    merge:Array<JsonMergeEntry>
}
*/

class PlainTextParseFormat implements BaseParseFormat //<String>
{
    public var format(default, null):TextFileFormat;
    public function new() { format = PLAINTEXT; }

    public function parse(str:String):String { return str; }

    public function append(baseText:String, appendText:String, id:String):String
    {
        var lastChar = Util.uCharAt(baseText, Util.uLength(baseText) - 1);
        var lastLastChar = Util.uCharAt(baseText, Util.uLength(baseText) - 1);
        var joiner = "";

        var endLine = "\n";

        var crIndex = Util.uIndexOf(baseText, "\r");
        var lfIndex = Util.uIndexOf(baseText, "\n");
        
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

        return Util.uCombine([baseText, joiner, appendText]);
    }
    
    public function merge(baseText:String, mergeText:String, id:String):String
    {
        Polymod.warning(MERGE, "("+id+") Plain text does not support merging!");
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