package polymod.hscript;

import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import polymod.hscript.HScriptable.HScriptParams;
import polymod.hscript.HScriptable.ScriptOutput;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
using Lambda;

class HScriptMacro
{
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
							// Context.info('Found value for pathName: ${value}', Context.currentPos());
							result.pathName = value;
						case EConst(CIdent(value)):
							// Passed an identifier, this means pathName is dynamic.
							// Context.info('Found IDENTIFIER for pathName, that means it is dynamic: ${value}', Context.currentPos());
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
					// Context.info('New @:hscript detected.', Context.currentPos());
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

	public static macro function build():Array<Field>
	{
		var cls:haxe.macro.Type.ClassType = Context.getLocalClass().get();
		var fields:Array<Field> = Context.getBuildFields();

		var alreadyProcessed_metadata = cls.meta.get().find(function(m) return m.name == ':hscriptProcessed');

		if (alreadyProcessed_metadata == null)
		{
			Context.info('HScriptable: Class ' + cls.name + ' ready to process...', Context.currentPos());

			// Process @:hscriptClass({}) annotations.
			fields = buildHScriptClass(cls, fields);
			// Process @:hscript({}) annotations.
			fields = buildHScriptFields(cls, fields);

			cls.meta.add(":hscriptProcessed", [], cls.pos);

			return fields;
		}
		else
		{
			// Context.info('HScriptable: Class ' + cls.name + ' already processed, skipping...', Context.currentPos());
			return null;
		}
	}

	public static function buildHScriptFields(cls:haxe.macro.Type.ClassType, fields:Array<Field>):Array<Field>
	{
		var constructor_setup:Array<Expr> = null;
		var classParams = getClassHScriptParams(cls);

		// Find all fields with @:hscript metadata
		for (field in fields)
		{
			if (field.meta == null)
				continue;
			var scriptable_meta = field.meta.find(function(m) return m.name == ':hscript');
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
							case TPath({name: 'Void', pack: [], params: []}):
								// Function sigture says Void, don't return anything
								macro null;
							default:
								macro return script_result;
						}

						var pathName = field.name;
						if (polymod.util.DefineUtil.getDefineBoolRaw('POLYMOD_USE_NAMESPACE'))
						{
							var module:String = Context.getLocalModule();
							module = StringTools.replace(module, '.', '/');
							pathName = $v{'$module/$pathName'};
						}

						// If pathName is a string, set it.
						if (hscriptParams.pathName != null)
						{
							// Context.info('Using path: ${hscriptParams.pathName}', Context.currentPos());
							pathName = hscriptParams.pathName;
						}

						// If pathName is an identifier, call the function or access the variable.
						var scriptFetchExpr = macro _polymod_scripts.get($v{pathName}, Assets);

						if (hscriptParams.pathNameDynId != null)
						{
							// Context.info('Using path (identifier): ${hscriptParams.pathNameDynId}', Context.currentPos());
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
						var hscriptDynamicPath:Bool = hscriptParams.pathNameDynId != null;
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
									polymod.Polymod.error(polymod.Polymod.PolymodErrorCode.SCRIPT_EXCEPTION, 'Error: script ' + $v{pathName} + ' threw:\n$e');
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
						if (!hscriptDynamicPath)
						{
							constructor_setup.push(macro
								{
									// polymod.Polymod.debug('Loading hscript ' + $v{pathName});
									_polymod_scripts.load($v{pathName}, Assets);
								});
						}

					default:
						Context.error("Error: The @:hscript meta is only allowed on functions", Context.currentPos());
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
		var constructor = fields.find(function(field) return field.name == 'new');
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

	/**
	 * Parse `@:hscriptClass({})`. Don't get this confused!
	 */
	static function parseHScriptClassParams(metaEntry:MetadataEntry):HScriptClassParams
	{
		var result:HScriptClassParams = {};

		switch (metaEntry.params[0].expr)
		{
			case EObjectDecl(paramFields):
				// paramFields
				for (paramField in paramFields)
				{
					switch (paramField.field)
					{
						case 'baseClass':
							switch (paramField.expr.expr)
							{
								case EConst(CIdent(baseClassName)):
									result.baseClass = baseClassName;
								default:
									Context.error("Error: @:hscriptClass baseClass must be a string", Context.currentPos());
							}
							break;
					}
				}
			default:
				Context.error("Error: @:hscriptClass({}) must contain an object", Context.currentPos());
		}

		return result;
	}

	public static function buildHScriptClass(cls:haxe.macro.Type.ClassType, fields:Array<Field>):Array<Field>
	{
		var cls:haxe.macro.Type.ClassType = Context.getLocalClass().get();

		var script_class_meta = cls.meta.get().find(function(m) return m.name == ':hscriptClass');
		if (script_class_meta != null)
		{
			var superCls:haxe.macro.Type.ClassType = cls.superClass.t.get();

			// Create scripted class override for constructor.
			var constructor = fields.find(function(field) return field.name == 'new');

			if (constructor != null)
			{
				Context.error("Error: Constructor already defined for this class", Context.currentPos());
			}
			else
			{
				if (superCls.constructor != null)
				{
					switch (superCls.constructor.get().type)
					{
						case TFun(args, ret):
							// Build a new constructor, which has the same signature as the superclass constructor.
							var constArgs = [
								for (arg in args)
									{name: arg.name, opt: arg.opt, type: Context.toComplexType(arg.t)}
							];
							// Create scripted class utility functions.
							var utilFields:Array<Field> = buildScriptedClassUtils(cls, superCls, constArgs);
							fields = fields.concat(utilFields);
							constructor = buildScriptedClassConstructor(constArgs);
						case TLazy(builder):
							switch (builder())
							{
								case TFun(args, ret):
									// Build a new constructor, which has the same signature as the superclass constructor.
									var constArgs = [
										for (arg in args)
											{name: arg.name, opt: arg.opt, type: Context.toComplexType(arg.t)}
									];
									// Create scripted class utility functions.
									var utilFields:Array<Field> = buildScriptedClassUtils(cls, superCls, constArgs);
									fields = fields.concat(utilFields);
									constructor = buildScriptedClassConstructor(constArgs);
								default:
									Context.error('Error: Lazy superclass constructor is not a function (got ${superCls.constructor.get().type})',
										Context.currentPos());
							}
						default:
							Context.error('Error: super constructor is not a function (got ${superCls.constructor.get().type})', Context.currentPos());
					}
				}
				else
				{
					constructor = buildEmptyScriptedClassConstructor();
					// Create scripted class utility functions.
					var utilFields:Array<Field> = buildScriptedClassUtils(cls, superCls, []);
					fields = fields.concat(utilFields);
				}
				fields.push(constructor);
			}

			// Create scripted class overrides for all fields (except constructor).
			// Create scripted class overrides for non-constructor fields.
			fields = fields.concat(buildScriptedClassFieldOverrides(cls));
		}
		// Else, do nothing.

		return fields;
	}

	static function buildScriptedClassUtils(cls:haxe.macro.Type.ClassType, superCls:haxe.macro.Type.ClassType, superConstArgs:Array<FunctionArg>):Array<Field>
	{
		Context.info('Building scripted class utils', Context.currentPos());
		var clsTypeName:String = cls.pack.join('.') != '' ? '${cls.pack.join('.')}.${cls.name}' : cls.name;
		var superClsTypeName:String = superCls.pack.join('.') != '' ? '${superCls.pack.join('.')}.${superCls.name}' : superCls.name;

		// var _asc:AbstractScriptClass = null;
		var var__asc:Field = {
			name: '_asc',
			doc: "The AbstractScriptClass instance which any variable or function calls are redirected to internally.",
			access: [APrivate], // Private instance variable
			kind: FVar(Context.toComplexType(Context.getType('polymod.hscript.PolymodAbstractScriptClass'))),
			pos: cls.pos,
		};

		// public static function listScriptClasses():Array<String>;
		var function_listScriptClasses:Field = {
			name: 'listScriptClasses',
			doc: "Returns a list of all the scripted classes which extend this class.",
			access: [APublic, AStatic],
			meta: null,
			pos: cls.pos,
			kind: FFun({
				args: [],
				params: null,
				ret: Context.toComplexType(Context.typeof(macro
					{var x:Array<String>; x;})),
				expr: macro
				{
					return polymod.hscript.PolymodScriptClass.listScriptClassesExtending($v{superClsTypeName});
				},
			}),
		};

		// public static function init(clsName:String, ...args):T;
		var constArgs = [for (arg in superConstArgs) macro $i{arg.name}];
		var typePath:haxe.macro.TypePath = {
			pack: cls.pack,
			name: cls.name,
		};
		var function_init:Field = {
			name: 'init',
			doc: "Initializes a scripted class instance using the given scripted class name and constructor arguments.",
			access: [APublic, AStatic],
			meta: null,
			pos: cls.pos,
			kind: FFun({
				args: [{name: 'clsName', type: Context.toComplexType(Context.getType('String'))},].concat(superConstArgs),
				params: null,
				ret: Context.toComplexType(Context.getType(clsTypeName)),
				expr: macro
				{
					polymod.hscript.PolymodScriptClass.scriptClassOverrides.set($v{superClsTypeName}, Type.resolveClass($v{clsTypeName}));

					var asc:polymod.hscript.PolymodAbstractScriptClass = polymod.hscript.PolymodScriptClass.createScriptClassInstance(clsName, $a{constArgs});
					var scriptedObj = asc.superClass;

					Reflect.setField(scriptedObj, '_asc', asc);

					return scriptedObj;
				},
			}),
		};

		return [var__asc, function_listScriptClasses, function_init];
	}

	/**
	 * For each function in the superclass, create a function in the subclass
	 		* that redirects to the internal abstract script class.
	 */
	static function buildScriptedClassFieldOverrides(cls:haxe.macro.Type.ClassType):Array<Field>
	{
		var fieldDone:Array<String> = [];
		var fieldArray:Array<Field> = [];

		var targetClass:haxe.macro.Type.ClassType = cls;
		var mappedParams:Map<String, haxe.macro.Type> = new Map<String, haxe.macro.Type>();
		var tType = Context.getType(cls.name);
		var tClass = Context.toComplexType(tType);

		// Start with a custom implementation of .toString()
		var func_toString:haxe.macro.Expr.Field = buildScriptedClass_toString(targetClass);
		fieldArray.push(func_toString);
		fieldDone.push('toString');

		while (targetClass != null)
		{
			Context.info('Processing overrides for class: ${targetClass.name}<${mappedParams}>', Context.currentPos());
			// Values will be either of type haxe.macro.Expr.Field or Bool. This is because setting a Map value to null removes the key.
			var newFields:Map<String, Dynamic> = buildScriptedClassFieldOverrides_inner(targetClass, mappedParams);
			for (newFieldName => newField in newFields)
			{
				if (Std.isOfType(newField, Bool))
				{
					// Sometimes a child version needs to be skipped but the parent version doesn't.
					// In this case, the parent needs to be skipped also.
					// Example: A child function override can be inline when the parent isn't.
					// Context.info('  Skipping field: ${newFieldName}', Context.currentPos());
					fieldDone.push(newFieldName);
				}
				else
				{
					if (!fieldDone.contains(newFieldName))
					{
						// Context.info('  Registering: ${newFieldName}', Context.currentPos());
						fieldArray.push(newField);
						fieldDone.push(newFieldName);
					}
					else
					{
						// Context.info('  Redundant: ${newField.name}', Context.currentPos());
					}
				}
			}
			// Context.info('Moving on... ${targetClass.superClass}', Context.currentPos());
			if (targetClass.superClass != null)
			{
				var targetParams:Array<haxe.macro.Type> = targetClass.superClass.params;
				targetClass = targetClass.superClass.t.get();
				for (paramIndex in 0...targetClass.params.length)
				{
					var paramType = targetParams[paramIndex];
					var paramName = targetClass.params[paramIndex].name;
					var paramFullName = '${targetClass.pack.join('.')}.${targetClass.name}.${paramName}';
					mappedParams.set(paramFullName, paramType);
				}
			}
			else
			{
				targetClass = null;
			}
		}

		return fieldArray;
	}

	static function buildScriptedClass_toString(cls:haxe.macro.Type.ClassType):Field
	{
		return {
			name: 'toString',
			doc: null,
			access: [APublic, AOverride],
			meta: null,
			pos: cls.pos,
			kind: FFun({
				args: [],
				params: null,
				ret: Context.toComplexType(Context.getType('String')),
				expr: macro
				{
					if (_asc == null)
					{
						var clsName = $v{cls.name};
						var superName = $v{cls.superClass.t.get().name};
						return 'PolymodScriptedClass<${clsName} extends ${superName}>(NO ASC)';
					}
					else
					{
						return _asc.callFunction('toString', []);
					}
				},
			}),
		};
	}

	static function buildScriptedClassFieldOverrides_inner(cls:haxe.macro.Type.ClassType, targetParams:Map<String, haxe.macro.Type>):Map<String, Dynamic>
	{
		// Values will be either of type haxe.macro.Expr.Field or Bool. This is because setting a Map value to null removes the key.
		var fields:Map<String, Dynamic> = new Map<String, Dynamic>();

		// Context.info('Mapping overrides of class: ${cls.name}', Context.currentPos());
		for (field in cls.fields.get())
		{
			// Context.info('Attempting to build instance override: ${field.name}', Context.currentPos());
			if (field.name == 'new')
			{
				// Do nothing
			}
			else
			{
				var results:Array<Field> = overrideField(field, false, targetParams);
				if (results.length == 0)
				{
					fields.set(field.name, false);
				}
				else
				{
					for (result in results)
					{
						fields.set(result.name, result);
					}
				}
			}
		}
		for (field in cls.statics.get())
		{
			// Context.info('  Skipping: ${field.name} is static', Context.currentPos());
		}

		return fields;
	}

	static function overrideField(field:haxe.macro.Type.ClassField, isStatic:Bool, targetParams:Map<String, haxe.macro.Type>,
			?type:haxe.macro.Type = null):Array<Field>
	{
		if (type == null)
		{
			type = field.type;
		}

		switch (type)
		{
			case TLazy(lt):
				// A lazy wrapper for another field.
				// We have to call the function to get the true value.
				var ltv:haxe.macro.Type = lt();
				// Context.info('Lazy field type: ${field}', Context.currentPos());
				return overrideField(field, isStatic, targetParams, ltv);
			// return [];
			case TFun(args, ret):
				// This field is a function of the class.
				// We need to redirect to the scripted class in case our scripted class overrides it.
				// If it isn't overridden, the AbstractScriptClass will call the original function.

				// We need to skip overriding functions which meet the following:
				// 1. One or more argments are private types.
				// 2. The function is an inline function.
				// Neither scripted NOR normal classes can override these functions anyway, so it is safe to skip them.
				// TODO: We are also skipping functions which take Null<Bool> as an argument, since the type building function isn't handling them properly.

				for (arg in args)
				{
					switch (arg.t)
					{
						case TInst(ty, pa):
							var typ = ty.get();
							if (typ.isPrivate)
							{
								// Context.info('  Skipping: "${field.name}" contains private type ${typ.module}.${typ.name}', Context.currentPos());
								return [];
							}
						default:
							// Do nothing.
					}
				}
				switch (field.kind)
				{
					case FMethod(k):
						switch (k)
						{
							case MethInline:
								// Context.info('  Skipping: "${field.name}" is inline function', Context.currentPos());
								return [];
							default:
								// Do nothing.
						}
					default:
						// Do nothing.
				}

				for (fieldMeta in field.meta.get())
				{
					if (fieldMeta.name == ':generic')
					{
						// Context.info('  Skipping: "${field.name}" is marked with @:generic', Context.currentPos());
						return [];
					}
				}

				var func_inputArgs:Array<FunctionArg> = [];

				// We only get limited information about the args from Type, we need to use TypedExprDef.
				switch (field.expr().expr)
				{
					case TFunction(tfunc):
						for (arg in tfunc.args)
						{
							var isOptional = (arg.value != null);
							var tfuncMeta:haxe.macro.Metadata = arg.v.meta.get();
							var tfuncExpr:haxe.macro.Expr = arg.value == null ? null : Context.getTypedExpr(arg.value);
							var tfuncType:haxe.macro.ComplexType = Context.toComplexType(arg.v.t);
							switch (arg.v.t)
							{
								case TInst(ty, params):
									var typ = ty.get();
									if (targetParams.exists(ty.toString()))
									{
										// Argument type is T.
										tfuncType = Context.toComplexType(targetParams.get(ty.toString()));
										// Context.info('  Uses parameter type: ${ty.toString()}, replacing with ${tfuncType}', Context.currentPos());
									}
									else if (params.length != 0)
									{
										for (paramIndex in 0...params.length)
										{
											var param = params[paramIndex];
											switch (param)
											{
												case TInst(pty, ppr):
													if (targetParams.exists(pty.toString()))
													{
														// Argument type is Foobar<T>.
														// Context.info('  Argument type uses parameter ${pty.toString()}, which should be ${targetParams.get(pty.toString())}', Context.currentPos());
														// Okay uhhh we have to mutate the ComplexType.
														tfuncType = Context.toComplexType(arg.v.t.applyTypeParameters(typ.params,
															[targetParams.get(pty.toString())]));
														// func_ret_t = TypeTools.applyTypeParameters(func_ret_t, targetParams.get(pty.toString()));
													}
												default:
													// Nothing.
											}
										}
									}
								default:
									// Nothing.
							}
							var tfuncArg:FunctionArg = {
								name: arg.v.name,
								type: tfuncType,
								// opt: isOptional,
								meta: tfuncMeta,
								value: tfuncExpr,
							};
							func_inputArgs.push(tfuncArg);
						}
					default:
						Context.error('Expected a function and got ${field.expr().expr}', Context.currentPos());
				}

				// Is there a better way to do this?
				var doesReturnVoid:Bool = ret.toString() == "Void";

				// Generate the list of call arguments for the function.
				var func_callArgs:Array<Expr> = [for (arg in args) macro $i{arg.name}];
				var func_access = [field.isPublic ? APublic : APrivate];
				if (field.isFinal)
					func_access.push(AFinal);
				if (isStatic)
				{
					func_access.push(AStatic);
				}
				else
				{
					func_access.push(AOverride);
				}

				// TODO: This breaks if there's a type constraint on the parameter.
				var func_params = [for (param in field.params) {name: param.name}];

				var func_ret = doesReturnVoid ? null : Context.toComplexType(ret);

				switch (ret)
				{
					case TInst(ty, params):
						var typ = ty.get();
						if (targetParams.exists(ty.toString()))
						{
							// Return type is T.
							// Context.info('  Function returns ${ty}, replacing with ${func_ret}', Context.currentPos());
							func_ret = Context.toComplexType(targetParams.get(ty.toString()));
						}
						else if (params.length != 0)
						{
							for (paramIndex in 0...params.length)
							{
								var param = params[paramIndex];
								switch (param)
								{
									case TInst(pty, ppr):
										if (targetParams.exists(pty.toString()))
										{
											// Return type is Foobar<T>.
											// Context.info('  Return type uses parameter ${pty.toString()}, which should be ${targetParams.get(pty.toString())}', Context.currentPos());
											// Okay uhhh we have to mutate the ComplexType.
											func_ret = Context.toComplexType(ret.applyTypeParameters(typ.params, [targetParams.get(pty.toString())]));
											// func_ret_t = TypeTools.applyTypeParameters(func_ret_t, targetParams.get(pty.toString()));
										}
									default:
										// Nothing.
								}
							}
						}
					default:
						// Do nothing.
				}

				var funcName:String = field.name;
				var func_over:Field = {
					name: funcName,
					doc: field.doc == null ? 'Polymod ScriptedClass override of ${field.name}.' : 'Polymod ScriptedClass override of ${field.name}.\n${field.doc}',
					access: func_access,
					meta: field.meta.get(),
					pos: field.pos,
					kind: FFun({
						args: func_inputArgs,
						params: func_params,
						ret: func_ret,
						expr: macro
						{
							var fieldName:String = $v{funcName};
							if (_asc != null)
							{
								// trace('ASC: Calling $fieldName() in macro-generated function...');
								$
								{
									doesReturnVoid ? (macro _asc.callFunction(fieldName,
										[$a{func_callArgs}])) : (macro return _asc.callFunction(fieldName, [$a{func_callArgs}]))
								}
							}
							else
							{
								// Fallback, call the original function.
								// trace('ASC: Fallback to original ${fieldName}');
								$
								{
									doesReturnVoid ? (macro super.$funcName($a{func_callArgs})) : (macro return super.$funcName($a{func_callArgs}))
								}
							}
						},
					}),
				};
				var func_superCall:Field = {
					name: '__super_' + funcName,
					doc: 'Calls the original ${field.name} function while ignoring the ScriptedClass override.',
					access: [APrivate],
					meta: field.meta.get(),
					pos: field.pos,
					kind: FFun({
						args: func_inputArgs,
						params: func_params,
						ret: func_ret,
						expr: macro
						{
							var fieldName:String = $v{funcName};
							// Fallback, call the original function.
							// trace('ASC: Force call to super ${fieldName}');
							$
							{
								doesReturnVoid ? (macro super.$funcName($a{func_callArgs})) : (macro return super.$funcName($a{func_callArgs}))
							}
						},
					}),
				}

				return [func_over, func_superCall];
			case TInst(_t, _params):
				// This field is an instance of a class.
				// Example: var test:TestClass = new TestClass();

				// Originally, I planned to replace all variables on the class with properties,
				// however this is not possible because properties are merely a compile-time feature.

				// However, since scripted classes correctly access the superclass variables anyway,
				// there is no need to override the value.
				// Context.info('Field: Instance variable "${field.name}"', Context.currentPos());
				return [];
			case TEnum(_t, _params):
				// Enum instance
				// Context.info('Field: Enum variable "${field.name}"', Context.currentPos());
				return [];
			case TMono(_t):
				// Monomorph instance
				// https://haxe.org/manual/types-monomorph.html
				// Context.info('Field: Monomorph variable "${field.name}"', Context.currentPos());
				return [];
			case TAnonymous(_t):
				// Context.info('Field: Anonymous variable "${field.name}"', Context.currentPos());
				return [];
			case TDynamic(_t):
				// Context.info('Field: Dynamic variable "${field.name}"', Context.currentPos());
				return [];
			case TAbstract(_t, _params):
				// Context.info('Field: Abstract variable "${field.name}"', Context.currentPos());
				return [];
			default:
				// Context.info('Unknown field type: ${field}', Context.currentPos());
				return [];
		}
	}

	static function buildScriptedClassConstructor(superConstArgs:Array<FunctionArg>):Field
	{
		// var ascArg:FunctionArg = {
		// 	name: '_asc',
		// 	opt: false,
		// 	type: Context.toComplexType(Context.getType('hscript.AbstractScriptClass')),
		// 	value: null,
		// 	meta: null,
		// };

		// var constArgs:Array<FunctionArg> = [ascArg].concat(superConstArgs);
		var constArgs:Array<FunctionArg> = superConstArgs;
		var superCallArgs:Array<Expr> = [for (arg in superConstArgs) macro $i{arg.name}];

		// Context.info('  Generating constructor for scripted class with super(${superCallArgs})', Context.currentPos());

		return {
			name: 'new',
			access: [APrivate],
			pos: Context.currentPos(),
			kind: FFun({
				args: superConstArgs,
				expr: macro
				{
					// Call the super constructor with appropriate args
					super($a{superCallArgs});
				},
			}),
		};
	}

	static function buildEmptyScriptedClassConstructor():Field
	{
		// var ascArg:FunctionArg = {
		// 	name: '_asc',
		// 	opt: false,
		// 	type: Context.toComplexType(Context.getType('hscript.AbstractScriptClass')),
		// 	value: null,
		// 	meta: null,
		// };

		return ({
			name: "new",
			access: [APrivate],
			pos: Context.currentPos(),
			kind: FFun({
				args: [],
				expr: macro
				{
				}
			})
		});
	}
}

typedef HScriptClassParams =
{
	?baseClass:String,
}
