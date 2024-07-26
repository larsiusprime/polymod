package polymod.hscript._internal;

@:forward
@:access(polymod.hscript._internal.PolymodScriptClass)
abstract PolymodAbstractScriptClass(PolymodScriptClass) from PolymodScriptClass
{
	private function resolveField(name:String):Dynamic
	{
		switch (name)
		{
			case "superClass":
				return this.superClass;
			case "createSuperClass":
				return this.createSuperClass;
			case "findFunction":
				return this.findFunction;
			case "callFunction":
				return this.callFunction;
			case _:
				if (this.findFunction(name) != null)
				{
					var fn = this.findFunction(name);
					var nargs = 0;
					if (fn.args != null)
					{
						nargs = fn.args.length;
					}
					switch (nargs)
					{
						case 0: return this.callFunction0.bind(name);
						case 1: return this.callFunction1.bind(name, _);
						case 2: return this.callFunction2.bind(name, _, _);
						case 3: return this.callFunction3.bind(name, _, _, _);
						case 4: return this.callFunction4.bind(name, _, _, _, _);
						#if neko
						case _: @:privateAccess this._interp.error(ECustom("only 4 params allowed in script class functions (.bind limitation)"));
						#else
						case 5: return this.callFunction5.bind(name, _, _, _, _, _);
						case 6: return this.callFunction6.bind(name, _, _, _, _, _, _);
						case 7: return this.callFunction7.bind(name, _, _, _, _, _, _, _);
						case 8: return this.callFunction8.bind(name, _, _, _, _, _, _, _, _);
						case _: @:privateAccess this._interp.error(ECustom("only 8 params allowed in script class functions (.bind limitation)"));
						#end
					}
				}
				else if (this.findVar(name) != null)
				{
					var v = this.findVar(name);

					var varValue:Dynamic = null;
					if (this._interp.variables.exists(name) == false)
					{
						if (v.expr != null)
						{
							varValue = this._interp.expr(v.expr);
							this._interp.variables.set(name, varValue);
						}
					}
					else
					{
						varValue = this._interp.variables.get(name);
					}
					return varValue;
				}
				else if (this.superClass == null) {
					throw "field '" + name + "' does not exist in script class '" + this.className + "'";
				} else if (Type.getClass(this.superClass) == null) {
					// Anonymous structure
					if (Reflect.hasField(this.superClass, name)) {
						return Reflect.field(this.superClass, name);
					} else {
						throw "field '" + name + "' does not exist in script class '" + this.className + "' or super class '"
							+ Type.getClassName(Type.getClass(this.superClass)) + "'";
					}
				} else if (Std.isOfType(this.superClass, PolymodScriptClass)) {
					// PolymodScriptClass
					var superScriptClass:PolymodAbstractScriptClass = cast(this.superClass, PolymodScriptClass);
					try
					{
						return superScriptClass.fieldRead(name);
					}
					catch (e:Dynamic)
					{
					}
				} else {
					// Class object
					var fields = Type.getInstanceFields(Type.getClass(this.superClass));
					if (fields.contains(name) || fields.contains('get_$name')) {
						return Reflect.getProperty(this.superClass, name);
					} else {
						throw "field '" + name + "' does not exist in script class '" + this.className + "' or super class '"
							+ Type.getClassName(Type.getClass(this.superClass)) + "'";
					}
				}
		}

		if (this.superClass == null)
		{
			throw "field '" + name + "' does not exist in script class '" + this.className + "'";
		}
		else
		{
			throw "field '" + name + "' does not exist in script class '" + this.className + "' or super class '"
				+ Type.getClassName(Type.getClass(this.superClass)) + "'";
		}
	}

	@:op(a.b) public function fieldRead(name:String):Dynamic
	{
		return resolveField(name);
	}

	@:op(a.b) public function fieldWrite(name:String, value:Dynamic):Dynamic
	{
		switch (name)
		{
			case _:
				if (this.findVar(name) != null)
				{
					this._interp.variables.set(name, value);
					return value;
				}
				else if (Reflect.hasField(this.superClass, name))
				{
					Reflect.setProperty(this.superClass, name, value);
					return value;
				}
				else if (this.superClass != null && Std.isOfType(this.superClass, PolymodScriptClass))
				{
					var superScriptClass:PolymodAbstractScriptClass = cast(this.superClass, PolymodScriptClass);
					try
					{
						return superScriptClass.fieldWrite(name, value);
					}
					catch (e:Dynamic)
					{
					}
				}
		}

		if (this.superClass == null)
		{
			throw "field '" + name + "' does not exist in script class '" + this.className + "'";
		}
		else
		{
			throw "field '" + name + "' does not exist in script class '" + this.className + "' or super class '"
				+ Type.getClassName(Type.getClass(this.superClass)) + "'";
		}
	}
}
