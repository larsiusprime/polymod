---
title: Mod Metadata
---
{% include toc.html %}

In order to be recognized by Polymod, a mod folder must contain a metadata file. By default, this file is located at `_polymod_meta.json`, but this can be reconfigured in your own projects. See [Configuring Polymod](./configuring-polymod) for more information.

A mod's metadata contains all the information needed for your project to not only recognize a mod and validate its compatibility, but also display it to your users. It includes a title, description, author, and even optionally an icon you can display.

## Scanning for Mods

In your application, you can retrieve the metadata for all installed mods using the following function:

```haxe
/**
 * Scan the modRoot directory for available mods and returns all their respective metadata entries.
 * @param modRoot The root directory to scan for mods in.
 * @param apiVersionStr (optional) Enforce a specific API version on mods.
 * @param errorCallback (optional) A function to receive any PolymodErrors that occur.
 * @return A list of ModMetadata objects, or an empty list.
 */
Polymod.scan(modRoot, apiVersionStr, errorCallback);
```

## _polymod_meta.json

The metadata JSON contains data which is loaded 

## _polymod_icon.png

If a mod provides this image file, it will be read into memory and provided as a Bytes in the `ModMetadata` object.
