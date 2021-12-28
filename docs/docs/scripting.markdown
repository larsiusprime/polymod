---
title: Scripting
---
{% include toc.html %}

# Scripting

![A visual preview of the polymod hscript sample](preview2.gif)

"Okay," you say, "I can replace all the assets I want, but how do I override the base game's code?"

There are two ways to support scripting using Polymod:

1. Do it yourself
2. Use Polymod's `HScriptable` interface

## Do it yourself (NOT RECOMMENDED)

You don't need a dedicated scripting framework to get moddable scripts. So long as your script files are part of your asset library, they can be replaced or modified like any other text file, and it doesn't even matter what scripting language you choose.

For example, you could implement Lua scripting through the following method:
1. Load the script file from your assets folder. Polymod will intervene here and load the modded script if it is available.
2. Parse the script.
3. Execute the script.
4. Interpret the result and continue with your program.

However, using this method can overcomplicate your application, since you must handle this entire process yourself. This is a major potential [footgun](https://en.wiktionary.org/wiki/footgun) for newcomers, however, so unless you already know what you're doing, I generally recommend using Polymod's built-in support for scripting.

## Use Polymod's `HScriptable` interface (RECOMMENDED)
Polymod provides an optional interface called `HScriptable`. This interface uses the magic of compile-time macros to automatically bind targeted functions to [hscript](https://github.com/HaxeFoundation/hscript) scripts.

_NOTE: Big thanks to [Jeff Ward](https://github.com/jcward) for making this possible!_

There are three steps to enable hscript bindings with Polymod:

### 1. Create a class that implements `HScriptable`
```haxe
class MyClass implements polymod.hscript.HScriptable
```
This class should include some functions you intend to expose to hscript files.

### 2. Tag a function with the `@:hscript` metadata
```haxe
@:hscript
private function doSomething() { }
```

### 3. Provide an hscript file matching the function's module & name:
```
data/demo/Simulation/doSomething.txt
```

When you do all of the above steps, "doSomething.txt" will be parsed during `MyClass`'s constructor, and when `MyClass.doSomething()` is run, the parsed hscript representation of `doSomething.txt` will be executed.

The default root path for scripts is the top-level `/data` folder in your assets library. This can be reconfigured, as long as you do so before loading any classes which implement `HScriptable`. The file extension used for scripts (which defaults to `.txt` for compatibility reasons) can also be configured, and it is recommended that you change it to `.hscript` or something similar. See [Configuring Polymod](./configuring-polymod) for more information.

You can also toggle whether to use the function's fully qualified path as a directory prefix (this behavior is on by default). In this example, the file path `demo/Simulation/doSomething` corresponds with the function's fully qualified path in the Haxe namespace, `demo.Simulation.doSomething`.

You can also [Choose a custom script path](#choosing-a-custom-script-path) on a per-function basis.

Be aware that these paths may be case-sensitive on any case-sensitive file systems (hello Linux!).

## A practical example

We shall use as our example the `openfl_hscript` sample included with Polymod, depicted above. For context, this is a simple simulation containing a field of flowers, some honeybees, and a "home" depicted by a honeypot. Bees will seek out flowers, drain them of pollen, return home, deposit the pollen as honey (updating the score), and then seek a new flower. We would like to expose various aspects of this behavior to scripts, so that users can change the behavior.

First, note that the `Simulation` class implements `HScriptable`:
```haxe
class Simulation extends Sprite implements polymod.hscript.HScriptable
```

### Simple function

Consider this function:
```haxe
@:hscript
private function emptyFlower(flower:Flower) { }
```

And the corresponding hscript file `emptyFlower.txt`:
```haxe
flower.pollen = 0;
flower.cooldown = flower.maxCooldown;
flower.alpha = 0.25;
```

For context, this function runs when a bee visits a flower, touches it, and gains pollen. The default script will remove pollen from the flower, start a cooldown timer, and make it appear faded to indicate that it's depleted.

Note that the function body is empty. The macro will inject all the necessary boilerplate to load the `emptyFlower.txt` script file during the `Simulation` class's constructor, and at runtime when `emptyFlower()` is called, the `flower:Flower` parameter will be passed in to the script as a local variable. So the final `emptyFlower()` function post macro-injection actually looks something like this:

```haxe
private function emptyFlower(flower:Flower)
{
	var script:Script = _polymod_scripts.get("emptyFlower");  //_polymod_scripts initialized in the constructor
	script.set("flower", flower);
	script.execute();
}
```

**NOTE:** _Polymod loads the relevant script files to be executed in the object's constructor, therefore static methods are not supported. This may be changed in the future, but in the meantime you can achieve the same result by utilizing a [singleton](https://en.wikipedia.org/wiki/Singleton_pattern)._

**NOTE:** _Since scripts are loaded in the same manner as other assets, they therefore follow the standard rules for asset replace/append/merge. Keep this in mind when writing scripts, if you want to create and maintain compatibility between mods._

### Adding variables to the context

Here's another function:
```haxe
private function updateBee(bee:Bee, elapsed:Float) { }
```

It only takes two variables, so this should be simple, right?

Well, not so fast:
```haxe
if(bee == null) return;

if(bee.x < 0 || bee.x > 800 || bee.y < 0 || bee.y > 480)
{
    bee.x = 100 + Math.random() * 700;
    bee.y = 50 + Math.random() * 380;
}

if(bee.pollen > 0)
{
    if(!isTouching(bee, home))
    {
        moveToward(bee, home, elapsed);
        if(isTouching(bee, home))
        {
            home.honey += bee.pollen;
            bee.pollen = 0;
            updateScore(home.honey);
        }
    }
    return;
}

if(bee.flower == null)
{
    bee.turnsSearching++;
    bee.flower = getRandomFlower();

    if(bee.flower != null && bee.flower.pollen == 0)
    {
        bee.flower == null;
    }

    if(bee.turnsSearching > 2)
    {
        bee.flower = getRandomFlower();
        bee.turnsSearching = 0;
    }

    if(bee.flower != null && bee.flower.pollen > 0)
    {
        bee.turnsSearching = 0;
    }
}

if(bee.flower != null)
{
    moveToward(bee, bee.flower, elapsed);
    if(isTouching(bee, bee.flower))
    {
        if(bee.flower.pollen > 0)
        {
            bee.pollen = bee.flower.pollen;
            emptyFlower(bee.flower);
        }
        bee.flower = null;
    }
}
```

That logic is relying on many other class member variables, and even calling other functions. This is a pretty common situation when you're trying to convert existing functions into hscript files, and it's not necessarily a good idea to "fix" the problem by cramming all those references in as explicit function parameters. Not only is that unwieldy, it will change the function signature, requiring you to track down every call to this function and update it. Not only is that a pain, it's an opportunity to introduce new bugs.

Instead, you can just add extra variables to the script context by adding the `context` parameter to your `hscript` annotation, like this:
```haxe
@:hscript({
    context: [Math,elapsed,home,moveToward,isTouching,getClosestFlower,getRandomFlower,emptyFlower,updateScore]
})
private function updateBee(bee:Bee, elapsed:Float) { }
```

Here the script will receive all the parameters we specified in the provided `context`, followed by all the normal function parameters. This is also a good way to pass in global utility classes that are otherwise not available to your scripts, such as `Math`, `Std`, and `StringTools`.

**NOTE:** _You can also pass `this` to the `context` parameter, which will pass in the object itself, allowing your script to access the current object, and therefore call any public functions available on your class, like so:_

```haxe
@:hscript({
    context: [Math,this]
})
private function updateBee(bee:Bee, elapsed:Float) { }
```

with this user script:

```haxe
this.moveToward(this.getClosestFlower());
```

**NOTE:** _Although your scripts can make changes to any mutable objects you pass in, a local variable within an hscript file is *not* the same as the local variable from your host function with the same name, even if they both *point* to the same object. This means that you can do `bee.pollen = 0` in your script and expect to see that change even after the script is finished, but if you do `bee = anotherBee` within the script, the `bee` variable in your main function will remain unchanged. This is the difference between passing by reference and passing by value used in other languages such as C++, and this can be a common source of subtle bugs if you're not careful.To TL;DR -- scripts can change the internal state of objects that are passed to it, and call functions of those objects, but cannot change what objects that variables are being pointed to._

### Context inheritance

Say you have a class containing several scripted functions, all of which share a context, like the one below:

```haxe
class Simulation {
  @:hscript({
    context: [Math,elapsed,home,moveToward,isTouching,getClosestFlower,getRandomFlower,emptyFlower,updateScore]
  })
  private function updateBee(bee:Bee, elapsed:Float) { }

  @:hscript({
    context: [Math,elapsed,home,moveToward,isTouching,getClosestFlower,getRandomFlower,emptyFlower,updateScore]
  })
  private function updateFlower(flower:Flower, elapsed:Float) { }
}
```

It can be a massive pain to manage the context for each function, and this only multiplies if you have several classes which all share the same context. One typo or omission can cause a script to fail to execute, or to execute in an unexpected way.

Fear not! The `@:hscript` macro can be used to specify a context for a class, and all of its functions will inherit that context. Moreover, `@:hscript` can be specified on the parent classes and interfaces for a class, and all its parameters will be passed down in order of inheritance.

Check it out:

```haxe
@:hscript({
    context: [Std, Math, FlxG]
})
interface IScriptable extends HScriptable {}

@:hscript({
    context: [elapsed,home,moveToward,isTouching,getClosestFlower,getRandomFlower,emptyFlower,updateScore]
})
class Simulation implements IScriptable {
  @:hscript
  private function updateBee(bee:Bee, elapsed:Float) { }

  @:hscript
  private function updateFlower(flower:Flower, elapsed:Float) { }
}
```

This is a great way to share common functionality between scripts, and it's also a great way to share functionality between classes.

**NOTE:** _`context` is not the only parameter which is passed down. You can also pass down any other parameters of `@:hscript`, including `optional`, `cancellable`, `pathName`, etc. The behavior of these parameters is covered later in this documentation._

**NOTE:** _Inheritance acts in a reasonably predictable manner; children will inherit the parameters of their super classes and interfaces, with the child class's own parameters overriding those of the parents. Note that `context` is a special case, in which contexts are **CONCATENATED TOGETHER** rather than overridden.

### Mixing code and scripts

Of significant note is that the function body of a scriptable function doesn't have to be empty!

```haxe
@:hscript
private function updateScore(value:Float)
{
    score.text = script_result;
}
```

The actual script is a simple one-liner:
```haxe
"Honey collected: " + value;
```

The script simply composes a string, and the function takes the result and updates a text field.

What makes this work is that the macro automatically injects the script logic at the beginning of the `@:hscript`-tagged function, before any other code in the function body. Then it defines three new local variables: `script_result`, `script_variables`, and `script_error`. `script_result` and `script_error` are both `Dynamic`, while `script_variables` is a `Map<String, Dynamic>`.

- `script_result` is a `Dynamic` value that returns the output variable of the script.
- `script_error` is a `Dynamic` value that contains the error which occured during execution, if any.
    - See the [Handling errors](#handling-errors) section for more info.
- `script_variables` is a `Map<String, Dynamic> ` which contains each variable within the local scope of the script, by name.
    - See the [Retrieving multiple variables from a script](#retrieving multiple-variables-from-a-script) section for an example on how to use this.

In this particular function, we feed `script_result` into `score.text`.

**NOTE:** _If your function returns something other than `Void`, the macro will inject a `return script_result;` line at the end of your function, *after* any code you supply. If you want to return something other than `script_result` with your own logic,  be sure to provide your own `return` line to force an early return that skips the macro's injected one._

### Executing scripts optionally

One notable edge case relating to script functions whose body is where you have code which you always want to run, then optionally wish to run a user-provided script. This can easily be done with the following code:

```haxe
 @:hscript({
    optional: true
 })
private function updateScore(value:Float)
{
    currentScore += value;
}
```

If `optional` is set to `false` (the default), Polymod will throw an error when the relevant script is unavailable. Note that in this case, the body of the function will not be executed (especially since the function body may depend on the script_result)

However, if it is true, the following will happen:
* If the script exists, it will be run, then the body of the function will be run.
* If the script does NOT exist, Polymod will run the body of the function without an error.

### Executing code optionally

The opposite case can also be performed, say you have a function like the one below:

```haxe
@:hscript({
    cancellable: true
})
private function updateScore(value:Float)
{
    currentScore += value;
}
```

In the case above, a new function, `cancel()`, is provided to the context of the script. If the user's script calls that function, the function body (which would normally execute after the script) will be skipped entirely.

For example, you could make a function like the following:

```haxe
@:hscript({
    cancellable: true
})
private function onPickUpItem(item:Item)
{
    addToInventory(item);
    removeFromWorld(item);
}
```

If your `onPickUpItem` script contained something like the following:

```
if (item.properties.includes('slippery')) {
    cancel();
}
```

In this case, items with the property `slippery` will not execute the pickup logic.

### Running code before user-provided scripts

Another edge case is one where you want to execute your own code BEFORE the user-provided script's code. This can be done with the following:

```haxe
@:hscript({
    runBefore: true
})
private function updateScore(value:Float)
{
    score.text = value;
}
```

In this case, the body of the `updateScore` function will run BEFORE the script. This has some notable advantages:

```haxe
@:hscript({
    runBefore: true
})
private function updateScore(value:Float)
{
    if (value == 0) {
        return null;
    }
}
```

In the snippet above, the conditional block preempts the user-provided script from ever running by returning BEFORE the script is executed.

### Choosing a custom script path

A common case is the one where a different script path is desired for a given script. Setting custom script paths for each function can help make the structure of the script directory more logical.

```haxe
@:hscript({
    pathName: "player/updateHighScore"
})
private function updateScore(value:Float)
{
    score.text = script_result;
}
```

In the above example, the script will be loaded from `data/player/uploadHighScore.txt` instead of the default path based on the namespace.

### Using dynamic script paths

The implementation of the `pathName` attribute has an important caveat; *the pathName does not need to be a constant*.

pathName can also be an identifier; if the identifier points to a field or property, its value will be used, and if it points to a function, that function will be called and its return value will be used.

See the example below:

```haxe
var healthPath;

public function new(type:String) {
    healthPath = 'enemy/$id/updateHealth';
}

@:hscript({
    pathName: healthPath
})
private function updateHealth(value:Float)
{
    this.health = script_result;
}

function getDamagePath() {
    return 'enemy/$id/updateDamage';
}

@:hscript({
    pathName: getDamagePath
})
private function updateDamage(value:Float)
{
    this.damage = script_result;
}
```

In the above example, the script which is called for each function is *dynamic*, and depends on the `id` field of the current object. The variable method or the function method will have the same end result, so which one you use is up to personal preference.

### Retrieving multiple variables from a script

Utilizing the `script_variables` value which is passed to the function, you can retrieve any variables from the local context. This allows you to calcualte multiple values with one script.

User script:

```haxe
var health = 10;
var damage = 20;
```

Code:

```haxe
@:hscript
function updateMetadata() {
    if (script_variables.get('health') != null) {
        this.health = script_variables.get('health');
    }
    if (script_variables.get('damage') != null) {
        this.health = script_variables.get('damage');
    }
}
```

### Defining callback functions in a script

Depending on the structure of your scripted application, you may want to utilize a single script containing multiple functions, rather than multiple scripts each containing a single function.

For example, this may be what you want your user's script to look like:

```haxe
var trail;
function onCreate() {
    trail = new FlxTrail();
    add(trail);
}

function onUpdate() {
    trail.update();
}

function onDestroy() {
    remove(trail);
}
```

To implement this in code, all you need to do is retrieve each function by name from the `script_variables` map provided within the function context.

```haxe
function getPathName() {
    return 'character/$id';
}

@:hscript({
    pathName: getPathName
})
public function buildCallbacks() {
    if (script_variables.get('onCreate') != null) {
		trace('Found character hook: onCreate');
		cbOnCreate = script_variables.get('onCreate');
	}
    if (script_variables.get('onUpdate') != null) {
		trace('Found character hook: onUpdate');
		cbOnUpdate = script_variables.get('onUpdate');
	}
    if (script_variables.get('onDestroy') != null) {
		trace('Found character hook: onDestroy');
		cbOnDestroy = script_variables.get('onDestroy');
	}
}
```

You can then call the function later as needed:

```haxe
public function new() {
    // Make sure to actually CALL the function that runs the script!
    buildCallbacks();

    if (cbOnCreate != null) {
        cbOnCreate();
    }
}

public override function update() {
    super.update();

    if (cbOnUpdate != null) {
        cbOnUpdate();
    }
}

public override function destroy() {
    if (cbOnDestroy != null) {
        cbOnDestroy();
    }
    super.destroy();
}
```

Note that these callback functions can utilize any local variables that they created within their script; those variables don't get destroyed when the script is done.

### Handling errors

If you're exposing scripts in your project, that means someone can change the game's logic at runtime, which means they can and will screw something up, which means *errors*.

You probably want your application to handle them gracefully, or at least give the user some feedback about what went wrong.

```haxe
@:hscript(Std, Math, numFlowers, numBees, distTest, makeFlower, makeHome, makeBee, home)
private function init():Void
{
    if (script_error != null)
    {
      	trace('hscript failed to load or threw: '+script_error);
        trace('TODO: Do something to recover from this failure.');
    }
}
```

As mentioned before, the macro will inject a local `script_error` variable along with the rest of the boilerplate. If there was a problem with the script (typically: it couldn't load, or the script itself threw an error), this variable will be set. Note that there is no point in using your own try/catch block; the macro has already done that for you and caught the result, which is now stored in `script_error`. If `script_error` is null it can be safely ignored.

Handling errors at all is purely optional, but recommended.
