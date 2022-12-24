# samples/flixel_zip

This sample demonstrates the use of Polymod with ZIP files.
On native filesystems, the ZipFileSystem automatically detects and functions with mod folders and mod archives (uncompressed or compressed).
On HTML5, the ZipFileSystem requires the user to upload the ZIP file. This means that it does not work with mod folders.

This sample utilizes assets from the following:
- Boyfriend from Friday Night Funkin', whose assets are made available under the Apache license.
- ENA from the [ENA Skin Pack](https://gamebanana.com/mods/186934), whose assets are made available under the Creative Commons 4.0.
    - ENA's mod is in an uncompressed ZIP file, demonstrating easy drag-and-drop mod installation.
- Miku from the [Hatsune Miku](https://gamebanana.com/mods/185602) mod, whose assets are made available under the Creative Commons 4.0.
    - Miku's mod is a directory, which demonstrates that the ZipFileSystem can load unzipped mods as well, meaning you don't have to rezip mods you are in the process of developing.
    - Note that directory mods cannot be loaded on the HTML5 version of this sample.
- Whitty from [VS Whitty Definitive Edition](https://gamebanana.com/mods/354884), whose assets are made available under the Creative Commons 4.0.
    - Whitty's mod is a compressed ZIP, demonstrating that mods can be distributed in a compressed format.

## Build Instructions

1. Install Haxe.
2. `haxelib install hmm` to download the dependency manager.
3. `haxelib run hmm install` to download dependencies.
4. `lime test windows -debug` to build and run the sample for Windows.
- You can also use `lime test html5 -debug` to build and run the sample for web.
