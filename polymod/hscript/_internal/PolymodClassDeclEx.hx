package polymod.hscript._internal;

import hscript.Expr.ClassDecl;

typedef PolymodClassDeclEx =
{
	> ClassDecl,
	/**
	 * Save performance and improve sandboxing by resolving imports at interpretation time.
	 */
	//@:optional var imports:Map<String, Array<String>>;
	@:optional var imports:Map<String, PolymodClassImport>;
	@:optional var pkg:Array<String>;
}

typedef PolymodClassImport = {
	@:optional var name:String;
	@:optional var pkg:Array<String>;
	@:optional var fullPath:String; // pkg.pkg.pkg.name
	@:optional var cls:Class<Dynamic>;
	@:optional var enm:Enum<Dynamic>;
}
