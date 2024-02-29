package polymod.hscript._internal;

#if hscript
import hscript.Parser;

class PolymodParserEx extends Parser
{
	#if (hscript > "2.5.0")
	public override function parseModule(content:String, ?origin:String = "hscript", ?position = 0)
	#else
	public override function parseModule(content:String, ?origin:String = "hscript")
	#end
	{
		#if (hscript > "2.5.0")
		return super.parseModule(content, origin, position);
		#else
		return super.parseModule(content, origin);
		#end
	}
}
#end
