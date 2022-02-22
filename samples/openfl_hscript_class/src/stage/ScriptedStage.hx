package stage;

import polymod.hscript.HScriptable;

@:hscriptClass
class ScriptedStage extends Stage implements HScriptable
{
}
/*
	```
	class BasicStage extends Stage {
	  public override function create():Void {
	super.create();
	// Do custom stuff...
	  }
	}
	```

	var currentStage:Stage = ScriptedStage.init('BasicStage', []);
 */
