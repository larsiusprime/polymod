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
