package polymod.hscript._internal;

#if hscript
import hscript.Expr.ClassDecl;
import hscript.Expr.FieldDecl;
import polymod.hscript._internal.PolymodScriptClass;

/**
 * A scripted class declaration, with a package declaration, imports, and potentially static fields.
 */
typedef PolymodClassDeclEx =
{
	> ClassDecl,
	/**
	 * Save performance and improve sandboxing by resolving imports at interpretation time.
	 */
	@:optional var imports:Map<String, PolymodClassImport>;
	@:optional var importsToValidate:Map<String, PolymodClassImport>;
	@:optional var pkg:Array<String>;

	@:optional var staticFields:Array<FieldDecl>;
}

/**
 * An imported class or enumeration.
 */
typedef PolymodClassImport = {
	@:optional var name:String;
	@:optional var pkg:Array<String>;
	@:optional var fullPath:String; // pkg.pkg.pkg.name
	@:optional var cls:Class<Dynamic>;
	@:optional var enm:Enum<Dynamic>;
}
#end