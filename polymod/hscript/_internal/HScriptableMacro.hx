package polymod.hscript._internal;

import haxe.macro.Context;
import haxe.macro.Expr;
import polymod.hscript.HScriptable.HScriptParams;
using Lambda;
using haxe.macro.ComplexTypeTools;
using haxe.macro.ExprTools;
using haxe.macro.TypeTools;

class HScriptableMacro
{

	public static macro function build():Array<Field>
	{
		var cls:haxe.macro.Type.ClassType = Context.getLocalClass().get();
		var fields:Array<Field> = Context.getBuildFields();

		// If the class already has `@:hscriptProcessed` on it, we don't need to do anything.
		var alreadyProcessed_metadata = cls.meta.get().find(function(m) return m.name == ':hscriptProcessed');

		// TODO: Add check if the class is an HScriptedClass as well, and throw an error if it is.

		if (alreadyProcessed_metadata == null)
		{
			Context.info('HScriptable: Class ' + cls.name + ' ready to process...', Context.currentPos());

			// Process @:hscript({}) annotations.
			fields = buildHScriptFields(cls, fields);

			// Ensure unused scripted classes are still available to initialize in scripts.
			// SORRY, DCE gets run before this, so we can't use the @:keep metadata.
			cls.meta.add(":hscriptProcessed", [], cls.pos);
			return fields;
		}
		else
		{
			// Returning null is equal to "don't do anything".
			return null;
		}
	}

	static function legacyParseParams(classToEvaluate:haxe.macro.Type.ClassType):Array<String>
	{
		if (classToEvaluate == null)
			return [];

		var result = [];

		// Find any classes with the @:hscript annotation on the class itself.
		var scriptable_meta = classToEvaluate.meta.get().find(function(m) return m.name == ':hscript');
		if (scriptable_meta != null)
		{
			for (p in scriptable_meta.params)
			{
				switch p.expr
				{
					case EConst(CIdent(name)):
						result.push(name);
					default:
						throw 'LEGACY Error: Only identifiers (like Std, Math, myVariable, etc) are allowed in @:hscript(), got "${p.toString()}"';
				}
			}
		}

		return result;
	}

	static function parseParamObjectFields(paramFields:Array<ObjectField>, result:HScriptParams)
	{
		for (paramField in paramFields)
		{
			switch (paramField.field)
			{
				case 'context':
					// Parse the list of context items.
					switch (paramField.expr.expr)
					{
						case EArrayDecl(contextItems):
							for (contextItem in contextItems)
							{
								switch contextItem.expr
								{
									case EConst(CIdent(name)):
										result.mergeContext([name]);
									case EField(e, field):
										throw 'Error: Only constant identifiers (like Std, Math, myVariable, etc) are allowed in @:hscript({context}). Got "${contextItem.toString()}", which is a field access.';
									case EArray(e1, e2):
										throw 'Error: Only constant identifiers (like Std, Math, myVariable, etc) are allowed in @:hscript({context}). Got "${contextItem.toString()}", which is an array access.';
									case EBinop(op, e1, e2):
										throw 'Error: Only constant identifiers (like Std, Math, myVariable, etc) are allowed in @:hscript({context}). Got "${contextItem.toString()}", which is a binary operator.';
									case EParenthesis(e):
										throw 'Error: Only constant identifiers (like Std, Math, myVariable, etc) are allowed in @:hscript({context}). Got "${contextItem.toString()}", which is an expression wrapped in parens.';
									case EObjectDecl(fields):
										throw 'Error: Only constant identifiers (like Std, Math, myVariable, etc) are allowed in @:hscript({context}). Got "${contextItem.toString()}", which is an object declaration.';
									case EArrayDecl(values):
										throw 'Error: Only constant identifiers (like Std, Math, myVariable, etc) are allowed in @:hscript({context}). Got "${contextItem.toString()}", which is an array declaration.';
									default:
										throw 'Error: Only constant identifiers (like Std, Math, myVariable, etc) are allowed in @:hscript({context}). Got "${contextItem.toString()}"';
								}
							}
						default:
							throw '@:hscript({context}) must be an array of identifiers.';
					}
				case 'cancellable':
					switch (paramField.expr.expr)
					{
						case EConst(CIdent('true')):
							result.cancellable = true;
						case EConst(CIdent('false')):
							result.cancellable = false;
						default:
							throw '@:hscript({cancellable}) must be a Boolean value.';
					}
				case 'optional':
					switch (paramField.expr.expr)
					{
						case EConst(CIdent('true')):
							result.optional = true;
						case EConst(CIdent('false')):
							result.optional = false;
						default:
							throw '@:hscript({optional}) must be a Boolean value.';
					}
				case 'runBefore':
					switch (paramField.expr.expr)
					{
						case EConst(CIdent('true')):
							result.runBefore = true;
						case EConst(CIdent('false')):
							result.runBefore = false;
						default:
							throw '@:hscript({runBefore}) must be a Boolean value.';
					}
				case 'pathName':
					switch (paramField.expr.expr)
					{
						case EConst(CString(value)):
							// Passed a string, this means pathName is constant.
							result.pathName = value;
						case EConst(CIdent(value)):
							// Passed an identifier, this means pathName is dynamic.
							result.pathNameDynId = value;
						default:
							throw '@:hscript({pathName}) must be a String value.';
					}
				default:
					throw '@:hscript({${paramField.field}}) is an unknown parameter.';
			}
		}
	}

	/**
	 * Parse `@:hscript({})` on a class.
	 */
	static function getClassHScriptParams(classToEvaluate:haxe.macro.Type.ClassType):HScriptParams
	{
		var result = new HScriptParams();

		if (classToEvaluate == null)
			return result;

		// Find any classes with the @:hscript annotation on the class itself.
		var scriptable_meta = classToEvaluate.meta.get().find(function(m) return m.name == ':hscript');
		if (scriptable_meta != null)
		{
			// Get variables names from inside @:hscript(...) and add them to the list to pass to scripts.
			var hscriptObjectRaw = scriptable_meta.params[0];
			switch (hscriptObjectRaw.expr)
			{
				case EObjectDecl(paramFields):
					parseParamObjectFields(paramFields, result);
				case EConst(CIdent(name)):
					result.mergeContext(legacyParseParams(classToEvaluate));
				default:
					throw 'The parameters for your @:hscript annotation are incorrect.';
			}
		}
		// Resolve any parent classes.
		if (classToEvaluate.superClass != null && classToEvaluate.superClass.t != null)
		{
			// Recursion!
			var parentParams = getClassHScriptParams(classToEvaluate.superClass.t.get());
			result = parentParams.merge(result);
		}
		// Resolve any interfaces.
		if (classToEvaluate.interfaces != null && classToEvaluate.interfaces.length > 0)
		{
			for (iface in classToEvaluate.interfaces)
			{
				// Recursion!
				var parentParams = getClassHScriptParams(iface.t.get());
				result = parentParams.merge(result);
			}
		}

		return result;
	}

	static function getFunctionHScriptParams(params:Null<Array<Expr>>, parentParams:HScriptParams):HScriptParams
	{
		var result = new HScriptParams();

		var hscriptObjectRaw = params[0];

		if (hscriptObjectRaw != null)
		{
			switch hscriptObjectRaw.expr
			{
				case EObjectDecl(paramFields):
					// New and preferred syntax. Pass in a parameter object.
					parseParamObjectFields(paramFields, result);
				case EConst(CIdent(name)):
					// Legacy support. Allow passing context as a set of parameters.
					result.mergeContext(params.map(function(p)
					{
						switch (p.expr)
						{
							case EConst(CIdent(name)):
								return name;
							default:
								Context.error('@:hscript only accepts a single parameter object or a set of context objects.', Context.currentPos());
								return null;
						}
					}).filter(function(p) return p != null));
				default:
					Context.error('The parameters for your @:hscript annotation are incorrect.', Context.currentPos());
			}
		}

		return parentParams.copy().merge(result);
	}
}
