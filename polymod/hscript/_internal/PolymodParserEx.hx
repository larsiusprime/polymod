package polymod.hscript._internal;

#if hscript
import hscript.Parser;
import polymod.util.DefineUtil;

class PolymodParserEx extends Parser
{
	public function new()
	{
		super();

		preprocesorValues = DefineUtil.getDefines();
		allowJSON = true;
		allowTypes = true;
		allowMetadata = true;
	}
}
#end
