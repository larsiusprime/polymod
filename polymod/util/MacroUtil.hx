package polymod.util;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

@:nullSafety
class MacroUtil {
    #if macro
    /**
     * Check if a Class implements an Interface. Checks all superclasses of the class type as well.
     * @param classType The class to check.
     * @param interfaceType The interface to check against.
     * @return True if the class implements the interface (directly or via inheritance), false otherwise.
     */
    public static function implementsInterface(classType:ClassType, interfaceType:ClassType):Bool
    {
      for (i in classType.interfaces)
      {
        if (areClassesEqual(i.t.get(), interfaceType))
        {
          return true;
        }
      }

      if (classType.superClass != null)
      {
        return implementsInterface(classType.superClass.t.get(), interfaceType);
      }

      return false;
    }

    /**
     * Retrieve a ClassType from a string name.
     * @param name The name of the class to retrieve.
     * @return The ClassType of the class.
     */
    public static function getClassType(name:String):ClassType
    {
      switch (Context.getType(name))
      {
        case TInst(t, _params):
          return t.get();
        default:
          throw 'Class type could not be parsed: ${name}';
      }
    }

    /**
     * Check if two Classes are equal by comparing their names and package names.
     * @param class1 The first class to compare.
     * @param class2 The second class to compare.
     * @return True if the classes are equal, false otherwise.
     */
    public static function areClassesEqual(class1:ClassType, class2:ClassType):Bool
    {
      return class1.pack.join('.') == class2.pack.join('.') && class1.name == class2.name;
    }

    /**
     * Check if two Types are equal by comparing their names and type parameters.
     * @param type1 The first type to compare.
     * @param type2 The second type to compare.
     * @return True if the types are equal, false otherwise.
     */
    public static function areTypesEqual(type1:Type, type2:Type):Bool
    {
      if (type1 == type2) return true;

      switch (type1) {
        case TMono(t1):
          switch (type2) {
            case TMono(t2):
              return areTypesEqual(t1.get(), t2.get());
            default:
              return false;
          }
        case TEnum(t1, p1):
          switch (type2) {
            case TEnum(t2, p2):
              return t1 == t2 && areTypeArraysEqual(p1, p2);
            default:
              return false;
          }
        case TInst(t1, p1):
          switch (type2) {
            case TInst(t2, p2):
              return areClassesEqual(t1.get(), t2.get()) && areTypeArraysEqual(p1, p2);
            default:
              return false;
          }
        case TType(t1, p1):
          switch (type2) {
            case TType(t2, p2):
              var d1 = t1.get().type;
              var d2 = t2.get().type;
              return areTypesEqual(d1, d2) && areTypeArraysEqual(p1, p2);
            default:
              return false;
          }
        case TFun(args1, ret1):
          switch (type2) {
            case TFun(args2, ret2):
              return areFunctionArgsEqual(args1, args2) && areTypesEqual(ret1, ret2);
            default:
              return false;
          }
        case TAnonymous(a1):
          throw "Not implemented";
        case TDynamic(t1):
          throw "Not implemented";
        case TLazy(f1):
          throw "Not implemented";
        case TAbstract(t1, p1):
          throw "Not implemented";
        default:
          return false;
      }
    }

    public static function areFunctionArgsEqual(args1:Array<{name:String, opt:Bool, t:Type}>, args2:Array<{name:String, opt:Bool, t:Type}>):Bool
    {
      for (i in 0...args1.length) {
        if (!areTypesEqual(args1[i].t, args2[i].t)) {
          return false;
        }
      }

      return true;
    }

    public static function areTypeParametersEqual(type1:TypeParameter, type2:TypeParameter):Bool
    {
      return type1.name == type2.name && areTypesEqual(type1.t, type2.t) && areTypesEqual(type1.defaultType, type2.defaultType);
    }

    /**
     * Check if two arrays of type parameters are equal by comparing their names and types.
     * @param type1 The first array of type parameters to compare.
     * @param type2 The second array of type parameters to compare.
     * @return True if the type parameters are equal, false otherwise.
     */
    public static function areTypeParameterArraysEqual(type1:Array<TypeParameter>, type2:Array<TypeParameter>):Bool
    {
      if (type1.length != type2.length) return false;

      for (i in 0...type1.length) {
        if (!areTypeParametersEqual(type1[i], type2[i])) {
          return false;
        }
      }

      // If we get here, the type parameters are equal
      return true;
    }

    /**
     * Check if two enum types are equal by comparing their names and type parameters.
     * @param type1 The first enum type to compare.
     * @param type2 The second enum type to compare.
     * @return True if the enum types are equal, false otherwise.
     */
    public static function areEnumTypesEqual(type1:EnumType, type2:EnumType):Bool
    {
      return type1.name == type2.name && areTypeParameterArraysEqual(type1.params, type2.params);
    }

    /**
     * Check that two arrays of types have the same types in the same order.
     * @param types1 The first array of types.
     * @param types2 The second array of types.
     * @return True if the arrays are equal, false otherwise.
     */
    public static function areTypeArraysEqual(types1:Array<Type>, types2:Array<Type>):Bool
    {
      if (types1.length != types2.length) return false;

      for (i in 0...types1.length) {
        if (!areTypesEqual(types1[i], types2[i])) {
          return false;
        }
      }

      // If we get here, the types are equal
      return true;
    }
    #end
}
