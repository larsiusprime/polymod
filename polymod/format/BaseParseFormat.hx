package polymod.format;

class  BaseParseFormat<T>
{
    public var format:TextFileFormat;
    public function parse(str:String):T { return null; }
    public function append(baseText:String, mergeText:String):String { return baseText; }
    public function merge(baseText:String, mergeText:String):String { return baseText; }
    public function print(data:T):String { return null; }
}