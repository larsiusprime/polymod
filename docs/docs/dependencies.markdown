---
title: Localization
---
{% include toc.html %}

# WIP: Dependencies

## THIS PROPOSAL IS WIP

A mod may have dependencies on other mods. Through proper configuration, Polymod can sure that any dependencies are loaded before the mod is loaded, and that the proper versions are used.

## Configuring Mod Dependencies

Mod dependencies are configured in the mod's `_polymod_metadata.json` file, like so:

```json
{
	"title":"Dragon",
	"description":"Replaces Bees with Dragons",
	"api_version":"0.1.0",
	"mod_version":"1.0.0-alpha",
  "dependencies": {
    "mod1": "1.0.0",
    "mod2": ">=1.3.0"
  }
}
```

Mod IDs are provided as keys, and the value is a version range which includes one or more comparators. Polymod's version comparator format fully conforms to the specification used by [node-semver](https://github.com/npm/node-semver#versions). A quick summary:

* `1.0.0`: The mod must match this version exactly.
* `>1.0.0`: The mod must be greater than the specified version.
* `>=1.0.0`: The mod must be greater than or equal to the specified version.
* `<1.0.0`: The mod must be less than the specified version.
* `<=1.0.0`: The mod must be less than or equal to the specified version.
* `1.0.*`: Allow any patch version of the mod.
* `1.*`: Allow any minor version of the mod.
* `*`: Allow any version of the mod, as long as it is present.
* `""`: An empty string is equivalent to `*`, and allows any version of the mod.

## Optional Dependencies

You can also define `optionalDependencies` to specify dependencies that are not required, like so:

```json
{
  // ...
  "optionalDependencies": {
    "mod1": "1.0.0",
    "mod2": ">=1.3.0"
  }
}
```

Mods listed as optional dependencies are not required to be enabled, but if they are enabled, Polymod will ensure they are loaded before the mod is loaded.

## Dependency Behavior

* If a mod has no dependencies, it will be loaded according to the provided modload order.
* If a mod has one or more mandatory dependencies, those mods will be added to the modload list, before the mod itself.
  * If one of the dependencies is not found, an error message will be provided and the mod will not load.
  * If one of the dependencies is available, but the version is not compatible, an error message will be provided and the mod will not load.
* If the mod has a dependency that is already in the modload list, and is listed before the mod, it will stay in its place in the list.
  * If the mod has a dependency that is already in the mod list, but AFTER the mod that depends on it, the dependency will be MOVED such that it is loaded before the dependency.
* If a mod has one or more optional dependencies, those mods will not be added to the modload list unless they are already present,
  * If the optional dependency is being loaded after the mod, the dependency will be MOVED such that it is loaded before the mod. Otherwise, it will stay in its place in the list.
* If two or mods form a dependency cycle, an error message will be provided and the associated mods will not load.
