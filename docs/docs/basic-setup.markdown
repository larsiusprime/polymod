---
title: Basic Setup
---
{% include toc.html %}

# Basic Setup

Initializing Polymod is the first and most basic step to implementing modding support in your application.

To start loading mods, simply run `Polymod.init`, like so:

```haxe
Polymod.init({
  modRoot: "./mods/",
  dirs:["mymod"]
 });
```

Be sure to do this BEFORE your game loads any assets, and Polymod will do the rest, including determining what game engine you're using.

After that, all you do is load your game's assets like you normally do, making sure to utilize your framework's asset management systems:

OpenFL / HaxeFlxiel / NME:
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

`myImage` will use the modified `myImage.png` asset if it has been replaced by a mod, and if it hasn't, it will use the original asset.

## Loading Additional Mods

Of particular note in the snippet above is the `dirs` field. This is a list of all the IDs for the mods you wish to load.

Polymod recommends you build a list view, from which users can view which mods they have installed (i.e. present in the `modRoot` folder), whether they are enabled (i.e. whether your application passes the mod ID to `dirs`), and ideally some way to reprioritize mods (i.e. determine the order of the mod IDs in the `dirs` array). You will need to build this list yourself, since Polymod is not a UI library.

However, Polymod has several functions and utilities to assist you in building this list, such as a `scan()` function and a standard metadata format. See [Mod Metadata](./mod-metadata/) for more details.

## Samples

If you have any issues, please review the sample projects available on the [Github repository](https://github.com/larsiusprime/polymod).
