![](./logo.png)

# Polymod

An atomic modding framework for Haxe games/apps.

Supports these frameworks:
- OpenFL
- HEAPS
- NME
- Lime (with or without OpenFL)
- Custom (provide your own backend)
- KHA (Coming Soon)

## Basic sample:
![A visual preview of the polymod OpenFL sample](preview.gif)

## Installation

Polymod is now available via [HaxeLib](https://lib.haxe.org/p/polymod/)! If you have previously installed Polymod directly from git, please update your installation:

```
haxelib install polymod
```

## What is Polymod?

Let's say you have a game or app that you want to make moddable. The easiest way to do this is to:

1. Make your game data-driven (expose as much of your content in the form of loose data files as possible)
2. Let players provide their own data files

Easy enough. But what if you want players to be able to use multiple mods together? How do you manage that?

Polymod solves both problems.

First, it **overrides your framework's asset system** with a custom one pointed at a mod folder (or folders) somewhere on the user's hard drive. Whenever you request an asset via `Assets.getBitmapData()` or `Res.loader.load()` call or whatever, the custom backend first checks if the mod has a modified version of this file. If it does, it returns the mod's modified version. If it doesn't, it falls through to the default asset system (the assets included with the game).

Second, it **combines mods atomically**. Instead of supplying one mod folder, you can provide several. Polymod will go through each folder in turn and apply the changes from each mod, automatically joining them into one combined mod at runtime. Note that this means that the order you load the mods in matters, in the case that they have overlapping changes.

Polymod currently works with  desktop* targets, and will eventually support other frameworks and targets.

\**`sys` target, technically. Any target with a File System.*

Polymod supports the following kinds of operations:
- Replace asset
- Append data to the end of existing asset (text only)
- Merge data at a specified location within an existing asset (text only)

Replace logic works on any asset format.
Append logic works only on text assets.
Merge logic is currently supported for plaintext (TXT), CSV, TSV, and XML asset formats only. Support for JSON is planned.

Samples for the OpenFL, Lime, NME, and HEAPS frameworks are provided.

## Basic Usage

Loading one mod:
```haxe
Polymod.init({
  modRoot:"path/to/mods/",
  dirs:["mymod"]
 });
```

Loading multiple mods:
```haxe
Polymod.init({
  modRoot:"path/to/mods/",
  dirs:["firstmod","secondmod","thirdmod","etc"]
 });
```

> ***NOTE**: On Mac, the default application working directory is `<APPLICATION_NAME>.app/Contents/Resources`, which differs    from Windows and Linux. If you hard code the search path for your game's mod directory, be sure to account for this difference    when targeting the Mac platform.*

Be sure to call `Polymod.init()` before you load any assets. Also note that calling `Polymod.init()` will clear your Asset cache.

After that, you just load your assets as normal:

OpenFL / NME:
```haxe
var myImage = Assets.getBitmapData("myImage.png");
```

Lime:
```haxe
var myImage = Assets.getImage("myImage.png");
```

HEAPS:
```haxe
var myImage = Res.loader.load("myImage.png");
```

This will return either the default asset, or a modified version if it's been replaced by a loaded mod.

## Documentation

For further documentation on how to configure and use Polymod in your application, please see the [Polymod website](http://larsiusprime.github.io/polymod/docs/).

# Creating a mod



### append folder

Any text files you place here will have their contents appended to the ends of files with the same names in the default asset library. So if the base game has a file called `text/hello.txt` that says:

`Hello, world!`

You can add additional lines by placing a file at `<modroot>/<appendFolder>/text/hello.txt` that says:

`Hello from my mod!`

Which will result in this in game when `text/hello.txt` is loaded and displayed:

```
Hello, world!
Hello from my mod!
```

By default, The append Folder Name will be `_append`, But if you want/need to change it, there are two options:


1. Add a `<haxedef name="POLYMOD_APPEND_FOLDER" value="[append name folder]" />` value to your project.xml.
1. Add `PolymodConfig.appendFolder = "[append name folder]";` to your code somewhere. Make sure it's before you call Polymod.init or after (Recommended that you call it before) and before you load any assets.


### merge folder

This folder allows you to merge into files containing a more complex data structure, such as XML, CSV/TSV, or JSON. The format of the files in this folder depends on the file type of the file being merged into.

By default, the merge folder will be `_merge` but again, to change the name of the stuff just use the append folder setting but instead of append, merge.
So, something like:

1. Adding a `<haxedef name="POLYMOD_MERGE_FOLDER" value="[merge name folder]" />` value to your project.xml.
2. Adding `PolymodConfig.mergeFolder = "[append merge folder]";` to your code somewhere. Make sure it's before you call Polymod.init or after (Recommended that you call it before) and before you load any assets.

#### XML

Say you have a big complicated XML file at `data/stuff.xml` with lots of nodes:

```xml
<?xml version="1.0" encoding="utf-8" ?>
<data>
   <!--lots of complicated stuff-->
   <mode id="difficulty" values="easy"/>
   <!--even more complicated stuff-->
</data>
```

And you want it to say this instead:

```xml
<?xml version="1.0" encoding="utf-8" ?>
<data>
   <!--lots of complicated stuff-->
   <mode id="difficulty" values="super_hard"/>
   <!--even more complicated stuff-->
</data>
```

Basically we want to change this one tag from this:

```xml
<mode id="difficulty" values="easy"/>
```

to this:
```xml
<mode id="difficulty" values="super_hard"/>
```

This is the file you would put in `<modroot>/<mergeFolder>/data/stuff.xml`:
```xml
<?xml version="1.0" encoding="utf-8" ?>
<data>
    <mode id="difficulty" values="super_hard">
        <merge key="id" value="difficulty"/>
    </mode>
</data>
```

This file contains both data and merge instructions. The `<merge>` child tag tells the mod loader what to do, and will not be included in the final data. The actual payload is just this:

```xml
<mode id="difficulty" values="super_hard">
```

The `<merge>` tag instructs the mod loader thus:

* Look for any tags with the same name as my parent (in this case, `<mode>`)
* Look within said tags for a `key` attribute (in this case, one named `"id"`)
* Check if the key's value matches what I'm looking for (in this case, `"difficulty"`)

As soon as it finds the first match, it stops and merges the payload with the specified tag. Any attributes will be added to the base tag (overwriting any existing attributes with the same name, which in this case changes values from "easy" to just "super_hard", which is what we want). Furthermore, if the payload has child nodes, all of its children will be merged with the target tag as well.

#### CSV/TSV

CSV and TSV files can be merged as well, but no logic needs to be supplied. In this case, the mod loader will look for any rows in the base file whose first cell matches the same value as those in the merge file, and replace them with the rows from the merge file.
TODO: Advanced merge logic for CSV/TSV (specify a field other than the one at index 0 as the primary merge key) is not yet supported.

#### JSON

JSON acts somewhat similarly to XML. Say you have a data file like this:

```json
{
    "data": {
        "difficulty": "easy",
	"nested": {
	    "enemies": [
	    	{
		    "name": "foo"
		},
	    	{
		    "name": "bar",
		    "weapon": "deagle"
		},
	    	{
		    "name": "baz"
		}
	    ]
	}
    }
}
```

And you want to change the difficulty to `super_hard`, same idea as the XML. We also want to bump up Bar's meager Desert Eagle into a fearsome Minigun. Instead of specifying the whole structure and putting a merge tag underneath it, you create a single top-level array called `merge`, specify the full path to inject into, along with the payload to inject, like so:

```json
{
    "merge": [
    	{
	    "target": "data.difficulty",
	    "payload": "super_hard"
	},
	{
	    "target": "data.nested.enemies[1].weapon",
	    "payload": "minigun"
	}
    ]
}
```

You can inject as many values as you like into as many paths as you like.

## Metadata

The only metadata file that is required is `_polymod_meta.json`, and it will look something like this:

```json
{
	"title":"Daisy",
	"description":"This mod has a daisy",
	"author":"Lars A. Doucet",
	"api_version":"0.1.0",
	"mod_version":"1.0.0-alpha",
	"license":"CC BY 4.0,MIT"
}
```

These files are not required, but are strongly recommended:

* `_polymod_icon.png` (for use in mod browsers, etc)
* `LICENSE.txt` (for general licensing terms)
* `ASSET_LICENSE.txt` (for asset-specific licensing terms, I recommend something from [Creative Commons](https://creativecommons.org/))
* `CODE_LICENSE.txt` (for code/script-specific licensing terms, I recommend something like [MIT](https://opensource.org/licenses/MIT))

And this file indicates that the mod is a mod pack:

* `_polymod_pack.txt`

## Mod packs

If a mod includes the file `_polymod_pack.txt` in the root directory, it will be treated not as a regular mod, but as a *mod pack*, ie, a collection of mods. This text file is a simple comma-separated list of mod directory names (relative to the root mod directory).

**NOTE:** *If a mod contains a mod pack list, ALL other files will be ignored.*

Let's say you have a mod called `stuff` that contains this `_polymod_pack.txt`:

`foo,bar,abc,xyz`

Loading `stuff` will cause Polymod to load those four mods in the specified order.

You can also indicate specific versions of mods:

`foo:1.0.0,bar:1.2.0`

As well as use wildcards:

`foo:1.*.*,bar:1.2.*`

When Polymod tries to load a modpack, it will look in the root mod directory you provided for the indicated mods. It will only load mods that 1) actually exist and 2) pass the version check (if specified). Any errors or warning will be sent to the error callback handler, and only non-failing mods will be loaded.

# Scripting

![A visual preview of the polymod hscript sample](preview2.gif)

"Okay," you say, "I can replace all the assets I want, but how do I override the base game's code?"

There are two ways to support scripting using Polymod:

1. Do it yourself
2. Use Polymod's `HScriptable` interface

## Do it yourself
You don't need a dedicated scripting framework to get moddable scripts. So long as your script files are part of your asset library, they can be replaced or modified like any other text file, and it doesn't even matter what scripting language you choose. This is a potential [footgun](https://en.wiktionary.org/wiki/footgun) for newcomers, however, so unless you already know what you're doing, I generally recommend using Polymod's built-in support for scripting.

## Use Polymod's `HScriptable` interface
Polymod provides an optional interface called `HScriptable` that will use some macro magic to automatically bind targeted functions to [hscript](https://github.com/HaxeFoundation/hscript) scripts.

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

The default root search path for scripts is the top-level "data" folder in your assets library. You can change this by modifying the public static variables in `polymod.hscript.HScriptConfig`. Be sure to do this *before* instantiating any class that implements `polymod.hscript.HScriptable`! You can also toggle whether to use the function's fully qualified path as a directory prefix (this behavior is on by default). In this example, the file path `demo/Simulation/doSomething` corresponds with the function's fully qualified path in the Haxe namespace, `demo.Simulation.doSomething`. The casing from your code is reflected in the search path, so be aware of that on case-sensitive file systems (hello Linux!).

**NOTE:** _as of right now the file extension it looks for is ".txt". We plan on making this configurable in the near future._

When you do all of the above steps, "doSomething.txt" will be parsed during `MyClass`'s constructor, and when `MyClass.doSomething()` is run, the parsed hscript representation of `doSomething.txt` will be executed.

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

**NOTE:** _Polymod loads the relevant script files to be executed in the object's constructor, therefore static methods are not supported. This may be changed in the future._

**NOTE:** _Since scripts are loaded in the same manner as other assets, they therefore follow the standard rules for asset replace/append/merge. Keep this in mind when writing scripts, if you want to create and maintain compatibility between mods._

### Resolving other variables

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

Instead, you can just add extra variables to the script context, like this:
```haxe
@:hscript(Math,bee,elapsed,home,moveToward,isTouching,getClosestFlower,getRandomFlower,emptyFlower,updateScore)
private function updateBee(bee:Bee, elapsed:Float) { }
```

Here the script will receive all the parameters we specified between the `@:hscript` tag's parentheses, followed by all the normal function parameters. This is also a good way to pass in global utility classes that are otherwise not available to your scripts, such as `Math`, `Std`, and `StringTools`.

**NOTE:** _Although your scripts can make changes to any mutable objects you pass in, a local variable within an hscript file is *not* the same as the local variable from your host function with the same name, even if they both *point* to the same object. This means that you can do `bee.pollen = 0` in your script and expect to see that change even after the script is finished, but if you do `bee = anotherBee` within the script, the `bee` variable in your main function will remain unchanged. Does that make sense? This can be a common source of subtle bugs if you're not careful. TL;DR -- go ahead and use your scripts to change the internal state of objects, call functions, and do calculations, but be very careful about trying to use scripts to change what variables are pointing to._

### Mixing code and scripts

I should note that the function body of a scriptable function doesn't have to be empty!

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

What makes this work is that the macro automatically injects the script logic at the beginning of the `@:hscript`-tagged function, before any other code in the function body. Then it defines two new local variables: `script_result` and `script_error`, both of type `Dynamic`. In this particular function, we feed `script_result` into `score.text`.

**NOTE:** _If your function returns something other than `Void`, the macro will inject a `return script_result;` line at the end of your function, *after* any code you supply. If you want to return something other than `script_result` with your own logic,  be sure to provide your own `return` line to force an early return that skips the macro's injected one._

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


# Further reading

https://www.fortressofdoors.com/player-friendly-atomic-game-modding/
