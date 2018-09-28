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
 
package polymod.hscript;

import hscript.*;
import hscript.Expr;

// This interface triggers this build macro on any implementing classes
@:autoBuild(polymod.hscript.HScriptMacro.build())
interface HScriptable { }

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
}