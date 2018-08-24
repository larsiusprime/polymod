# Polymod
An atomic modding framework for Haxe games

WIP

Currently works with OpenFL only but could be expanded to support other frameworks.

# Usage

Loading one mod:
```haxe
Polymod.init("path/to/my/mod");
```

Loading multiple mods:
```haxe
Polymod.init(["path/to/first/mod","path/to/second/mod","path/to/third/mod","etc"]);
```

Be sure to call Polymod.init() before you load any assets.

After that, you just load your assets as normal:

```haxe
var myImage = Assets.getBitmapData("myImage.png"); //either the default asset or the one overriden by a mod
```

# How It Works

Blah blah fill this in with details.

https://www.fortressofdoors.com/player-friendly-atomic-game-modding/
