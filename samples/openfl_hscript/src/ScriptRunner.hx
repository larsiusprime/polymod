import hscript.*;
import hscript.Expr;

class ScriptRunner
{
    private var scripts:Map<String, Script>;
    private var parser:Parser;

    public function new()
    {
        parser = new Parser();
        scripts = new Map<String, Script>();
	}

    public function load(name:String,source:String):Script
    {
        var script = new Script(source);
        scripts.set(name, script);
        return script;
    }

    public function get(name:String):Script
    {
        return scripts.get(name);
    }

    public function execute(name:String):Dynamic
    {
        if(!scripts.exists(name)) return null;
        var script = scripts.get(name);
        return script.execute();
    }

    public function executeWithVars(name:String, vars:Map<String,Dynamic>):Dynamic
    {
        if(!scripts.exists(name)) return null;
        var script = scripts.get(name);
        return script.executeWithVars(vars);
    }
}

class Script
{
    public var program:Expr;
    public var interp:Interp;
    private static var parser:Parser;
    
    public function new(script:String)
    {
        if(parser == null)
        {
            parser = new Parser();
            parser.allowTypes = true;
        }
        program = parser.parseString(script);
        interp = new Interp();
    }

    public function set(key:String, value:Dynamic)
    {
        interp.variables.set(key, value);
    }

    public function execute():Dynamic
    {
        return interp.execute(program);
    }

    public function executeWithVars(vars:Map<String,Dynamic>):Dynamic
    {
        for(key in vars.keys())
        {
            interp.variables.set(key,vars.get(key));
            vars.set(key,vars.get(key));
        }
        return interp.execute(program);
    }

}