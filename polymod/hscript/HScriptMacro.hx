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

import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import polymod.hscript.HScriptable.HScriptParams;
import polymod.hscript.HScriptable.ScriptOutput;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using Lambda;

class HScriptMacro
{
	static function legacyParseParams(classToEvaluate:haxe.macro.Type.ClassType):Array<String>
	{
		if (classToEvaluate == null)
			return [];

		var result = [];

		// Find any classes with the @:hscript annotation on the class itself.
		var scriptable_meta = classToEvaluate.meta.get().find(function(m) return m.name == ":hscript");
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
							// Context.info('Found value for pathName: ${value}', paramField.expr.pos);
							result.pathName = value;
						case EConst(CIdent(value)):
							// Passed an identifier, this means pathName is dynamic.
							// Context.info('Found IDENTIFIER for pathName, that means it is dynamic: ${value}', paramField.expr.pos);
							result.pathNameDynId = value;
						default:
							throw '@:hscript({pathName}) must be a String value.';
					}
				default:
					throw '@:hscript({${paramField.field}}) is an unknown parameter.';
			}
		}
	}

	static function getClassHScriptParams(classToEvaluate:haxe.macro.Type.ClassType):HScriptParams
	{
		var result = new HScriptParams();

		if (classToEvaluate == null)
			return result;

		// Find any classes with the @:hscript annotation on the class itself.
		var scriptable_meta = classToEvaluate.meta.get().find(function(m) return m.name == ":hscript");
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
					// Context.info('New @:hscript detected.', paramFields[0].expr.pos);
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
								Context.error('@:hscript only accepts a single parameter object or a set of context objects.', p.pos);
								return null;
						}
					}).filter(function(p) return p != null));
				default:
					Context.error('The parameters for your @:hscript annotation are incorrect.', params[0].pos);
			}
		}

		return parentParams.copy().merge(result);
	}

	public static macro function build():Array<Field>
	{
		var cls = Context.getLocalClass().get();
		var fields:Array<Field> = Context.getBuildFields();

		var constructor_setup:Array<Expr> = null;

		var classParams = getClassHScriptParams(cls);

		// Find all fields with @:hscript metadata
		for (field in fields)
		{
			var scriptable_meta = field.meta.find(function(m) return m.name == ":hscript");
			if (scriptable_meta != null)
			{
				switch field.kind
				{
					case FFun(func):
						// The variables we'll set on the hscript scope:
						var variable_names:Array<String> = [];

						// Get the full @:hscript parameters.
						var hscriptParams:HScriptParams = getFunctionHScriptParams(scriptable_meta.params, classParams);

						// Also the direct function arguments
						for (arg in func.args)
							variable_names.push(arg.name);

						// Also the variables specified by the class and its parents
						for (v in hscriptParams.context)
							variable_names.push(v);

						// Now prepend the code to execute the hscript to the
						// function body. Store it in a variable called script_result.
						// If the return type is specified Void, don't return
						// anything. Otherwise, return the script_result.
						var setters:Array<Expr> = variable_names.map(function(name)
						{
							return macro script.set($v{name}, $i{name});
						});

						// Get the original script's return expression.
						// Defaults to `return script_result` unless you return in your function body.
						var return_expr = switch func.ret
						{
							case TPath({name: "Void", pack: [], params: []}):
								// Function sigture says Void, don't return anything
								macro null;
							default:
								macro return script_result;
						}

						var pathName = field.name;
						if (polymod.util.DefineUtil.getDefineBoolRaw('POLYMOD_USE_NAMESPACE'))
						{
							var module:String = Context.getLocalModule();
							module = StringTools.replace(module, ".", "/");
							pathName = $v{module + "/" + pathName};
						}

						// If pathName is a string, set it.
						if (hscriptParams.pathName != null)
						{
							// Context.info('Using path: ${hscriptParams.pathName}', field.pos);
							pathName = hscriptParams.pathName;
						}

						// If pathName is an identifier, call the function or access the variable.
						var scriptFetchExpr = macro _polymod_scripts.get($v{pathName}, Assets);

						if (hscriptParams.pathNameDynId != null)
						{
							// Context.info('Using path (identifier): ${hscriptParams.pathNameDynId}', field.pos);
							scriptFetchExpr = macro
								{
									if (Reflect.isFunction($i{hscriptParams.pathNameDynId}))
									{
										var pathName = Reflect.callMethod(this, cast $i{hscriptParams.pathNameDynId}, []);
										_polymod_scripts.get(pathName, Assets);
									}
									else
									{
										_polymod_scripts.get(cast $i{hscriptParams.pathNameDynId}, Assets);
									}
								}
						}

						// Alter the function body:
						var hscriptCancellable:Bool = hscriptParams.cancellable == null ? HScriptParams.CANCELLABLE_DEFAULT : hscriptParams.cancellable;
						var hscriptOptional:Bool = hscriptParams.optional == null ? HScriptParams.OPTIONAL_DEFAULT : hscriptParams.optional;
						var hscriptRunBefore:Bool = hscriptParams.runBefore == null ? HScriptParams.RUN_BEFORE_DEFAULT : hscriptParams.runBefore;
						func.expr = macro
							{
								$b{hscriptRunBefore ? [func.expr] : []};

								var script_error:Dynamic = null;
								var script_result:Dynamic = null;
								// Initialize as empty rather than null.
								var script_variables:Map<String, Dynamic> = new Map<String, Dynamic>();
								var wasCancelled:Bool = false;
								try
								{
									var script = $e{scriptFetchExpr};

									if (script == null)
									{
										if ($v{!hscriptOptional})
										{
											// We failed to find the script!
											// But we only care about that if the script is not optional.
											polymod.Polymod.error(polymod.Polymod.PolymodErrorCode.SCRIPT_NOT_FOUND,
												'The script ' + $v{pathName} + ' could not be found.');

											// Prevent the script and the function body from executing.
											wasCancelled = true;
										}
										else
										{
											polymod.Polymod.debug('The script '
												+ $v{pathName} + ' could not be found, but that is fine because it is optional.');

											// Prevent the script from running but do not prevent the function body from executing.
											// wasCancelled = true;
										}
									}

									if (script != null && !wasCancelled)
									{
										if (script != null)
										{
											$b{setters};
										}

										if ($v{hscriptCancellable})
										{
											script.set('cancel', function()
											{
												polymod.Polymod.debug('Script called cancel()');
												wasCancelled = true;
											});
										}

										var output = script.execute();
										script_result = output.script_result;
										script_variables = output.script_variables;
									}
								}
								catch (e:Dynamic)
								{
									polymod.Polymod.error(polymod.Polymod.PolymodErrorCode.SCRIPT_EXCEPTION,
										"Error: script " + $v{pathName} + " threw:\n" + e);
									script_error = e;
								}

								if (!$v{hscriptRunBefore} && !wasCancelled)
								{
									${func.expr};
								}

								$return_expr;
							}

						// Generate the expression that will get inserted into the constructor
						// to load this script:
						if (constructor_setup == null)
						{
							constructor_setup = [macro _polymod_scripts = new polymod.hscript.HScriptable.ScriptRunner()];
						}
						constructor_setup.push(macro
							{
								polymod.Polymod.debug("Loading hscript " + $v{pathName});
								_polymod_scripts.load($v{pathName}, Assets);
							});

					default:
						Context.error("Error: The @:hscript meta is only allowed on functions", field.pos);
				}
			}
		}

		// No @:hscript fields found? Just return now...
		if (constructor_setup == null)
			return fields;
		// Inject _polymod_scripts var
		for (new_field in (macro class Ignore
			{
				public var _polymod_scripts:polymod.hscript.HScriptable.ScriptRunner;
			}).fields)
			fields.push(new_field);
		// Find constructor, and inject script setup...
		var constructor = fields.find(function(field) return field.name == "new");
		if (constructor == null)
			Context.error("Error: @:hscript requires a constructor", Context.currentPos());
		switch constructor.kind
		{
			case FFun(func):
				func.expr = macro
					{
						$b{constructor_setup};
						${func.expr};
					}
			default:
				Context.error("Error: constructor is not a function?!", Context.currentPos());
		}
		return fields;
	}
}
