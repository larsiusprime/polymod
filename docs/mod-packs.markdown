---
title: Mod Packs
---
{% include toc.html %}

# Mod Packs

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