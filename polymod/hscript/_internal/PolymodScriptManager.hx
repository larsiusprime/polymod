package polymod.hscript._internal;

#if hscript
import hscript.Expr;
import polymod.hscript._internal.PolymodClassDeclEx;

@:access(hscript.Interp)
class PolymodScriptManager
{
	private static var _instance:PolymodScriptManager = null;
	public static var instance(get, never):PolymodScriptManager;

	static function get_instance():PolymodScriptManager
	{
		if (_instance == null)
				_instance = new PolymodScriptManager();
		return _instance;
	}

	public var importOverrides(default, null):Map<String, Class<Dynamic>>;

	public var defaultImports(default, null):Map<String, Class<Dynamic>>;

	public var abstracts(default, null):Map<String, Class<Dynamic>>;

	public var scriptOverrides(default, null):Map<String, Class<Dynamic>>;

	public var scriptClassDecls(default, null):Map<String, PolymodClassDeclEx>;
	
	private var _staticAccess:PolymodInterpEx;

	private var _staticFunctionDecls:Map<String, FunctionDecl>;

	public function new()
	{
		this.importOverrides = [];
		this.defaultImports = [];
		this.abstracts = PolymodScriptMacro.listAbstracts();
		this.scriptOverrides = PolymodScriptMacro.listScriptOverrides();
		this.scriptClassDecls = [];
		this._staticAccess = new PolymodInterpEx(null);
		this._staticFunctionDecls = [];
	}

	/**
	 * Register a scripted class by parsing the text of that script.
	 */
	public function registerScriptClassByString(body:String, path:String = null):Void
	{
			addModule(body, path == null ? 'hscriptClass' : 'hscriptClass($path)');
	}

	/**
	 * Register a scripted class by retrieving the script from the given path.
	 */
	public function registerScriptClassByPath(path:String):Void
	{
		@:privateAccess {
			var scriptBody = Polymod.assetLibrary.getText(path);
			if (scriptBody == null) 
			{
				Polymod.error(SCRIPT_PARSE_ERROR, 'Error while loading script "${path}", could not retrieve script contents!');
				return;
			}
			try
			{
				registerScriptClassByString(scriptBody, path);
			}
			catch (err:PolymodExprEx.ErrorEx)
			{
				var errLine:String = #if hscriptPos '${err.line}' #else "#???" #end;
				#if hscriptPos
				switch (err.e)
				#else
				switch (err)
				#end
				{
					case EUnexpected(s):
						Polymod.error(SCRIPT_PARSE_ERROR,
								'Error while parsing script ${path}#${errLine}: EUnexpected' + '\n' +
								'Unexpected error: Unexpected token "${s}", is there invalid syntax on this line?');
					default:
						Polymod.error(SCRIPT_PARSE_ERROR, 'Error while executing script ${path}#${errLine}: ' + '\n' + 'An unknown error occurred: ${err}');
				}
			} 
			catch (err:hscript.Expr.Error) 
			{
				var errLine:String = #if hscriptPos '${err.line}' #else "#???" #end;
				#if hscriptPos
				switch (err.e)
				#else
				switch (err)
				#end
				{
					case EUnexpected(s):
						Polymod.error(SCRIPT_PARSE_ERROR,
							'Error while parsing script ${path}#${errLine}: EUnexpected' + '\n' +
							'Unexpected error: Unexpected token "${s}", is there invalid syntax on this line?');
					default:
						Polymod.error(SCRIPT_PARSE_ERROR, 'Error while executing script ${path}#${errLine}: ' + '\n' + 'An unknown error occurred: ${err}');
				}
			}
		}
	}

	#if lime
	public function registerScriptClassByPathAsync(path:String):lime.app.Future<Bool>
	{
		var promise = new lime.app.Promise<Bool>();

		if (!Polymod.assetLibrary.exists(path)) 
		{
			Polymod.error(SCRIPT_PARSE_ERROR, 'Error while loading script "${path}", could not retrieve contents of non-existent script!');
			return null;
		}

		Polymod.assetLibrary.loadText(path).onComplete((text) ->
		{
			try
			{
				Polymod.debug('Fetched script class "$path", parsing...');
				registerScriptClassByString(text);
				promise.complete(true);
			}
			catch (err:PolymodExprEx.ErrorEx)
			{
				var errLine:String = #if hscriptPos '${err.line}' #else "#???" #end;
				#if hscriptPos
				switch (err.e)
				#else
				switch (err)
				#end
				{
					case EUnexpected(s):
						Polymod.error(SCRIPT_PARSE_ERROR,
							'Error while parsing script ${path}#${errLine}: EUnexpected' + '\n' +
							'Unexpected error: Unexpected token "${s}", is there invalid syntax on this line?');
					default:
						Polymod.error(SCRIPT_PARSE_ERROR,
							'Error while parsing script ${path}#${errLine}: ' + '\n' + 'An unknown error occurred: ${err}');
				}
				promise.error(err);
			}
		}).onError((err) ->
		{
			if (err == "404") 
			{
				Polymod.error(SCRIPT_PARSE_ERROR, 'Error while loading script "${path}", could not retrieve script contents (404 error)!');
			} 
			else 
			{
				Polymod.error(SCRIPT_PARSE_ERROR, 'Error while parsing script ${path}: ' + '\n' + 'An unknown error occurred: ${err}');
				promise.error(err);
			}
		});
		// Await the promise
		return promise.future;
	}
	#end

	public function validateImports():Void
	{
		for (clsPath => cls in scriptClassDecls)
		{
			for (other in scriptClassDecls)
			{
				if (other == cls)
					continue;

				var pkg = other.pkg ?? [];

				var importedClass:PolymodClassImport = {
					name: other.name,
					pkg: other.pkg,
					fullPath: (pkg.length > 0) ? '${pkg.join('.')}.${other.name}' : other.name,
					cls: PolymodScriptClass,
					enm: null
				};

				if (pkg.length == 0) 
				{
					if (!cls.imports.exists(other.name))
						cls.imports.set(other.name, importedClass);
				}
				else if (cls.pkg != null && cls.pkg.length >= pkg.length)
				{
					var inSamePkg:Bool = true;
					for (i => subPkg in pkg)
						if (subPkg != cls.pkg[i])
							inSamePkg = false;
					if (inSamePkg)
						cls.imports.set(other.name, importedClass);
				}
			}

			for (key => imp in cls.importsToValidate)
			{
				if (scriptClassDecls.exists(imp.fullPath))
				{
					imp.cls = PolymodScriptClass;
					cls.imports.set(key, imp);
					continue;
				}

				Polymod.error(SCRIPT_CLASS_MODULE_NOT_FOUND, 'Could not import ${imp.fullPath}', clsPath);
			}
		}
	}

	public function listScriptClasses():Array<String>
	{
		var result = [];
		for (key => _ in scriptClassDecls)
			result.push(key);
		return result;
	}

	public function registerScriptClass(c:PolymodClassDeclEx):Void
	{
		var path = c.name;
		if (c.pkg != null)
			path = '${c.pkg.join('.')}.${c.name}';

		if (scriptClassDecls.exists(path))
		{
			var message = 
				'A scripted class with the fully qualified name "$path" has already been defined.' +
				' Please change the class name or the package name to ensure a unique name.';
			Polymod.error(SCRIPT_CLASS_ALREADY_REGISTERED, message);
		}
		else
		{
			for (f in c.staticFields) 
			{
				var fieldPath = '${path}.${f.name}';

				switch (f.kind)
				{
					case KVar(v):
						if (v.expr != null)
							_staticAccess.variables.set(fieldPath, _staticAccess.expr(v.expr));
						else
							_staticAccess.variables.set(fieldPath, null);
					case KFunction(f):
						_staticFunctionDecls.set(fieldPath, f);
				}
			}
			scriptClassDecls.set(path, c);
		}
	}

	public function clearScriptedClasses():Void
	{
		scriptClassDecls.clear();
		_staticFunctionDecls.clear();
		_staticAccess.resetVariables();
	}

	public function instantiateScriptedClass(path:String, ?args:Array<Dynamic>):PolymodScriptClass
	{
		if (args == null)
			args = [];
		return new PolymodScriptClass(scriptClassDecls.get(path), args);
	}

	public function staticFieldExists(path:String, field:String):Bool
	{
		var variableKey = '$path.$field';
		return _staticAccess.variables.exists(variableKey) || _staticFunctionDecls.exists(variableKey);
	}

	public function staticFieldRead(path:String, field:String):Dynamic
	{
		var variableKey = '$path.$field';

		if (_staticAccess.variables.exists(variableKey))
		{
			return _staticAccess.variables.get(variableKey);
		} 
		else if (_staticFunctionDecls.exists(variableKey))
		{
			var fn = _staticFunctionDecls.get(variableKey);
			var nargs = fn.args != null ? fn.args.length : 0;
			switch (nargs)
			{
				case 0: return staticCallFunction0.bind(path, field);
				case 1: return staticCallFunction1.bind(path, field, _);
				case 2: return staticCallFunction2.bind(path, field, _, _);
				case 3: return staticCallFunction3.bind(path, field, _, _, _);
				case 4: return staticCallFunction4.bind(path, field, _, _, _, _);
				#if neko
				default: @:privateAccess _staticAccess.error(ECustom('only 4 params allowed in script class functions'));
				#else
				case 5: return staticCallFunction5.bind(path, field, _, _, _, _, _);
				case 6: return staticCallFunction6.bind(path, field, _, _, _, _, _, _);
				case 7: return staticCallFunction7.bind(path, field, _, _, _, _, _, _, _);
				case 8: return staticCallFunction8.bind(path, field, _, _, _, _, _, _, _, _);
				default: @:privateAccess _staticAccess.error(ECustom('only 8 params allowed in script class functions'));
				#end
			}
		}

		Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'The scripted class "$path" does not have $field.');
		return null;
	}

	public function staticFieldWrite(path:String, field:String, value:Dynamic):Dynamic
	{
		var variableKey = '$path.$field';
		if (!_staticAccess.variables.exists(variableKey))
		{
			Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'The scripted class "$path" does not have $field.');
			return null;
		}
		_staticAccess.variables.set(variableKey, value);
		return value;
	}

	public function staticCallFunction(path:String, fnName:String, ?args:Array<Dynamic>):Dynamic
	{
		var variableKey = '$path.$fnName';

		var r = null;
		var fn = _staticFunctionDecls.get(variableKey);
		args = args ?? [];

		if (fn == null)
		{
			Polymod.error(SCRIPT_RUNTIME_EXCEPTION, 'The scripted class "$path" does not have $fnName.');
			return null;
		}

		var prev:Map<String, Dynamic> = [];
		for (i => a in fn.args)
		{
			prev.set(a.name, _staticAccess.variables.get(a.name));

			if (i < args.length)
				_staticAccess.variables.set(a.name, args[i]);
			else if (a.value != null)
				_staticAccess.variables.set(a.name, _staticAccess.expr(a.value));
		}

		r = _staticAccess.executeEx(fn.expr);

		for (k => v in prev)
			_staticAccess.variables.set(k, v);

		return r;
	}

	private function addModule(moduleContents:String, ?origin:String = "hscript")
	{
		var parser = new PolymodParserEx();
		var decls = parser.parseModule(moduleContents, origin);
		registerModules(decls, origin);
	}

	private function registerModules(module:Array<ModuleDecl>, ?origin:String = "hscript")
	{
		var pkg:Array<String> = null;
		var imports:Map<String, PolymodClassImport> = [];
		var importsToValidate:Map<String, PolymodClassImport> = [];

		for (importPath in defaultImports.keys())
		{
			var splitPath = importPath.split(".");
			var clsName = splitPath[splitPath.length - 1];

			imports.set(clsName, {
				name: clsName,
				pkg: splitPath.slice(0, splitPath.length - 1),
				fullPath: importPath,
				cls: defaultImports.get(importPath),
			});
		}

		for (decl in module)
		{
			switch (decl)
			{
				case DPackage(path):
					pkg = path;
				case DImport(path, _):
					var clsName = path[path.length - 1];

					if (imports.exists(clsName))
					{
						if (imports.get(clsName) == null) {
							Polymod.error(SCRIPT_CLASS_MODULE_BLACKLISTED, 'Scripted class ${clsName} is blacklisted and cannot be used in scripts.', origin);
						} else {
							Polymod.warning(SCRIPT_CLASS_MODULE_ALREADY_IMPORTED, 'Scripted class ${clsName} has already been imported.', origin);
						}
						continue;
					}

					var importedClass:PolymodClassImport = {
						name: clsName,
						pkg: path.slice(0, path.length - 1),
						fullPath: path.join("."),
						cls: null,
						enm: null
					};

					if (importOverrides.exists(importedClass.fullPath)) 
					{
						// importOverrides can exist but be null (if it was set to null).
						// If so, that means the class is blacklisted.

						importedClass.cls = importOverrides.get(importedClass.fullPath);
					} 
					else if (abstracts.exists(importedClass.fullPath)) 
					{
						// We used a macro to map each abstract to its implementation.
						importedClass.cls = abstracts.get(importedClass.fullPath);
						trace('RESOLVED ABSTRACT CLASS ${importedClass.fullPath} -> ${Type.getClassName(importedClass.cls)}');
						trace(Type.getClassFields(importedClass.cls));
					} 
					else 
					{
						var resultCls:Class<Dynamic> = Type.resolveClass(importedClass.fullPath);

						// If the class is not found, try to find it as an enum.
						var resultEnm:Enum<Dynamic> = null;
						if (resultCls == null)
							resultEnm = Type.resolveEnum(importedClass.fullPath);

						if (resultCls == null && resultEnm == null) 
						{
							importsToValidate.set(importedClass.name, importedClass);
							continue;
						} 
						else if (resultCls != null) 
						{
							importedClass.cls = resultCls;
						} 
						else if (resultEnm != null) 
						{
							importedClass.enm = resultEnm;
						}
					}

					imports.set(importedClass.name, importedClass);
				case DClass(c):
					var extend = c.extend;
					if (extend != null)
					{
						var superClassPath = new hscript.Printer().typeToString(extend);
						if (!imports.exists(superClassPath) && !importsToValidate.exists(superClassPath)) 
						{
							switch (extend) 
							{
								case CTPath(path, params):
									if (params != null && params.length > 0)
										Polymod.error(SCRIPT_PARSE_ERROR, 'do not include type parameters in super class name: ${superClassPath}', origin);
								default:
							}
							Polymod.error(SCRIPT_PARSE_ERROR, 'not recognized, is the type imported?: ${superClassPath}', origin);
						}

						if (imports.exists(superClassPath) || importsToValidate.exists(superClassPath))
						{
							var extendImport = imports.get(superClassPath);
							if (extendImport != null && extendImport.cls == null)
								Polymod.error(SCRIPT_PARSE_ERROR, 'expected a class: ${superClassPath}', origin);

							switch (extend)
							{
								case CTPath(_, params):
									extend = CTPath((imports.get(superClassPath) ?? importsToValidate.get(superClassPath)).fullPath.split('.'), params);
								case _:
							}
						}
					}

					var instanceFields = [];
					var staticFields = [];
					for (f in c.fields)
					{
						if (f.access.contains(AStatic)) {
							staticFields.push(f);
						} else {
							instanceFields.push(f);
						}
					}

					var classDecl:PolymodClassDeclEx = {
						imports: imports,
						importsToValidate: importsToValidate,
						pkg: pkg,
						name: c.name,
						params: c.params,
						meta: c.meta,
						isPrivate: c.isPrivate,
						extend: extend,
						implement: c.implement,
						fields: instanceFields,
						isExtern: c.isExtern,
						staticFields: staticFields,
					};
					registerScriptClass(classDecl);
				case DTypedef(_):
			}
		}
	}

	private inline function staticCallFunction0(path:String, fnName:String):Dynamic
	{
		return staticCallFunction(path, fnName);
	}

	private inline function staticCallFunction1(path:String, fnName:String, arg0:Dynamic):Dynamic
	{
		return staticCallFunction(path, fnName, [arg0]);
	}

	private inline function staticCallFunction2(path:String, fnName:String, arg0:Dynamic, arg1:Dynamic):Dynamic
	{
		return staticCallFunction(path, fnName, [arg0, arg1]);
	}

	private inline function staticCallFunction3(path:String, fnName:String, arg0:Dynamic, arg1:Dynamic, arg2:Dynamic):Dynamic
	{
		return staticCallFunction(path, fnName, [arg0, arg1, arg2]);
	}

	private inline function staticCallFunction4(path:String, fnName:String, arg0:Dynamic, arg1:Dynamic, arg2:Dynamic, arg3:Dynamic):Dynamic
	{
		return staticCallFunction(path, fnName, [arg0, arg1, arg2, arg3]);
	}

	#if !neko
	private inline function staticCallFunction5(path:String, fnName:String, arg0:Dynamic, arg1:Dynamic, arg2:Dynamic, arg3:Dynamic, arg4:Dynamic):Dynamic
	{
		return staticCallFunction(path, fnName, [arg0, arg1, arg2, arg3, arg4]);
	}

	private inline function staticCallFunction6(path:String, fnName:String, arg0:Dynamic, arg1:Dynamic, arg2:Dynamic, arg3:Dynamic, arg4:Dynamic, arg5:Dynamic):Dynamic
	{
		return staticCallFunction(path, fnName, [arg0, arg1, arg2, arg3, arg4, arg5]);
	}

	private inline function staticCallFunction7(path:String, fnName:String, arg0:Dynamic, arg1:Dynamic, arg2:Dynamic, arg3:Dynamic, arg4:Dynamic, arg5:Dynamic, arg6:Dynamic):Dynamic
	{
		return staticCallFunction(path, fnName, [arg0, arg1, arg2, arg3, arg4, arg5, arg6]);
	}

	private inline function staticCallFunction8(path:String, fnName:String, arg0:Dynamic, arg1:Dynamic, arg2:Dynamic, arg3:Dynamic, arg4:Dynamic, arg5:Dynamic, arg6:Dynamic, arg7:Dynamic):Dynamic
	{
		return staticCallFunction(path, fnName, [arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7]);
	}
	#end
}
#end