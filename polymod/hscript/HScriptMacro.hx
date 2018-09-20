package polymod.hscript;

import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;

using Lambda;

class HScriptMacro
{
  public static macro function build():Array<Field>
  {
    var cls = Context.getLocalClass().get();
    var fields:Array<Field> = Context.getBuildFields();

    var constructor_setup:Array<Expr> = null;

    // Find all fields with @:hscript metadata
    for (field in fields)
    {
      var scriptable_meta = field.meta.find(function(m) return m.name==":hscript");
      if (scriptable_meta!=null)
      {
        switch field.kind
        {
          case FFun(func):

            // The variables we'll set on the hscript scope:
            var variable_names:Array<String> = [];
           
            // Get variables names from inside @:hscript(...)
            for (p in scriptable_meta.params) switch p.expr
            {
              case EConst(CIdent(name)): variable_names.push(name);
              default: Context.error("Error: Only identifiers (like Std, Math, myVariable, etc) are allowed in @:hscript()", p.pos);
            }

            // Also the function arguments
            for (arg in func.args) variable_names.push(arg.name);

            // Now prepend the code to execute the hscript to the
            // function body. Store it in a variable called script_result.
            // If the return type is specified Void, don't return
            // anything. Otherwise, return the script_result.
            var setters:Array<Expr> = variable_names.map(function(name)
            {
              return macro script.set($v{ name }, $i{ name });
            });

            var return_expr = switch func.ret
            {
              case TPath({ name:"Void", pack:[], params:[] }):
                // Function sigture says Void, don't return anything
                macro null;
              default:
                macro return script_result;
            }

            // Alter the function body:
            func.expr = macro
            {
              var script_error:Dynamic = null;
              var script_result:Dynamic = null;
              try
              {
                var script = _polymod_scripts.get($v{ field.name });
                #if POLYMOD_DEBUG if (script==null) throw "Did not find hscript: "+$v{ field.name }; #end
                $b{ setters };
                script_result = script.execute();
              }
              catch (e:Dynamic)
              {
                #if POLYMOD_DEBUG trace("Error: script "+$v{ field.name }+" threw:\n"+e); #end
                script_error = e;
              }
              ${ func.expr };
              $return_expr;
            }

            // Generate the expression that will get inserted into the constructor
            // to load this script:
            if (constructor_setup==null)
            {
              constructor_setup = [ macro _polymod_scripts = new polymod.hscript.HScriptable.ScriptRunner() ];
            }
            constructor_setup.push(macro
            {
              #if POLYMOD_DEBUG trace("Polymod: Loading hscript "+$v{ field.name }); #end
              _polymod_scripts.load($v{ field.name }, Assets.getText("data/"+$v{ field.name }+".txt"));
            });

          default: Context.error("Error: The @:hscript meta is only allowed on functions", field.pos);
        }
      }
    }

    // No @:hscript fields found? Just return now...
    if (constructor_setup==null) return fields;

    // Inject _polymod_scripts var
    for (new_field in (macro
      class Ignore
      {
        public var _polymod_scripts:polymod.hscript.HScriptable.ScriptRunner;
      }
    ).fields) fields.push(new_field);

    // Find constructor, and inject script setup...
    var constructor = fields.find(function(field) return field.name=="new");
    if (constructor==null) Context.error("Error: @:hscript requires a constructor", Context.currentPos());

    switch constructor.kind
    {
      case FFun(func):
        func.expr = macro
        {
          $b{ constructor_setup };
          ${ func.expr };
        }
      default: Context.error("Error: constructor is not a function?!", Context.currentPos());
    }

    return fields;
  }
}

