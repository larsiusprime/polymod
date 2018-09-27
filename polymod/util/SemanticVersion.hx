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

package polymod.util;

class SemanticVersion
{
	/**
	 * Expects a string of the format "1.2.3", "1.2.3-blah", "1.2.3-alpha.1.blah.2", etc
	 * @param str 
	 * @return SemanticVersion
	 */
	public static function fromString(str:String):SemanticVersion
	{
		var v = new SemanticVersion();
		v.original = str;
		if(str == "" || str == null) throw "SemanticVersion.hx: string is empty!";
		var extra = "";
        if(str.indexOf("+") != -1)
		{
            var arr = str.split("+");
         	str = arr[0];   
        }
		if(str.indexOf("-") != -1)
		{
			var arr = str.split("-");
			str = arr[0];
			extra = arr[1];
		}
		var arr = str.split(".");
		if(arr.length < 3) throw "SemanticVersion.hx: needs major, minor, and patch versions! :\""+str+"\"";
		for(ii in 0...arr.length)
		{
			var substr = arr[ii];
			if(substr.length > 1 && substr.charAt(0) == "0")
			{
				throw "SemanticVersion.hx: no leading zeroes allowed! :\""+str+"\"";
			}
			for(i in 0...substr.length)
			{
				var char:String = substr.charAt(i);
				switch(char)
				{
					case "0","1","2","3","4","5","6","7","8","9","*":
						//donothing, fine
					default:
						var word = switch(ii){
							case 0: "major";
							case 1: "minor";
							case 2: "patch";
							default: "";
						}
						throw "SemanticVersion.hx: couldn't parse " + word + " version! :\""+str+"\"";
				}
			}
		}
		var maj:Null<Int> = null;
		var min:Null<Int> = null;
		var pat:Null<Int> = null;
		if(arr[0] == "*") maj = -1;
		if(arr[1] == "*") min = -1;
		if(arr[2] == "*") pat = -1;
		if(maj == null) maj = Std.parseInt(arr[0]);
		if(min == null) min = Std.parseInt(arr[1]);
		if(pat == null) pat = Std.parseInt(arr[2]);
		if(maj == null) throw "SemanticVersion.hx: couldn't parse major version! :\""+str+"\"";
		if(min == null) throw "SemanticVersion.hx: couldn't parse minor version! :\""+str+"\"";
		if(pat == null) throw "SemanticVersion.hx: couldn't parse patch version! :\""+str+"\"";

		if(maj == -1)
		{
			min = -1;
			pat = -1;
		}
		if(min == -1)
		{
			pat = -1;
		}

		v.major = maj;
		v.minor = min;
		v.patch = pat;
		v.preRelease = [];

		if(maj == -1 || min == -1 || pat == -1)
		{
			extra = "";
		}

		if(extra != null && extra != "")
		{
            if(maj > 1) throw "SemanticVersion.hx: pre-release version not allowed post 1.0.0! :\""+str+"\"";
            if(maj == 1){
                if(min > 0) throw "SemanticVersion.hx: pre-release version not allowed post 1.0.0! :\""+str+"\"";
                if(pat > 0) throw "SemanticVersion.hx: pre-release version not allowed post 1.0.0! :\""+str+"\"";
            }
			var arr = extra.split(".");
			if(arr != null && arr.length > 0)
			{
				for(substr in arr)
				{
					var i = Std.parseInt(substr);
					if(i != null)
					{
						if(substr.length > 0 && substr.charAt(0) == "0")
						{
							throw "SemanticVersion.hx: no leading zeroes allowed! :\""+str+"\"";
						}
					}
					v.preRelease.push(substr);
				}
			}
		}
		v.effective = v.major + "." + v.minor + "." + v.patch;
		if(v.preRelease != null && v.preRelease.length > 0){
			v.effective = (v.effective + "-" + v.preRelease.join("."));
		}
        return v;
	}
	
	public var original:String;
	public var effective:String;
	public var major:Int;
	public var minor:Int;
	public var patch:Int;
	public var preRelease:Array<String>;
	
    public function new(){}
    
	/**
	 * Compare version numbers and return compatibility score
	 * @param newer version to check against
	 * @return Int 3:match major/minor/patch, 2:match major/minor, 1:match major, 0:incompatible
	 */
	public function checkCompatibility(newer:SemanticVersion):Int
	{
		var score = 0;
		if(newer.major == major || newer.major == -1 || major == -1)
		{
			score++;
			if(newer.minor >= minor || newer.minor == -1 || minor == -1)
			{
				score++;
				if(newer.patch >= patch || newer.patch == -1 || patch == -1)
				{
					score++;
				}
			}
		}
        return score;
	}
    
    private function compare(other:SemanticVersion):Int
    {
		if(major == -1 || other.major == -1) return 0;
		if(major > other.major) return -1;
        if(major < other.major) return  1;
		if(minor == -1 || other.minor == -1) return 0;
		if(minor > other.minor) return -1;
        if(minor < other.minor) return  1;
		if(patch == -1 || other.patch == -1) return 0;
		if(patch > other.patch) return -1;
        if(patch < other.patch) return  1;
        var bits  = preRelease.length;
        var otherBits = other.preRelease.length;
        if(otherBits > bits) bits = otherBits;
		for(i in 0...bits){
			var bit = (preRelease != null && preRelease.length > i ) ? preRelease[i] : "";
			var otherBit = (other.preRelease != null && other.preRelease.length > i) ? other.preRelease[i] : "";
        	if(bit == "" && otherBit != "") return -1;
        	if(bit != "" && otherBit == "") return  1;
			var i = Std.parseInt(bit);
        	var j = Std.parseInt(otherBit);
        	if(i != null && j != null)
            {
                if(i > j) return -1;
                if(i < j) return  1;
            }
        	else
            {
                if(bit > otherBit) return -1;
                if(bit < otherBit) return  1;
            }
		}
    	return 0;
    }
	
	public function isEqualTo(other:SemanticVersion):Bool
	{
        return compare(other) == 0;
    }
	
	public function isNewerThan(other:SemanticVersion):Bool
	{
		return compare(other) == -1;
	}

	public function toString():String
	{
		return effective;
	}
}