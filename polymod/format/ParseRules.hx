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

import haxe.Json;
import polymod.Polymod;
import polymod.Polymod.PolymodError;
import polymod.Polymod.PolymodErrorType;
import polymod.fs.PolymodFileSystem;
import polymod.util.Util;

#if unifill
import unifill.Unifill;
#end

import UnicodeString;

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
            case JSON: new JSONParseFormat();
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

    public function addFile(path:String, format:BaseParseFormat) 
    {
        formats.set(path, format);
    }

    public static function getDefault():ParseRules
    {
        var rules = new ParseRules();
        rules.addFormat("csv", new CSVParseFormat(",",true));
        rules.addFormat("tsv", new TSVParseFormat());
        rules.addFormat("xml", new XMLParseFormat());
        rules.addFormat("json", new JSONParseFormat());
        rules.addFormat("txt", new PlainTextParseFormat());
        return rules;
    }
}

class CSVParseFormat implements BaseParseFormat
{
    public var format(default, null):TextFileFormat;
    public var isSimpleMode(get,null):Bool;
    public var delimeter:String;
    public var quotedCells:Bool;
    public var lookForHeaders:Bool;

    public function new(delimeter:String, quotedCells:Bool)
    {
        format = TextFileFormat.CSV;
        this.delimeter = delimeter;
        this.quotedCells = quotedCells;
    }

    private function get_isSimpleMode():Bool
    {
        return (delimeter == "," && quotedCells == false);
    }

    public function parse(str:String):CSV
    {
        return polymod.format.CSV.parse(str, delimeter, quotedCells);
    }

    public function append(baseText:String, appendText:String, id:String):String
    {
		var endLine:String = "\n";
		if (baseText.indexOf("\r\n") != -1){
			endLine = "\r\n";
		}
		if (lookForHeaders)
		{
			var baseCSV:polymod.format.CSV;
			var appendCSV:polymod.format.CSV;
			
			//Strip of a trailing endline from append if there is one
			var appendEndLine = "\n";
			if(appendText.indexOf("\r\n") != -1){
				appendEndLine = "\r\n";
			}
			var appendLength = Util.uLength(appendText);
			var appendLast = Util.uLastIndexOf(appendText, appendEndLine);
			if (appendLast == appendLength - 1 || appendLast == appendLength - 2){
				appendText = Util.uSubstr(appendText, 0, appendLength - Util.uLength(appendEndLine));
			}
			
			try
			{
				baseCSV = polymod.format.CSV.parseWithFormat(baseText, this);
				appendCSV = polymod.format.CSV.parseWithFormat(appendText, this);
			}
			catch(msg:Dynamic)
			{
				Polymod.error(APPEND,"CSV Append error ("+id+") : " + msg);
				return baseText;
			}
			
			var finalText:String = baseText;
			var finalLength = Util.uLength(finalText);
			
			var lastEndLine = Util.uLastIndexOf(finalText, endLine);
			var addFinalEndline = false;
			
			if (lastEndLine == finalLength - 1 || lastEndLine == finalLength - 2){
				finalText = Util.uSubstr(finalText, 0, finalLength - Util.uLength(endLine));
				addFinalEndline = true;
			}
			
			var compareFields = 0;
			for (i in 0...baseCSV.fields.length){
				var baseField = baseCSV.fields[i];
				var appendFieldExists = appendCSV.fields.indexOf(baseField) != -1;
				if (appendFieldExists) compareFields++;
			}
			
			if (lookForHeaders){
				if (compareFields < Std.int(baseCSV.fields.length/2)){
					Polymod.error(APPEND, "Mod file(" + id + ") is missing most or all of the expected header fields", INIT);
				}
			}
			
			var missingFields = [];
			
			for (r in 0...appendCSV.grid.length){
				var line = "";
				for (bi in 0...baseCSV.fields.length){
					var baseField = baseCSV.fields[bi];
					var appendField = appendCSV.fields.indexOf(baseField);
					if (appendField != -1){
						var appendValue = appendCSV.grid[r][appendField];
						if (appendValue == null){
							appendValue = "";
						}
						line += appendValue;
					}
					else{
						if (missingFields.indexOf(baseField) == -1){
							missingFields.push(baseField);
						}
					}
					if(bi != baseCSV.fields.length-1){
						line += delimeter;
					}
				}
				finalText += endLine + line;
			}
			
			if (addFinalEndline){
				finalText += endLine;
			}
			
			for(baseField in missingFields){
				Polymod.warning(PolymodErrorCode.APPEND, "Mod file(" + id + ") missing expected field \"" + baseField + "\", values will default to empty string.", INIT);
			}
			
			return finalText;
		}
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
                buf.add(cell);
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
                buf.add(cell);
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

typedef TargetSignatureElement = {
    var value:String;
    var arrayIndeces:Array<Int>;
}

typedef JsonMergeEntry = {
    var target:String;
    var payload:Dynamic;
}

typedef JsonMergeStruct = {
    var merge:Array<JsonMergeEntry>;
}

class JSONParseFormat implements BaseParseFormat
{
    public var format:TextFileFormat;
    public var space(default, null):String;
    public var replacer(default, null):Dynamic->Dynamic->Dynamic;

    public function new(space:String=null, replacer:Dynamic->Dynamic->Dynamic=null)
    {
        this.replacer = replacer;
        this.space = space;
        format = JSON;
    }

    public function parse(str:String):Dynamic
    {
        return Json.parse(str);
    }

    public function append(baseText:String, appendText:String, id:String):String
    {
        var lastBracket = Util.uLastIndexOf(baseText,"}");
        var baseFirst = Util.uSubstr(baseText,0,lastBracket);
        var baseEnd = Util.uSubstr(baseText, lastBracket,baseText.length);
        
        var firstAppendBracket = Util.uIndexOf(appendText,"{");
        var lastAppendBracket = Util.uLastIndexOf(appendText,"}");
        var injectText = Util.uSubstring(appendText,firstAppendBracket+1,lastAppendBracket);
        
        if(injectText == null || injectText == "") return baseText;
        
        //var whiteSpace = [32,10,13,9]; //" ","\n","\r","\t"
        
        baseFirst = Util.uTrimFinalEndlines(baseFirst);
        injectText = Util.uTrimFinalEndlines(injectText);
        injectText = Util.uTrimFirstEndlines(injectText);
        baseEnd = Util.uTrimFinalEndlines(baseEnd);

        var comma = ",";

        return baseFirst + comma + "\n" + injectText + baseEnd;
    }

    public function merge(baseText:String, mergeText:String, id:String):String
    {
		var base:Dynamic = null;
        var merge:JsonMergeStruct = null;

        try
        {
            base = cast parse(baseText);
        }
        catch(msg:Dynamic)
        {
            Polymod.error(MERGE,"JSON merge error ("+id+"): couldn't parse base text! : " + msg);
        }

        try
        {
            merge = cast parse(mergeText);
        }
        catch(msg:Dynamic)
        {
            Polymod.error(MERGE,"JSON merge error ("+id+"): couldn't parse merge text! : " + msg);
            return baseText;
        }
		
        if(Reflect.hasField(merge,"merge"))
        {
			if(Std.isOfType(merge.merge,Array))
            {
			    var merge:Array<JsonMergeEntry> = merge.merge;
			    for(entry in merge)
                {
			        var target = null;
                    var payload = null;

                    target = entry.target;
                    payload = entry.payload;
                    base = _mergeJson(base, entry, id);
                }
            }
            else
            {
                Polymod.error(MERGE,"JSON merge error ("+id+"): merge file must contain a single top-level array named \"merge\"! (Found an object, not an array)");
            }
        }
        else
        {
            Polymod.error(MERGE,"JSON merge error ("+id+"): merge file must contain a single top-level array named \"merge\"!");
        }
        return print(base);
    }

    private function _mergeJson(base:Dynamic, entry:JsonMergeEntry, id:String):Dynamic
    {
		var sig = _getTargetSignature(entry.target);
        var obj = base;
        var currTarget = sig[0];
        if(currTarget == null)
        {
            Polymod.warning(MERGE,"JSON merge failed ("+id+"), sig was " + sig);
            return obj;
        }
        
        var done = false;
        var last = obj;
        var i:Int = 0;
        var signatureSoFar = "";
        var struct:{next:Dynamic,parent:Dynamic,arrIndex:Int,target:String} = {next:null,parent:null,arrIndex:-1,target:null};
        var next = null;
        while(!done)
        {
            struct = _descend(last, currTarget, signatureSoFar, struct);
            if(struct == null)
            {
                next = null;
            }
            else
            {
                next = struct.next;
            }

            if(signatureSoFar != "") signatureSoFar += ".";
            signatureSoFar += _targSigElementToString(currTarget);
            i++;

            if(next == null)
            {
                Polymod.warning(MERGE,"JSON merge failed ("+id+"), could not find object \""+signatureSoFar+"\")");
                done = true;
            }
            else
            {
                if(i < sig.length)
                {
                    currTarget = sig[i];
                }
                else
                {
                    _inject(struct.parent, struct.target, struct.arrIndex, entry.payload, signatureSoFar);
                    done = true;
                }
            }
            last = next;
        }
        return obj;
    }

    private function _targSigElementToString(target:TargetSignatureElement):String
    {
        var str = target.value;
        if(target.arrayIndeces != null && target.arrayIndeces.length > 0)
        {
            for(arri in target.arrayIndeces)
            {
                if(arri >= 0)
                {
                    str += "["+arri+"]";
                }
            }
        }
        return str;
    }

    private function _inject(obj:Dynamic, target:String, arrIndex:Int, payload:Dynamic, signatureSoFar:String="")
    {
		if(arrIndex == -1)
        {
            if(Reflect.hasField(obj,target))
            {
                var baseObject = Reflect.field(obj,target);
                var mergedValue = _mergeObjects(baseObject, payload, signatureSoFar);
                Reflect.setField(obj, target, mergedValue);
            }
            else
            {
                Reflect.setField(obj, target, payload);
            }
        }
        else
        {
            if(Std.isOfType(obj,Array))
            {
                var arr:Array<Dynamic> = cast obj;
                if(arr.length > arrIndex)
                {
                    var baseObject = arr[arrIndex];
                    var mergedValue = _mergeObjects(baseObject, payload, signatureSoFar);
                }
                else
                {
                    Polymod.warning(MERGE,"JSON merge failed, array index ("+arrIndex+") out of bounds for array of length ("+arr.length+") at " + signatureSoFar);
                }
            }
        }
    }
    
    private function _mergeObjects(a:Dynamic, b:Dynamic, signatureSoFar:String=""):Dynamic
    {
		 if(Std.isOfType(a,Array) && Std.isOfType(b,Array))
        {
            //if they are both arrays, stomp with b's values
            return b;
        }
        else if(!Std.isOfType(a,Array) && !Std.isOfType(b,Array))
        {
			var aPrimitive = isPrimitive(a);
			var bPrimitive = isPrimitive(b);
			if(aPrimitive && bPrimitive)
			{
				//if they are both primitives, stomp with b
				return b;
			}
			else if(aPrimitive != bPrimitive)
			{
				//if they are incompatible, stomp with a
				return a;
			}
			else
			{
				//if they are both objects, merge their values
				for(field in Reflect.fields(b))
				{
					if(Reflect.hasField(a,field))
					{
						//If a & b share a field, merge that field recursively
						var aValue = Reflect.field(a,field);
						var bValue = Reflect.field(b,field);
						var mergedValue = copyVal(_mergeObjects(aValue, bValue, signatureSoFar+"."+field));
						Reflect.setField(a, field, mergedValue);
					}
					else
					{
						//If b has a field that a doesn't have, add it to a
						Reflect.setField(a, field, Reflect.field(b, field));
					}
				}
			}
        }
        else
        {
            //if they're incompatible types, return a
            var aArr = Std.isOfType(a,Array) ? "array" : "object";
            var bArr = Std.isOfType(b,Array) ? "array" : "object";
            Polymod.warning(MERGE,"JSON can't merge @ ("+signatureSoFar+") because base is ("+aArr+") but payload is ("+bArr+")");
        }
        return a;
    }
    
    private function copyVal(a:Dynamic):Dynamic
    {
        var b:Dynamic = null;
        if(Std.isOfType(a,Int)) b = Std.int(a);
        if(Std.isOfType(a,Float)) b = cast(a,Float);
        if(Std.isOfType(a,String)) b = Std.string(b);
        if(Std.isOfType(a,Bool)) b = (a == true);
        else b = Std.string(a);
        return b;
    }

    private function isPrimitive(a:Dynamic):Bool
    {
        if(Std.isOfType(a,String)) return true;
        if(Std.isOfType(a,Float)) return true;
        if(Std.isOfType(a,Int)) return true;
        if(Std.isOfType(a,Bool)) return true;
        return false;
    }

    private function _descend(obj:Dynamic, target:TargetSignatureElement, signatureSoFar:String="", struct:{next:Dynamic,parent:Dynamic,arrIndex:Int,target:String}=null):{next:Dynamic,parent:Dynamic,arrIndex:Int,target:String}
    {
        if(struct == null)
        {
            struct = {next:null,parent:null,arrIndex:-1,target:null};
        }
        if(obj == null) return null;
        if(target == null) return null;
        
        if(Reflect.hasField(obj,target.value) == false)
        {
            Polymod.warning(MERGE,"JSON merge error : object ("+signatureSoFar+") has no field ("+target.value+")");
            return null;
        }
        var next = Reflect.field(obj,target.value);
        
        struct.next = next;
        struct.parent = obj;
        struct.target = target.value;
        
        if(next == null) 
        {
            return struct;
        }
        if(target.arrayIndeces.length > 0)
        {
            struct.next = next;
            if(Std.isOfType(next,Array))
            {
                var arr:Array<Dynamic> = cast next;
                var arrIndeces = target.arrayIndeces.copy();
                var done = false;
                signatureSoFar += "." + target.value;
                while(arrIndeces.length > 0)
                {
                    var arrIndex = arrIndeces.shift();
                    if(arrIndex < arr.length)
                    {
                        struct.parent = next;
                        next = arr[arrIndex];
                        struct.next = next;
                        struct.arrIndex = arrIndex;
                        if(Std.isOfType(next,Array))
                        {
                            arr = cast next;
                        }
                        else
                        {
                            Polymod.warning(MERGE,"JSON merge error : invalid array access ["+arrIndex+"] on target \""+signatureSoFar+"\"");
                            done = true;
                        }
                    }
                    else
                    {
                        Polymod.warning(MERGE,"JSON merge error : array index ("+arrIndex+") out of bounds on target \""+signatureSoFar+"\" with length " + arr.length);
                        done = true;
                    }
                    signatureSoFar += "["+arrIndex+"]";
                }
            }
            else
            {
                return null;
            }
        }
        return struct;
    }

    private function _getTargetSignature(str:String):Array<TargetSignatureElement>
    {
        if(str == null) return [];
        var result = [];
        var arr = str.split(".");
        for(bit in arr)
        {
            if(bit.indexOf("[") != -1)
            {
                var arr2 = bit.split("[");
                var value = arr2.shift();
                var arrayIndeces = [];
                while(arr2.length > 0)
                {
                    var value2 = arr2.shift();
                    value2 = Util.uTrimFinalCharIf(value2,"]");
                    var arrIndex = Std.parseInt(value2);
                    if(arrIndex != null && arrIndex >= 0)
                    {
                        arrayIndeces.push(arrIndex);
                    }
                    else
                    {
                        Polymod.warning(MERGE,"JSON merge error: found invalid array index ("+value2+") in signature ("+str+")");
                        break;
                    }
                }
                result.push({value:value,arrayIndeces:arrayIndeces});
            }
            else
            {
                result.push({value:bit,arrayIndeces:[]});
            }
        }
        return result;
    }

    public function print(data:Dynamic):String
    {
        return haxe.Json.stringify(data, replacer, space);
    }
}

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