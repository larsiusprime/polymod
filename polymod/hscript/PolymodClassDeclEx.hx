package polymod.hscript;

import hscript.Expr.ClassDecl;

typedef ClassDeclEx = {> ClassDecl,
    @:optional var imports:Map<String, Array<String>>;
    @:optional var pkg:Array<String>;
}