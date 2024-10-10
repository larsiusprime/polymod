package polymod.hscript._internal;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Type.ClassType;
import polymod.util.MacroUtil;
#end

import haxe.rtti.Meta;

/**
 * Provides a macro which, after types are generated, populates a list of classes which extend `polymod.hscript.HScriptedClass`.
 * We have to do weird shenanigans to make the data accessible at runtime though.
 */
class PolymodScriptClassMacro {
	/**
	 * Returns a `Map<String, Class<Dynamic>>` which maps superclass paths to scripted classes.
     * So `class ScriptedStage extends Stage implements HScriptable` will be `"Stage" -> ScriptedStage`
	 */
	public static macro function listHScriptedClasses():ExprOf<Map<String, Class<Dynamic>>> {
		if (!onGenerateCallbackRegistered)
		{
		  onGenerateCallbackRegistered = true;
		  haxe.macro.Context.onGenerate(onGenerate);
		}

		return macro polymod.hscript._internal.PolymodScriptClassMacro.fetchHScriptedClasses();
	}

	#if macro
  static var onGenerateCallbackRegistered:Bool = false;

  static function onGenerate(allTypes:Array<haxe.macro.Type>) {
    // Reset these, since onGenerate persists across multiple builds.
	  var hscriptedClassType:ClassType = MacroUtil.getClassType('polymod.hscript.HScriptedClass');
    var hscriptedClasses:Array<ClassType> = [];

	  for (type in allTypes) {
		  switch (type) {
			  // Class instances
			  case TInst(t, _params):
			    var classType:ClassType = t.get();
					var classPath:String = '${classType.pack.join(".")}.${classType.name}';

			    if (classType.isInterface) {
    				// Ignore interfaces.
	    		} else if (MacroUtil.implementsInterface(classType, hscriptedClassType)) {
				    hscriptedClasses.push(classType);
						Context.info('${classPath} implements HScriptedClass? YEAH', Context.currentPos());
				  } else { }
			  // Other types (things like enums)
			  default:
			    continue;
		  }
		}

    var entries:Array<Expr> = [];

    for (hscriptedClass in hscriptedClasses) {
      var classPath:String = '${hscriptedClass.pack.join(".")}.${hscriptedClass.name}';

      // TODO: Do we need to parameterize?
      var superClass:Null<ClassType> = hscriptedClass.superClass != null ? hscriptedClass.superClass.t.get() : null;

      if (superClass == null) throw 'No superclass for ' + classPath;

			var superClassPath:String = '${superClass.pack.join(".")}.${superClass.name}';
			var entryData = [
          macro $v{superClassPath},
					// TODO: How do we do reification to get a class?
          macro $v{classPath}
      ];
      entries.push(macro $a{entryData});
    }

    var polymodScriptClassClassType:ClassType = MacroUtil.getClassType('polymod.hscript._internal.PolymodScriptClass');
    polymodScriptClassClassType.meta.add('hscriptedClasses', entries, Context.currentPos());

		polymodScriptClassClassType.meta.add('hello', [macro $v{'world'}], Context.currentPos());
	}
	#end

	public static function fetchHScriptedClasses():Map<String, Class<Dynamic>> {
		var metaData = Meta.getType(PolymodScriptClass);

    trace('Got metaData: ' + metaData);

		if (metaData.hscriptedClasses != null) {
      trace('Got hscriptedClasses: ' + metaData.hscriptedClasses);

			var result:Map<String, Class<Dynamic>> = [];

			// Each element is formatted as `[superClassPath, classPath]`.

			for (element in metaData.hscriptedClasses) {
        if (element.length != 2) {
          throw 'Malformed element in hscriptedClasses: ' + element;
        }

        var superClassPath:String = element[0];
        var classPath:String = element[1];
				var classType:Class<Dynamic> = cast Type.resolveClass(classPath);
        result.set(superClassPath, classType);
      }

			return result;
		} else {
			throw 'No hscriptedClasses found in PolymodScriptClass!';
		}
	}
}
