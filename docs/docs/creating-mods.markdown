---
title: Creating Mods
---
{% include toc.html %}

# Creating Mods

The Polymod format is fairly simple -- create a folder for your mod, and stick some files in it. These files will then either replace or modify files from the base asset set. You have three basic operations:

* Replace: provide files to replace the default ones
* Append: add some lines of text to the end of an existing text file
* Merge: insert some text in the middle of an existing text file, according to specified pattern matching

## Basic mod structure

- root folder
- `_append` folder
    - Assets placed in the `_append` folder will be Appended to those from the default asset library.
    - This is only valid for plain text files; for JSON, CSV, and XML files, use Merging instead.
- `_merge` folder
    - Assets placed in the `_merge` folder will be Merged those from the default asset library.
    - This is supported for CSV, TSV, JSON, XML, and plaintext files by default.
    - Other asset types (such as images)


### Root folder

Any files you place here will replace those found in the default asset library. For example, if the default asset library has a file called `images/apple.png`, you can provide your own version by placing it at `<modroot>/images/apple.png`.

When loading multiple mods, if several mods all provide the same file, the last one loaded will provide the final asset. You can see this behavior in the included sample. This is why the order in which you load mods matters! Think of it like Minecraft

A good comparison is the Minecraft Texture Pack system