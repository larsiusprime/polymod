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

class JsonHelp
{
	public static function bool(json:Dynamic, field:String, defaultValue:Bool=false):Bool
	{
		var str:String = "";
		if(Reflect.hasField(json,field)) str = Reflect.field(json, field);
		if(str == null || str == "") return defaultValue;
		str = str.toLowerCase();
		if(str == "true") return true;
		return false;
	}

	public static function int(json:Dynamic, field:String, defaultValue:Int=0):Int
	{
		var str:String = "";
		if(Reflect.hasField(json,field)) str = Reflect.field(json, field);
		if(str == null || str == "") return defaultValue;
		var i = Std.parseInt(str);
		if(i == null) return defaultValue;
		return i;
	}

	public static function float(json:Dynamic, field:String, defaultValue:Float=0):Float
	{
		var str:String = "";
		if(Reflect.hasField(json,field)) str = Reflect.field(json, field);
		if(str == null || str == "") return defaultValue;
		var f = Math.NaN;
		try{
			f = Std.parseFloat(str);
		}catch(msg:Dynamic){
			f = Math.NaN;
		}
		if(Math.isNaN(f)) return defaultValue;
		return f;
		
		
	}
	
	 public static function mapStr(json:Dynamic, field:String):Map<String,String>
	{
		var map:Map<String,String> = new Map<String,String>();
		if (json == null || field == "" || field == null) return map;
		var val = null;
		if(Reflect.hasField(json,field)) val = Reflect.field(json, field);
		if(val != null)
		{
			for (field in Reflect.fields(val)){
				var fieldVal = Reflect.field(val, field);
				map.set(field, Std.string(fieldVal));
			}
		}
		return map;
	}

	public static function str(json:Dynamic, field:String, defaultValue:String=""):String
	{
		var str:String = "";
		if(Reflect.hasField(json,field)) str = Reflect.field(json, field);
		if(str == null || str == "") return defaultValue;
		return str;
	}

	public static function arrStr(json:Dynamic, field:String, defaultValue:Array<String>=null):Array<String>
	{
		var val = null;
		if(Reflect.hasField(json,field)) val = Reflect.field(json, field);
		if(val != null && Std.is(val,Array))
		{
			return cast val;
		}
		return defaultValue;
	}
}