---
title: Scripted Classes
---
{% include toc.html %}

# Scripted Classes

See the `openfl_hscript_class` sample for an example of this in action.

This documentation is a WIP because I only just got this working, but here's a quick and dirty rundown:

## Creating a Scripted Class

1. Create a class like this:

```
@:hscriptClass
class ScriptedStage extends Stage implements HScriptable {
}
```

## Abilities and Limitations of Scripted Classes

There are many things which you can do within a scripted class, including but not limited to:

* Override the constructor (using `public function new() { ... }`)
* Import modules and instantiate objects (like `import flixel.FlxG`).
* Access public or private fields of the superclass, including functions.

There are some things to watch out for though:

* You can't override `static` functions in a script.
* You can't override a function which uses a private class as an argument.
  * This is not possible in any Haxe program so don't worry about this.
* You can't (CURRENTLY) override functions with an optional argument like `function create(?name:String = 'test')`
* You can't (CURRENTLY) override functions which utilize a constrained generic type like `function test<T:Iterable<String>>(a:T)`
  * I think fully generic types work? Haven't tested.
* Sometimes using `this.xyz` to access fields doesn't work, but just `xyz` does.
