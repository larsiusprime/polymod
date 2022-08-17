# samples/flixel_zip_html5

This sample demonstrates the use of Polymod with the Flixel framework.
It includes several sprites and text files, and demonstrates file loading using the MemoryZipFileSystem, which is the ZipFileSystem provided on HTML5 platforms.
This sample is dependant on HTML5-specific features, and will not work on other platforms. Please see the `flixel_zip_sys` sample for a native version. In a finalized application, use can use `#if html5` to provide specific code for specific platforms.