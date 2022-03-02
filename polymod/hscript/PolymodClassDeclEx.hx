package polymod.hscript;

import hscript.Expr.ClassDecl;

typedef PolymodClassDeclEx =
{
	> ClassDecl,
	@:optional var imports:Map<String, Array<String>>;
	@:optional var pkg:Array<String>;
}
