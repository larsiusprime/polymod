package polymod.library;

#if sys
import sys.FileSystem;
#end

import haxe.Utf8;

class Util
{
	public static function mergeAndAppendText(baseText:String, id:String, dirs:Array<String>, getBaseText:String->String->String):String
	{
		var text = baseText;
		
		for (d in dirs)
		{
			if (hasMerge(id, d))
			{
				text = mergeText(text, id, d, getBaseText);
			}
			if (hasAppend(id, d))
			{
				text = appendText(text, id, d, getBaseText);
			}
		}
		
		return text;
	}
	
	/**
	 * Looks for a "_merge" entry for an asset and tries to merge its contents into the original
	 * With the following rules:
	 * - Only applies to XML and TSV files (identified by extension)
	 * - Adds single nodes from the merged asset into the original
	 * - If the original has that node too, it overwrites the original information
	 * @param	baseText	the basic text file you're merging extra content into
	 * @param	id	the name of the asset file
	 * @return
	 */
	
	public static function mergeText(baseText:String, id:String, theDir:String = "", getBaseText:String->String->String):String
	{
		var extension = uExtension(id, true);
		
		id = stripAssetsPrefix(id);
		
		if (extension == "xml")
		{
			var mergeText = getBaseText("_merge" + sl() + id, theDir);
			return mergeXML(baseText, mergeText, id);
		}
		else if (extension == "tsv")
		{
			var mergeText = getBaseText("_merge" + sl() + id, theDir);
			return mergeTSV(baseText, mergeText, id);
		}
		
		return baseText;
	}
	
	private static function mergeTSV(a:String, b:String, id:String):String
	{
		var aTSV = new TSV(a);
		var bTSV = new TSV(b);
		
		for (row in bTSV.grid)
		{
			var flag = row.length > 0 ? row[0] : "";
			if (flag != "")
			{
				for (i in 0...aTSV.grid.length)
				{
					var otherRow = aTSV.grid[i];
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
		
		var result = printTSV(aTSV);
		
		return result;
	}
	
	public static function printTSV(tsv:TSV):String
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
		
		if (strSoFar.indexOf("\n") != -1)
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
	
	public static function mergeXML(a:String, b:String, id:String):String
	{
		var ax:Xml = null;
		var bx:Xml = null;
		
		try
		{
			ax = Xml.parse(a);
			bx = Xml.parse(b);
		}
		catch (msg:Dynamic)
		{
			throw "Error parsing XML files during merge (" + id + ") " + msg;
		}
		
		try
		{
			XMLMerge.mergeXMLNodes(ax, bx);
		}
		catch (msg:Dynamic)
		{
			throw "Error combining XML files during merge (" + id + ") " + msg;
		}
		
		if (ax == null)
		{
			return a;
		}
		
		var result = haxe.xml.Printer.print(ax);
		
		return result;
	}
	
	public static function appendText(baseText:String, id:String, theDir:String, getBaseText:String->String->String):String
	{
		var extension = uExtension(id, true);
		
		id = stripAssetsPrefix(id);
		
		if (extension == "xml")
		{
			var appendText = getBaseText("_append" + sl() + id, theDir);
			
			switch(id)
			{
				case "game_progression.xml":
					return appendSpecialXML(baseText, appendText, ["<plotlines>"], ["</plotlines>"]);
				default:
					return appendXML(baseText, appendText);
			}
		}
		else if(extension == "tsv" || extension == "txt")
		{
			var appendText = getBaseText("_append" + sl() + id, theDir);
			
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
			
			if (extension == "tsv")
			{
				var otherEndline = endLine == "\n" ? "\r\n" : "\n";
				appendText = uSplitReplace(appendText, otherEndline, endLine);
			}
			
			var returnText = uCombine([baseText, joiner, appendText]);
			
			return returnText;
		}
		else if (extension == "json")
		{
			//TODO
		}
		
		return baseText;
	}
	
	public static function appendSpecialXML(a:String, b:String, headers:Array<String>, footers:Array<String>):String
	{
		a = stripXML(a, true, true, headers, footers);
		b = stripXML(b, true, true, headers, footers);
		
		var txt = '<?xml version="1.0" encoding="utf-8" ?>';
		txt = uCat(txt, "<data>");
		txt = uCat(txt, a);
		txt = uCat(txt, b);
		txt = uCat(txt, "</data>");
		
		return txt;
	}
	
	public static function appendXML(a:String, b:String):String
	{
		a = stripXML(a, false, true);
		b = stripXML(b, true, false);
		
		var txt = uCat(a, b);
		
		return txt;
	}
	
	public static function stripComments(txt:String):String
	{
		var start = uIndexOf(txt,"<!--");
		var end   = uIndexOf(txt,"-->");
		while (start != -1 && end != -1)
		{
			var len    = uLength(txt);
			var before = uSubstr(txt, 0, start);
			var after  = uSubstr(txt, end + 3, len - (end + 3));
			txt = uCat(before, after);
			start = uIndexOf(txt,"<!--");
			end   = uIndexOf(txt,"-->");
		}
		return txt;
	}
	
	public static function trimLeadingWhiteSpace(txt:String):String
	{
		var white=["\r","\n"," ","\t"];
		var len = uLength(txt);
		for (w in white)
		{
			while (uIndexOf(txt, w) == 0)
			{
				txt = uSubstr(txt,1,len-1);
				len--;
			}
		}
		return txt;
	}

	public static function trimTrailingWhiteSpace(txt:String):String
	{
		var white=["\r","\n"," ","\t"];
		var len = uLength(txt);
		for (w in white)
		{
			while (uCharAt(txt, len - 1) == w)
			{
				txt = uSubstr(txt,0,len-1);
				len--;
			}
		}
		return txt;
	}
	
	public static function stripXML(txt:String, stripHeader:Bool=true, stripFooter:Bool=true, headers:Array<String>=null, footers:Array<String>=null):String
	{
		txt = stripComments(txt);
		
		if (stripHeader)
		{
			if (uIndexOf(txt, "<?xml") == 0)
			{
				var i = uIndexOf(txt, ">");
				txt = uSubstr(txt, i+1, uLength(txt) - (i+1));
				txt = trimLeadingWhiteSpace(txt);
			}
			if (uIndexOf(txt, "<data") == 0)
			{
				var i = uIndexOf(txt, ">");
				txt = uSubstr(txt, i+1, uLength(txt) - (i+1));
				txt = trimLeadingWhiteSpace(txt);
			}
			if (headers != null)
			{
				for (header in headers)
				{
					if (uIndexOf(txt, header) == 0)
					{
						var i = uIndexOf(txt, ">");
						txt = uSubstr(txt, (i + 1), uLength(txt) - (i+1));
						txt = trimLeadingWhiteSpace(txt);
					}
				}
			}
		}
		if (stripFooter)
		{
			txt = trimTrailingWhiteSpace(txt);
			var ulen = uLength(txt);
			if (uLastIndexOf(txt, "</data>") == ulen - 7)
			{
				txt = uSubstr(txt, 0, ulen - 7);
			}
			if (footers != null)
			{
				for (footer in footers)
				{
					txt = trimTrailingWhiteSpace(txt);
					var ulen = uLength(txt);
					var footerlen = uLength(footer);
					if (uLastIndexOf(txt, footer) == ulen - footerlen)
					{
						txt = uSubstr(txt, 0, ulen - footerlen);
					}
				}
			}
		}
		return txt;
	}
	
	public static inline function hasMerge(id:String, theDir:String = ""):Bool
	{
		return hasSpecial(id, "_merge", theDir);
	}
	
	private static inline function hasAppend(id:String, theDir:String = ""):Bool
	{
		return hasSpecial(id, "_append", theDir);
	}
	
	public static inline function stripAssetsPrefix(id:String):String
	{
		if (uIndexOf(id, "assets/") == 0)
		{
			id = uSubstring(id, 7);
		}
		return id;
	}
	
	public static function hasSpecial(id:String, special:String = "", theDir:String = ""):Bool
	{
		#if sys
		id = stripAssetsPrefix(id);
		var thePath = uCombine([theDir, sl(), special, sl(), id]);
		return FileSystem.exists(thePath);
		#else
		return false;
		#end
		
	}
	
	public static function readDirectoryRecursive(str:String):Array<String>
	{
		var all = _readDirectoryRecursive(str);
		for (i in 0...all.length)
		{
			var f = all[i];
			var stri = uIndexOf(f, str + "/");
			if (stri == 0)
			{
				f = uSubstr(f, uLength(str+"/"), uLength(f));
				all[i] = f;
			}
		}
		return all;
	}
	
	private static function _readDirectoryRecursive(str:String):Array<String>
	{
		#if sys
		if (FileSystem.exists(str) && FileSystem.isDirectory(str))
		{
			var all = FileSystem.readDirectory(str);
			if (all == null) return [];
			var results = [];
			for (thing in all)
			{
				if (thing == null) continue;
				var pathToThing = str + sl() + thing;
				if (FileSystem.isDirectory(pathToThing))
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
		#end
		return [];
	}
	
	public static function sl():String
	{
		return "/";
	}
	
	@:access(haxe.xml.Xml)
	public static inline function copyXml(data:Xml, parent:Xml = null):Xml
	{
		var c:Xml = null;
		if (data.nodeType == Xml.Element)
		{
			c = Xml.createElement(data.nodeName);
			for (att in data.attributes())
			{
				c.set(att, data.get(att));
			}
			for (el in data.elements())
			{
				c.addChild(copyXml(el,c));
			}
		}
		else if(data.nodeType == Xml.PCData)
		{
			c = Xml.createPCData(data.nodeValue);        
		}
		else if(data.nodeType == Xml.CData)
		{
			c = Xml.createCData(data.nodeValue);
		}
		else if(data.nodeType == Xml.Comment)
		{
			c = Xml.createComment(data.nodeValue);
		}
		else if(data.nodeType == Xml.DocType)
		{
			c = Xml.createDocType(data.nodeValue);
		}
		else if(data.nodeType == Xml.ProcessingInstruction)
		{
			c = Xml.createProcessingInstruction(data.nodeValue);
		}
		else if(data.nodeType == Xml.Document)
		{
			c = Xml.createDocument();
			for (el in data.elements())
			{
				c.addChild(copyXml(el,c));
			}
		}
		@:privateAccess c.parent = parent;
		return c;
	}
	
	/*****UTF shims*****/
	
	public static function uCat(a:String, b:String):String
	{
		var sb = new StringBuf();
		sb.add(Std.string(a));
		sb.add(Std.string(b));
		return sb.toString();
	}
	
	public static function uCharAt(str:String, index:Int):String
	{
		#if unifill
		return Unfill.uCharAt(str, index);
		#else
		return str.charAt(index);
		#end
	}
	
	public static function uCombine(arr:Array<String>):String
	{
		var sb = new StringBuf();
		for (str in arr)
		{
			sb.add(Std.string(str));
		}
		return sb.toString();
	}
	
	public static function uExtension(str:String, lowerCase:Bool=false):String
	{
		var i = uLastIndexOf(str, ".");
		var extension = uSubstr(str, i + 1, uLength(str) - (i + 1));
		if (lowerCase)
		{
			extension = extension.toLowerCase();
		}
		return extension;
	}
	
	public static function uIndexOf(str:String, substr:String, ?startIndex:Int):Int
	{
		#if unifill
		return Unifill.uIndexOf(str, substr, startIndex);
		#else
		return str.indexOf(substr, startIndex);
		#end
	}
	
	public static function uLastIndexOf(str:String, value:String, ?startIndex:Int):Int
	{
		#if unifill
		return Unifill.uLastIndexOf(str, value, startIndex);
		#else
		return str.lastIndexOf(value, startIndex);
		#end
	}
	
	public static function uLength(str:String):Int
	{
		#if unifill
		return Unifill.uLength(str);
		#else
		return str.length;
		#end
	}
	
	public static function uSplit(str:String, substr:String):Array<String>
	{
		#if unifill
		return Unifill.uSplit(str, substr);
		#else
		return str.split(substr);
		#end
	}
	
	public static function uSplitReplace(s:String, substr:String, by:String):String
	{
		if (uIndexOf(s, substr) == -1) return s;
		
		var arr = uSplit(s, substr);
		
		if (arr == null || arr.length < 2) return s;
		
		var sb:StringBuf = new StringBuf();
		for (i in 0...arr.length)
		{
			var bit = arr[i];
			sb.add(bit);
			if (i != arr.length - 1)
			{
				sb.add(by);
			}
		}
		
		return sb.toString();
	}
	
	public static function uSubstr(str:String, pos:Int, ?len:Int):String
	{
		#if unifill
		return Unifill.uSubstr(str, pos, len)
		#else
		return str.substr(pos, len);
		#end
	}
	
	public static function uSubstring(str:String, startIndex:Int, ?endIndex:Int):String
	{
		#if unifill
		return Unifill.uSubstring(str, startIndex, endIndex)
		#else
		return str.substring(startIndex, endIndex);
		#end
	}
}