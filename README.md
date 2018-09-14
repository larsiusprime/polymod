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
 * `ASSET_LICENSE.txt`
 * `CODE_LICENSE.txt`
 * `LICENSE.txt`

# Creating a mod

I'll include more documentation about this when I have time. Until then, see this article:

https://www.fortressofdoors.com/player-friendly-atomic-game-modding/

## TODO:
- root folder
- `_append` folder
- `_merge` folder
- asset types

# Security

Players modifying their games to accept random untrusted third party content are already exposing themselves in a fundamental way, but there's perhaps some things we can do to shave the attack surface area down a bit. For one, special care needs to be taken care if some of the assets you're loading via Polymod are driving in-game scripts and have access to e.g. File read/write/delete API's (or even worse, invoking system commands and/or launching other executables). At the moment, Polymod does absolutely nothing to protect you from this, so you must make your own safeguards. In the future we might provide some basic sandboxing or safety checks.
