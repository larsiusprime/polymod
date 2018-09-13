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

package polymod.library;

class SemanticVersion
{
	public var original:String;
	public var effective:String;
	public var major:Int;
	public var minor:Int;
	public var patch:Int;
	public var preRelease:Array<String>;
	
    public function new(){}
    
	public function isCompatibleWith(newer:SemanticVersion):Bool
	{
		if(newer.major == major) return true;
        return false;
	}
    
    private function compare(other:SemanticVersion):Int
    {
        if(major > other.major) return -1;
        if(major < other.major) return  1;
		if(minor > other.minor) return -1;
        if(minor < other.minor) return  1;
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

	/**
	 * Expects a string of the format "1.2.3", "1.2.3-blah", "1.2.3-alpha.1.blah.2", etc
	 * @param str 
	 * @return SemanticVersion
	 */
	public static function fromString(str:String):SemanticVersion
	{
		var v = new SemanticVersion();
		v.original = str;
		if(str == "" || str == null) throw "SemanticVersion: string is empty!";
		var extra = "";
        if(str.indexOf("+") != -1){
            var arr = str.split("+");
         	str = arr[0];   
        }
		if(str.indexOf("-") != -1){
			var arr = str.split("-");
			str = arr[0];
			extra = arr[1];
		}
		var arr = str.split(".");
		if(arr.length < 3) throw "SemanticVersion: needs major, minor, and patch versions! :\""+str+"\"";
		for(substr in arr) {
			if(substr.length > 1 && substr.charAt(0) == "0"){
				throw "SemanticVersion: no leading zeroes allowed! : \""+str+"\"";
			}
		}
		var maj = Std.parseInt(arr[0]);
		var min = Std.parseInt(arr[1]);
		var pat = Std.parseInt(arr[2]);
		if(maj == null) throw "SemanticVersion: couldn't parse major version! :\""+str+"\"";
		if(min == null) throw "SemanticVersion: couldn't parse minor version! :\""+str+"\"";
		if(pat == null) throw "SemanticVersion: couldn't parse patch version! :\""+str+"\"";
		v.major = maj;
		v.minor = min;
		v.patch = pat;
		v.preRelease = [];
		if(extra != null && extra != "")
		{
            if(maj > 1) throw "SemanticVersion: pre-release version not allowed post 1.0.0! :\""+str+"\"";
            if(maj == 1){
                if(min > 0) throw "SemanticVersion: pre-release version not allowed post 1.0.0! :\""+str+"\"";
                if(pat > 0) throw "SemanticVersion: pre-release version not allowed post 1.0.0! :\""+str+"\"";
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
							throw "SemanticVersion: no leading zeroes allowed! : \""+str+"\"";
						}
					}
					v.preRelease.push(substr);
				}
			}
		}
		v.effective = v.major + "." + v.minor + "." + v.patch;
		if(v.preRelease != null){
			v.effective += "-" + v.preRelease.join(".");
		}
        return v;
	}
}