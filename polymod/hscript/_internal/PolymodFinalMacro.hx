package polymod.hscript._internal;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

class PolymodFinalMacro
{
  public static function getAllFinals():Map<String, Array<String>>
  {
    return Reflect.callMethod(null, Reflect.field(Type.resolveClass("polymod.hscript._internal.PolymodFinals"), "getAllFinals"), []);
  }

  public static macro function locateAllFinals():Void
  {
    Context.onAfterTyping((types) ->
    {
      if (calledBefore)
        return;

      var allFinals:Map<String,Array<String>> = [];

      for (type in types)
      {
        switch (type)
        {
          case TClassDecl(t):
            var classType:ClassType = t.get();
            var className:String = t.toString();
            if (classType.isInterface) continue;

            allFinals.set(className, []);
            for (field in classType.statics.get())
            {
              if (!field.isFinal) continue;
              allFinals[className].push(field.name);
            }

          default:
            continue;
        }
      }

      Context.defineModule('polymod.hscript._internal.PolymodFinalMacro', [
        {
          pack: ['polymod', 'hscript', '_internal'],
          name: 'PolymodFinals',
          kind: TypeDefKind.TDClass(null, [], false, false, false),
          fields: [
            {
              name: 'getAllFinals',
              access: [Access.APublic, Access.AStatic],
              kind: FieldType.FFun(
                {
                  args: [],
                  ret: (macro :Map<String, Array<String>>),
                  expr: macro
                  {
                    return $v{allFinals};
                  }
                }),
              pos: Context.currentPos()
            }
          ],
          pos: Context.currentPos()
        }
      ]);

      calledBefore = true;
    });
  }

  #if macro
  static var calledBefore:Bool = false;
  #end
}
