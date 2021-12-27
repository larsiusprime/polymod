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

When loading multiple mods, if several mods all provide the same file, the last one loaded will provide the final asset. You can see this behavior in the included sample. This is why the order in which you load mods matters!

### _append folder

Any text files you place here will have their contents appended to the ends of files with the same names. So if the base game has a file called `text/hello.txt` that says:

`Hello, world!`

You can add additional lines by placing a file at `<modroot>/<appendFolder>/text/hello.txt` that says:

`Hello from my mod!`

Which will result in this in game when `text/hello.txt` is loaded and displayed:

```
Hello, world!
Hello from my mod!
```

By default, the append folder Name will be `_append`, but this can be changed. See [Configuring Polymod](./configuring-polymod/) for more information.

When loading multiple mods, note that appending applies AFTER replacement! If several mods replace a file and serveral other mods append it, the last mod to replace the file will be used as a base (overriding the base library and any mods before it), then all `_append` files will be then applied in modload order.

### _merge folder

This folder allows you to merge into files containing a more complex data structure, such as XML, CSV/TSV, or JSON. The format of the files in this folder depends on the file type of the file being merged into.

See [Merging Files](./merging-files/) for more information on how merging works for each file type.

By default, the merge folder name will be `_merge`, but this can be changed. See [Configuring Polymod](./configuring-polymod/) for more information.

