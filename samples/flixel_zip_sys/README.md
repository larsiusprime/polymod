# samples/flixel_zip_sys

This sample demonstrates the use of Polymod with the Flixel framework.
It includes several sprites and text files, and demonstrates file loading using the SysZipFileSystem, which is the ZipFileSystem provided on native platforms.
This sample is dependant on native-specific features, and will not work on other platforms. Please see the `flixel_zip_html5` sample for a web version. In a finalized application, use can use `#if html5` to provide specific code for specific platforms.