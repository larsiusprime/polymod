package polymod.hscript._internal;

#if hscript
import EReg;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.rtti.CType.Abstractdef;
import haxe.rtti.Meta;
import polymod.util.MacroUtil;

using StringTools;
using haxe.macro.Tools;

class PolymodScriptMacro
{
	public static macro function listAbstracts():ExprOf<Map<String, Class<Dynamic>>>
	{
		if (!onGenerateCallbackRegistered)
		{
			onGenerateCallbackRegistered = true;
			Context.onGenerate(onGenerate);
		}
		return macro polymod.hscript._internal.PolymodScriptMacro.fetchAbstracts();
	}

	public static macro function listScriptOverrides():ExprOf<Map<String, Class<Dynamic>>>
	{
		if (!onGenerateCallbackRegistered)
		{
			onGenerateCallbackRegistered = true;
			Context.onGenerate(onGenerate);
		}
		return macro polymod.hscript._internal.PolymodScriptMacro.fetchScriptOverrides();
	}

	#if macro
	static var onGenerateCallbackRegistered:Bool = false;

	static function onGenerate(types:Array<Type>):Void
	{
		var abstracts:Array<Expr> = [];

		for (type in types)
		{
			switch (type)
			{
				case TAbstract(t, _):
					if (t.toString() != "flixel.util.FlxColor")
						continue;

					var abstractPath = t.toString();
					var abstractClass = t.get();

					var implementationPath = abstractClass.impl.toString();
					var implementationClass = abstractClass.impl.get();

					var metaData = [macro $v{abstractPath}, macro $v{implementationPath}];

					abstracts.push(macro $a{metaData});
				default:
					continue;
			}
		}

		var macroClass = MacroUtil.getClassType('polymod.hscript._internal.PolymodScriptMacro');
		macroClass.meta.add('abstracts', abstracts, Context.currentPos());
		macroClass.meta.add('scriptOverrides', scriptOverrides, Context.currentPos());
	}

	// classes to exclude
	static final excludes:Array<String> = [
		// basic classes: cannot extend basic class
		'Array', 'Std', 'String', 'Reflect', 'Sys', 'Date', 'EReg', 'Type', 'Math', 'Xml', 

		// compile errors on cpp: cannot open include file
		'haxe.EnumTools', 'haxe.EnumValueTools',

		// compile errors
		'cpp',

		// some additional necessities
		'polymod.hscript._internal.PolymodScriptClass',
	];
	static var scriptOverrides:Array<Expr> = [];
	public static function buildScriptImpls(?filters:Array<String>):Void
	{
		// if no filters are given
		// create a scripted implementation
		// for every class
		filters = filters ?? [''];
		
		Context.onAfterTyping((modules) -> {
			for (m in modules)
			{
				var cls:ClassType = switch (m)
				{
					case TClassDecl(c):
						var cls = c.get();

						var exclude:Bool = false;
						for (f in excludes)
							if (isInFilter(cls, f))
								exclude = true;
						if (exclude)
							continue;

						if (cls.name.endsWith(PolymodScriptClass.SCRIPT_IMPL_SUFFIX))
							continue;

						var inFilter:Bool = false;
						for (f in filters)
							if (isInFilter(c.get(), f))
								inFilter = true;
						if (!inFilter)
							continue;

						cls;
					default:
						continue;
				}

				if (cls.isFinal || cls.isPrivate || cls.isInterface)
					continue;

				if (cls.meta.has(':coreApi'))
					continue;

				switch (cls.kind)
				{
					case KAbstractImpl(_):
						continue;
					case KGenericBuild | KGeneric:
						continue;
					case KGenericInstance(_, _):
						continue;
					default:
				}

				var fields:Array<Field> = (macro class
					{
						private var __scriptClass__:Null<polymod.hscript._internal.PolymodScriptClass> = null;
						private var __skipScriptClass__:Bool = false;
					}).fields;

				var classFields:Array<ClassField> = [];
				var classParams:Array<{name: String, type: ComplexType}> = [];
				var clsToCheck:Null<ClassType> = cls;
				while (clsToCheck != null)
				{
					for (i => p in clsToCheck.superClass?.params ?? [])
					{
						var name = clsToCheck.superClass.t.get().params[i].name;
						if (classParams.filter((cp) -> cp.name == name).length == 0)
							classParams.push({
								name: name,
								type: p.toComplexType()
							});
					}

					for (f in clsToCheck.fields.get())
					{
						if (classFields.filter((cf) -> cf.name == f.name).length > 0)
							continue;
						classFields.push(f);
					}
					clsToCheck = clsToCheck.superClass?.t.get();
				}

				for (f in classFields)
				{
					switch (f.kind)
					{
						case FMethod(k):
							switch (k)
							{
								case MethNormal:
								default:
									continue;
							}
						default:
							continue;
					}

					if (f.isFinal)
						continue;

					// skip generic function implementations
					if (f.meta.has(':generic') && f.params.length == 0)
						continue;

					var fun:{
						args:Array<{t:Type, opt: Bool, name:String}>, 
						ret:Type
					} = switch (f.type)
					{
						case TFun(args, ret):
							{args: args, ret: ret};
						default:
							continue;
					}

					var funDecl:Null<TFunc> = switch (f.expr()?.expr)
					{
						case TFunction(tfunc):
							tfunc;
						default:
							null;
					}

					var params:Array<TypeParamDecl> = [
						for (p in f.params)
						{
							{
								name: p.name,
								constraints: switch (p.t.getClass().kind)
								{
									case KTypeParameter(cs):
										[for (c in cs) c.toComplexType()];
									default:
										throw 'This should never happen';
								}
							};
						}
					];

					var args:Array<FunctionArg> = [
						for (i => a in fun.args)
						{
							var t = a.t?.toComplexType();

							if (a.t != null)
							{
								switch(a.t)
								{
									case TType(dt, params):
										var type = dt.get();
										var tc = type.type.toComplexType();
										switch (tc)
										{
											case TPath(p):
												if (p.params != null)
												{
													for (i => tp in params)
													{
														for (j in 0...p.params.length)
														{
															switch (p.params[j])
															{
																case TPType(t):
																	if (t.toString() == type.params[i].name)
																		p.params[j] = TPType(tp.toComplexType());
																default:
															}
														}
													}
												}
												tc = TPath(p);
											default:
										}
										t = tc;
									default:
								}
							}

							t = deparameterizeType(t, classParams);

							try 
							{
								t?.toType();
							} 
							catch (_) // overriding functions using private types is not possible
							{
								if (t.toString() != 'StdTypes.Void')
								{
									switch (t)
									{
										case TPath(p):
											if (params.filter((tp) -> tp.name == p.name).length == 0)
											{
												try
												{
													var name = p.name;
													if (p.pack.length > 0)
														name = p.pack.join('.') + '.' + name;
													if (p.sub != null)
														name = name + '.' + p.sub;
													Context.getType(name);
												}
												catch (_) // this happens for private types
												{
													break;
												}
											}
										default:
									}
								}
							}
							// get default value expr
							var value = funDecl?.args[i].value != null ? Context.getTypedExpr(funDecl.args[i].value) : null;

							// wrap the expr in a cast statement
							// necessary for abstracts to work properly
							if (value != null)
								value = (macro cast($e{value}));

							{
								name: a.name,
								type: t,
								value: value
							};
						}
					];

					if (args.length != fun.args.length) 
						continue;

					var scriptArgs:Array<Expr> = [
						for (a in fun.args)
							macro $i{a.name}
					];

					var superArgs:String = [
						for (a in fun.args)
							a.name
					].join(', ');

					var ret = fun.ret.toComplexType();

					if (ret != null)
						ret = deparameterizeType(ret, classParams);

					// we have to decuce the return type
					// when the return type is of an import
					// that is using `as`
					var deduceRet:Bool = try 
					{
						ret.toType();
						false;
					} 
					catch (_) 
					{
						true;
					}

					var body = if (ret?.toString() == 'StdTypes.Void') 
					{
						macro 
						{
							if (!__skipScriptClass__ && __scriptClass__?.findFunction($v{f.name}) != null)
							{
								__skipScriptClass__ = true;
								__scriptClass__.callFunction($v{f.name}, $a{scriptArgs});
								return;
							} 
							else 
							{
								__skipScriptClass__ = false;
								${Context.parse('super.${f.name}(${superArgs})', Context.currentPos())};
								return;
							}
						};
					} 
					else 
					{
						macro
						{
							if (!__skipScriptClass__ && __scriptClass__?.findFunction($v{f.name}) != null)
							{
								__skipScriptClass__ = true;
								return __scriptClass__.callFunction($v{f.name}, $a{scriptArgs});
							}
							else
							{
								__skipScriptClass__ = false;
								return ${Context.parse('super.${f.name}(${superArgs})', Context.currentPos())};
							}
						};
					}

					var access = [AOverride];
					access.push(f.isPublic ? APublic : APrivate);

					fields.push({
						name: f.name,
						kind: FFun({
							args: args,
							ret: deduceRet == false ? ret : null,
							params: params,
							expr: body
						}),
						access: access,
						pos: Context.currentPos(),
					});
				}

				var params:Array<TypeParamDecl> = [
					for (p in cls.params)
					{
						{
							name: p.name,
							constraints: switch (p.t.getClass().kind)
							{
								case KTypeParameter(cs):
									[for (c in cs) c.toComplexType()];
								default:
									throw 'This should never happen';
							}
						};
					}
				];

				var mod = cls.module.split('.');

				var superClass:TypePath = {
					pack: cls.pack,
					name: mod[mod.length - 1],
					sub: cls.name,
					params: [
						for (p in params)
							TPType(TPath({pack: [], name: p.name})) 
					]
				};

				Context.defineModule(cls.module, [{
					pack: cls.pack,
					name: cls.name + PolymodScriptClass.SCRIPT_IMPL_SUFFIX,
					kind: TDClass(superClass, [], false, false, false),
					fields: fields,
					params: params,
					meta: [
						{name: ':keep', pos: Context.currentPos()},
						{name: ':haxe.warning', params: [macro '-WDeprecated'], pos: Context.currentPos()},
					],
					pos: Context.currentPos()
				}]);

				var clsPath = cls.name;
				if (cls.pack.length > 0)
					clsPath = '${cls.pack.join('.')}.${cls.name}';

				var scriptOverride = [
					macro $v{clsPath},
					macro $v{clsPath + PolymodScriptClass.SCRIPT_IMPL_SUFFIX}
				];
				scriptOverrides.push(macro $a{scriptOverride});
			}
		});
	}

	static function deparameterizeType(type:ComplexType, replaceParams:Array<{name:String, type:ComplexType}>):ComplexType
	{
		if (type == null)
			return type;

		switch (type)
		{
			case TPath(p):
				for (rp in replaceParams.filter((rp) -> rp.name == p.name))
				{
					return rp.type;
				}

				for (i => tp in p.params)
				{
					switch (tp)
					{
						case TPType(t):
							p.params[i] = TPType(deparameterizeType(t, replaceParams));
						default:
					}
				}

				return TPath(p);
			case TFunction(args, ret):
				for (i => a in args)
				{
					args[i] = deparameterizeType(a, replaceParams);
				}

				ret = deparameterizeType(ret, replaceParams);

				return TFunction(args, ret);
			case TOptional(t):
				return TOptional(deparameterizeType(t, replaceParams));
			case TParent(t):
				return TParent(deparameterizeType(t, replaceParams));
			case TNamed(n, t):
				return TNamed(n, deparameterizeType(t, replaceParams));
			default:
		}
		return type;
	}

	static function isInFilter(cls:ClassType, filter:String):Bool
	{
		if (filter == '')
			return true;

		var split = filter.split('.');

		var filterType = 'package';

		for (s in split)
			if (s.charAt(0).toUpperCase() == s.charAt(0) && s.charAt(0) != '_')
				filterType = filterType == 'package' ? 'module' : 'class';

		var pattern = '^$filter(\\.|$)';
		var regex = new EReg(pattern, '');

		switch (filterType)
		{
			case 'package':
				return regex.match(cls.pack.join('.'));
			case 'module':
				return regex.match(cls.module);
			case 'class':
				return (cls.module + '.' + cls.name) == filter;
			default:
				throw 'how';
		}
	}
	#end

	public static function fetchAbstracts():Map<String, Class<Dynamic>>
	{
		var meta = Meta.getType(PolymodScriptMacro);

		if (meta.abstracts == null)
			throw 'Did not find "abstracts" meta field in "PolymodScriptMacro"';

		var abstracts:Map<String, Class<Dynamic>> = [];
		for (elm in meta.abstracts)
		{
			if (elm.length != 2)
				throw 'Malformed element in "abstracts" meta field: $elm';

			var abstractPath = elm[0];
			var implementationPath = elm[1];

			#if js
			// Fucked up workaround, volatile and could break at any moment.
			// Sanitize just in case someone tries to exploit this.
			var invalidName = ~/[^.a-zA-Z0-9]/;
			var sanitizedName = invalidName.replace(clsName, '');
			var parsedName = StringTools.replace(sanitizedName, '.', '_');
			var implementation:Class<Dynamic> = cast js.Syntax.code('eval({0})', parsedName);
			#else
			var implementation:Class<Dynamic> = cast Type.resolveClass(implementationPath);
			#end

			if (implementation == null)
				throw 'Could not resolve $abstractPath';

			abstracts.set(abstractPath, implementation);
		}

		return abstracts;
	}

	public static function fetchScriptOverrides():Map<String, Class<Dynamic>>
	{
		var meta = Meta.getType(PolymodScriptMacro);

		if (meta.scriptOverrides == null)
			throw 'Did not find "scriptOverrides" meta field in "PolymodScriptMacro"';

		var scriptOverrides:Map<String, Class<Dynamic>> = [];
		for (elm in meta.scriptOverrides)
		{
			if (elm.length != 2)
				throw 'Malformed element in "scriptOverrides" meta field: $elm';

			var clsPath = elm[0];
			var scriptPath = elm[1];

			var scriptCls:Class<Dynamic> = cast Type.resolveClass(scriptPath);

			if (scriptCls == null)
				throw 'Could not resolve $scriptPath';

			scriptOverrides.set(clsPath, scriptCls);
		}

		return scriptOverrides;
	}
}
#end