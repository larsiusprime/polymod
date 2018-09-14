# Polymod
An atomic modding framework for Haxe games

![A visual preview of the polymod OpenFL sample](preview.gif)

# What is this

Let's say you have a game or app that you want to make moddable. The easiest way to do this is to:

1. Make your game data-driven (expose as much of your content in the form of loose data files as possible)
2. Let players provide their own data files

Easy enough. But what if you want players to be able to use multiple mods together? How do you manage that?

Polymod solves both problems.

First, it **overrides your lime/OpenFL Asset library** with a custom one pointed at a mod folder (or folders) somewhere on the user's hard drive. Whenever you request an asset via `Assets.getBitmapData()` call or whatever, the custom library first checks if the mod has a modified version of this file. If it does, it returns the mod's modified version. If it doesn't, it falls through to the default asset library (the assets included with the game).

Second, it **combines mods atomically**. Instead of supplying one mod folder, you can provide several. Polymod will go through each folder in turn and apply the changes from each mod, automatically joining them into one combined mod at runtime. Note that this means that the order you load the mods in matters, in the case that they have overlapping changes.

Polymod currently works with OpenFL desktop target only but could be expanded to support other frameworks and targets if there's interest.

Polymod supports the following kinds of operations:
- Replace asset
- Append data to the end of existing asset (text only)
- Merge data at a specified location within an existing asset (text only)

Replace logic works on any asset format.
Append logic works only on text assets.
Merge logic is currently supported for plaintext (TXT), TSV, and XML asset formats only. Support for JSON is planned.

A sample for the OpenFL framework is provided.

# Usage

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

Be sure to call `Polymod.init()` before you load any assets. Also note that calling `Polymod.init()` will clear your Asset cache.

After that, you just load your assets as normal:

```haxe
var myImage = Assets.getBitmapData("myImage.png"); //either the default asset or the one overriden by a mod
```

## Optional init parameters

At minimum you need to specify your root mod directory and the paths to each individual mod. However, you can also provide the following parameters:

### `apiVersion:String`
This lets you enforce a modding API for your game/app. This is a version string that conforms to [semantic versioning 2.0](https://semver.org/), and if provided will return errors for any mods whose metadata indicates they are not compatible. I strongly recommend you initialize Polymod with this so that users can receive good warnings about which mods may be broken. You should update your game's modding API in accordance with the semantic versioning rules to indicate when you've changed your data format in a way that might introduce breaking changes to existing mods.

### `errorCallback:PolymodError->Void`
This lets you get errors and warnings from Polymod about the mods you're trying to load in. If there's any problems, they'll be reported to this function. Otherwise any failures will happen silently.

### `modVersions:Array<String>`
This is helpful if there's multiple versions of particular mods and you want to check for specific ones. If this array is provided, Polymod will check to see if each mod you attempt to load matches a particular version (as in the mod's own version, not your game/app's modding API version). So if you're trying to load two mods called "foo" and "bar", but you want to make sure "foo" is compatible with version "1.2.0" of "foo" and "bar" is compatible with version "2.3.0" of "bar, you should pass in `["foo","bar"]` to `dirs` and `["1.2.0","2.3.0"]` to `modVersions`. If there's any problems with the version numbers, `errorCallback` will receive them.

### `mergeRules:MergeRules`
If you're using mods that make use of the `_merge` directory, Polymod needs additional information about how to parse certain data formats, CSV files for instance -- are cells quoted or unqouted? You should indicate the particular rules for properly parsing these files in this data structure. Mods just using normal file replacement and the `_append` directory don't need this because neither of those operations requires any knowledge of how to unpack a particular file format and put it back together.

NOTE: Currently this data structure just supports some basic hints for how to parse the CSV data format. More complexity will be added to this as needed.

### `ignoredFiles:Array<String>`
It's common to put some basic metadata files in the root directory of mods, but you might want to keep those from actually winding up as valid assets in the game/app itself. This is also useful for disallowing changes to particular key files. If you define this array, Polymod will not include any file that matches one of these filenames in your final asset library. If you want to exclude Polymod's default recommended metadata files from asset library ingestion, you can call `Polymod.getDefaultIgnoreList()`, which returns these files:
 
 * `_polymod_meta.json`
 * `_polymod_icon.png`
 * `_polymod_pack.txt`
 * `ASSET_LICENSE.txt`
 * `CODE_LICENSE.txt`
 * `LICENSE.txt`

# Creating a mod

The Polymod format is fairly simple -- create a folder for your mod, and stick some files in it. These files will then either replace or modify files from the base asset set. You have three basic operations:

* Replace: provide files to replace the default ones
* Append: add some lines of text to the end of an existing text file
* Merge: insert some text in the middle of an existing text file, according to specified pattern matching

## Basic mod structure

- root folder
- `_append` folder
- `_merge` folder

### Root folder

Any files you place here will replace those found in the default asset library. So if the default asset library has a file called `graphics/apple.png`, you can provide your own version by placing it at `<modroot>/graphics/apple.png`.

When loading multiple mods, if several mods all provide the same file, the last one loaded will provide the final asset. You can see this behavior in the included sample. This is why the order in which you load mods matters!

### `_append` folder

Any text files you place here will have their contents appended to the ends of files with the same names in the default asset library. So if the base game has a file called `text/hello.txt` that says:

`Hello, world!`

You can add additional lines by placing a file at `<modroot>/_append/text/hello.txt` that says:

`Hello from my mod!`

Which will result in this in game when `text/hello.txt` is loaded and displayed:

```
Hello, world!
Hello from my mod!
```

### `_merge` folder

This is mostly meant for XML and CSV/TSV files. Say you have a big complicated XML file at `data/stuff.xml` with lots of nodes:

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

This is the file you would put in `<modroot>/_merge/data/stuff.xml`:
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

CSV and TSV files can be merged as well, but no logic needs to be supplied. In this case, the mod loader will look for any rows in the base file whose first cell matches the same value as those in the merge file, and replace them with the rows from the merge file.

TODO: Merge logic for JSON is currently planned but not yet supported.
TODO: Advanced merge logic for CSV/TSV (specifcy a field other than the one at index 0 as the primary merge key) is not yet supported.

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

## Further reading

https://www.fortressofdoors.com/player-friendly-atomic-game-modding/

## TODO:

# Security

Players modifying their games to accept random untrusted third party content are already exposing themselves in a fundamental way, but there's perhaps some things we can do to shave the attack surface area down a bit. For one, special care needs to be taken care if some of the assets you're loading via Polymod are driving in-game scripts and have access to e.g. File read/write/delete API's (or even worse, invoking system commands and/or launching other executables). At the moment, Polymod does absolutely nothing to protect you from this, so you must make your own safeguards. In the future we might provide some basic sandboxing or safety checks.
