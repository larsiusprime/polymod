package polymod.hscript._internal;

import hscript.Expr;
import hscript.Printer;

class PolymodPrinterEx extends Printer
{
	public static function errorExToString(e:PolymodExprEx.ErrorEx)
	{
		var message = switch (#if hscriptPos e.e #else e #end)
		{
			case EInvalidChar(c): "Invalid character: '" + (StringTools.isEof(c) ? "EOF" : String.fromCharCode(c)) + "' (" + c + ")";
			case EUnexpected(s): "Unexpected token: \"" + s + "\"";
			case EUnterminatedString: "Unterminated string";
			case EUnterminatedComment: "Unterminated comment";
			case EInvalidPreprocessor(str): "Invalid preprocessor (" + str + ")";
			case EUnknownVariable(v): "Unknown variable: " + v;
			case EInvalidIterator(v): "Invalid iterator: " + v;
			case EInvalidOp(op): "Invalid operator: " + op;
			case EInvalidAccess(f): "Invalid access to field " + f;
			case EInvalidModule(m): "Invalid module: " + m;
			case EBlacklistedModule(m): "Blacklisted module: " + m;
			case EInvalidInStaticContext(v): "Invalid field access from static context: " + v;
			case EInvalidScriptedFnAccess(f): "Invalid function access to scripted class: " + f;
			case EInvalidScriptedVarGet(v): "Invalid variable retrieval to scripted class: " + v;
			case EInvalidScriptedVarSet(v): "Invalid variable assignment to scripted class: " + v;
			case EInvalidFinalSet(f): "Invalid final field assignment: " + f;
			case EClassSuperNotCalled: "Super constructor not called";
			case EClassUnresolvedSuperclass(c, r): 'Unresolved superclass $c (reason: $r)';
			// TODO: Do we need to distinguish these?
			case EScriptCallThrow(v): "Script threw an exception: \n" + v;
			case EScriptThrow(v): "Script threw an exception: \n" + v;
			case ECustom(msg): msg;
		};
		#if hscriptPos
		return e.origin + ":" + e.line + ": " + message;
		#else
		return message;
		#end
	}

	public function modulesToString(m:Array<ModuleDecl>)
	{
		var output:String = "";
		if (m.length == 0) return output;

		// Order the modules by priority (see hscript.Expr.ModuleDecl).
		m.sort(function(a:ModuleDecl, b:ModuleDecl)
		{
			var orderA:Int = Type.enumIndex(a);
			var orderB:Int = Type.enumIndex(b);

			return orderA == orderB ? 0 : orderA > orderB ? 1 : -1;
		});

		// Stringify every ModuleDecl.
		for (module in m)
		{
			switch (module)
			{
				case DPackage(path):
					output += "package " + path.join(".") + ";";

				case DImport(path, star, name):
					output += "import " + path.join(".");
					if ((star ?? false))
					{
						output += ".*";
					}
					else
					{
						if (name != null) output += " as " + name;
					}
					output += ";";

				case DClass(c):
					output += metaToString(c.meta);
					output += c.isPrivate ? "private " : "";
					output += c.isExtern ? "extern " : "";
					output += "class " + c.name;
					if (Reflect.fields(c.params).length > 0) output += "<>"; // Once params are actually functional, this should be implemented.
					output += " ";

					if (c.extend != null) output += "extends " + this.typeToString(c.extend) + " ";
					for (imp in c.implement)
					{
						output += "implements " + imp + " ";
					}

					output += "\n{";
					output += classFieldsToString(c.fields);
					output += "}";

				case DTypedef(t):

					output += metaToString(t.meta);
					output += t.isPrivate ? "private " : "";
					output += "typedef " + t.name;
					if (Reflect.fields(t.params).length > 0) output += "<>"; // Once params are actually functional, this should be implemented.
					output += " = " + this.typeToString(t.t);

				case DEnum(e):
					output += "enum " + e.name;
					output += "\n{\n";

					for (fld in e.fields)
					{
						output += fld.name;
						if (fld.args.length > 0)
						{
							output += "(";
							for (i in 0...fld.args.length)
							{
								var arg:EnumArgDecl = fld.args[i];
								output += arg.name + (arg.type != null ? this.typeToString(arg.type) : "");
								if (i < fld.args.length - 1) output += ", ";
							}
							output += ")";
						}
						output += "\n";
					}

					output += "}";
			}

			output += "\n";
		}

		return output;
	}

	function classFieldsToString(fields:Array<FieldDecl>)
	{
		if (fields.length == 0) return "\n";
		var output:String = "\n";
		for (fld in fields)
		{
			output += metaToString(fld.meta);

			for (acc in fld.access)
			{
				switch (acc)
				{
					case APublic: output += "public ";
					case APrivate: output += "private ";
					case AInline: output += "inline ";
					case AOverride: output += "override ";
					case AStatic: output += "static ";
					case AMacro: output += "macro ";
				}
			}

			switch (fld.kind)
			{
				case KFunction(f):
					output += "function " + fld.name + "(";
					for (i in 0...f.args.length)
					{
						var arg:Argument = f.args[i];
						if (arg.opt ?? false) output += "?";
						output += arg.name + this.typeToString(arg.t);
						if (arg.value != null) output += " = " + this.exprToString(arg.value);

						if (i < f.args.length - 1) output += ", ";
					}

					output += ")";
					if (f.ret != null) output += this.typeToString(f.ret);

					output += this.exprToString(f.expr);

				case KVar(v):
					output += "var " + fld.name;
					if (v.get != null || v.set != null)
					{
						output += "(" + (v.get ?? "default") + ", " + (v.set ?? "default") + ")";
					}

					if (v.type != null) output += this.typeToString(v.type);
					if (v.expr != null) output += " = " + this.exprToString(v.expr);
					output += ";";
			}

			output += "\n";
		}

		return output;
	}

	function metaToString(meta:Metadata)
	{
		if (meta.length == 0) return "";

		var output:String = "";
		for (m in meta)
		{
			output += "@" + m.name;
			if (m.params != null)
			{
				output += "(";
				for (i in 0...m.params.length)
				{
					var param:Expr = m.params[i];
					output += this.exprToString(param);
					if (i < m.params.length - 1) output += ", ";
				}
				output += ")";
			}
			output += "\n";
		}

		return output;
	}
}
