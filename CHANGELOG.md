# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.2] - 2022-03-01
A small bug fix update.
### Fixed
- Fixed a bug where scripted classes would fail while attempting to import and use an enum.
- Standardized code style across several files.

## [1.5.1] - 2022-02-25
A large number of bug fixes for scripted classes.
### Changed
- The `dirs` parameter of Polymod is now optional. This is useful if Polymod is only used for localization.
- Reduced the amount of compile-time logging created by scripted classes.
### Removed
- Removed an unused PolymodErrorCode.
### Fixed
- Fixed a bug where scripted classes would fail to build when encountering fields marked with `@:generic`.
  - These fields are now skipped completely (and cannot be overridden by scripted classes).
- Fixed a bug where scripted classes would fail to build when encountering arguments or return types using a type parameter.
- Fixed a bug where scripted classes would override functions with the return type `Void` with a function that attempts to return `null`.
- Fixed a bug where scripted classes did not properly support overriding functions with optional arguments.
- Fixed a bug related to using macros while using the FlixelBackend.
- Fixed a bug where the library would not build without the `hscript-ex` library installed (the library is no longer required).


## [1.5.0] - 2022-02-22
### Added
- Added new functionality which allows for parsing and instantiation of classes defined in scripts.
  - These scripted classes can extend existing classes or even other scripted classes.
  - See [Scripted Classes](https://polymod.io/docs/scripted-classes) for more information.
- Incorporated the functionality of `hscript-ex` into Polymod.
### Removed
- The `POLYMOD_USE_HSCRIPTEX` flag has been made redundant. A fork of `hscript-ex` is now bundled into Polymod.

## [1.4.3] - 2022-02-18
### Fixed
- OpenFLBackend no longer breaks when you are using the main version of OpenFL.

## [1.4.2] - 2022-02-06
Version 1.4.2 includes a large number of bug fixes and tweaks to improve reliability.
### Added
- Added the optional `assetsPrefix` option to the `frameworkParams`.
  - Use this if your project's `assets/` folder uses a different name.
- Added a new Flixel sample project which ensures cache clearing when reloading mods.
- Added several convenience functions to handle loading and unloading of mods at runtime.
  - These convenience functions perform the proper steps to reload Polymod. Note you may need to call `clearCache()` depending on your framework and your app's current state.
  - `loadMod()` and `loadMods()` enables an individual (or multiple) mods, by re-initializing the framework with the appropriate mods enabled.
  - `unloadMod()` and `unloadMods()` disables an individual (or multiple) mods, by re-initializing the framework with the appropriate mods disabled.
  - `unloadAllMods()` disables all mods, by re-initializing the framework with no mods enabled. 
    - Localized asset replacements will still work, but no user-defined mods will be loaded.
  - `disable()` fully disables Polymod, destroying the asset handler.
    - Neither user-defined mods nor localized asset replacements will work until you call `init()` again.
### Changed
- Added additional testing to the `openfl_firetongue` sample.
  - `mod5` now loads a different image depending on the selected locale.
- Performed many internal code style improvements (please use template strings)
- Improvements to documentation
  - Renamed and cleaned up the `Localization` page (formerly known as `Translation`)
  - Added a section to the `Localization` page describing its partial support (only available in Lime/OpenFL/Flixel as of this update).
### Fixed
- Fixed several issues that stopped the Flixel backend from working. It's finally actually working I swear check the sample.
- Fixed several bugs related to asset retrieval.
- Fixed a bug where debug printing would sometimes not enable.
- Fixed a bug where the project would not build if Firetongue was not installed.
- Fixed several issues with the HEAPS sample (seriously was it ever working?).
### Removed
- Temporarily disabled the `HScript-EX` feature.
  - Additional work to implement the scripted class functionality is required.
- REMOVED the existing modpack functionality (based on the `_polymod_pack.txt` file).
  - This will be replaced with a revamped system for modpacks in the future.
- REMOVED the documentation associated with modpacks.
### Known Issues
- The `openfl_firetongue` sample mod which implements an additional language is currently broken.


## [1.4.1] - 2022-01-20
### Changed
- Added additional codedocs for each error code.
### Fixed
- Fixed a compile bug for Flixel backends.
- Fixed a bug where embedded default assets would not load properly.

## [1.4.0] - 2022-01-17
This release marks the migration of the project documentation to [polymod.io](https://polymod.io), a new website for the project hosted by Github Pages.
### Added
- Added a new Github Pages site for documentation.
  - This page is automatically generated using the `master` branch, with the Jekyll project located at `/docs/`.
- Added a new logo for the library.
- Added FireTongue integration for asset localization.
  - This incredibly powerful feature allows you to pass a FireTongue instance to Polymod, which will allow loading assets from the locale folder. This allows for locales to override not just strings, but also data files and even audio/visual assets, just by using your framework's asset management system.
  - For example, when the locale is set to `en-US`, `openfl.Assets.getImage("images/billboard.png")` can return a default image, or a custom image when the locale is `pt-BR`.
  - This not only allows developers to translate audio or graphics with almost no effort, but also allows mods to translate audio and graphics of the base game, or EVEN OTHER MODS.
  - With the existing features of Polymod, mods should also be able to reasonably append new locales to the manifest, without requiring the developers to modify the base game.
- Added a new compile definition: `POLYMOD_API_VERSION_MATCH`
  - This allows you to define how strictly mods must match when loading.
  - `NONE` matches any version, `MATCH_MAJOR` requires the major version to match, `MATCH_MINOR` requires the minor version to match, and `MATCH_PATCH` requires the patch version to match.
  - This defaults to `MATCH_PATCH` to prevent breaking changes, but you should probably update this to at least `MATCH_MINOR` to reduce strain on your mod developers.
- Added a new compile definition: `POLYMOD_USE_HSCRIPTEX`
  - This *EXPERIMENTAL* option allows you to replace the default hscript parser with [hscript-ex](https://github.com/ianharrigan/hscript-ex), which provides support for classes.
- Added the new `FlixelBackend` backend.
  - This backend provides additional HaxeFlixel-specific fixes to the OpenFLBackend.
  - Added `FLIXEL` as a Framework value to manually select this backend.
  - Updated the framework detector to use the `FlixelBackend` over the `OpenFLBackend` when HaxeFlixel is being used.
- Added a new function, `Polymod.clearCache()`, which triggers the backend to clear any cached assets from memory.
  - This is useful if you want to ensure assets reload after a modlist or locale change. 
- Improved the Mod Metadata format with new and useful attributes.
  - These changes are backwards compatible; new fields are optional, and changed fields still support the existing format.
  - Added the `homepage` attribute to allow mods to provide a URL.
  - Added the `contributors` attribute to provide a list of contributors.
    - Each contributor is an object with the following keys: `name`, `role`, `email`, `url`.
    - New applications are encouraged to use this attribute over the `author` attribute where possible.
- Added a new sample demonstrating usage with FireTongue.
### Changed
- Deprecated the `author` attribute in favor of the `contributors` attribute.
  - The `author` attribute is still supported for backwards compatibility.
  - Retrieving `author` when `contributors` is defined will return the name of the first contributor.
- Improved compile-time error output for when `@:hscript({context})` receives an invalid value.
- Changed the `openfl_hscript` sample to demonstrate retrieving and calling one or more functions from a single script file.
- Cleaned up samples by removing unnecessary project configuration.
### Fixed
- Fixed a crash bug which occured when LimeBackend was used without a `frameworkParams` argument.
- Fixed a bug where `MOD_LOAD_PREPARE` and `MOD_LOAD_DONE` were showing as errors rather than notices.

## [1.3.1] - 2021-12-05
### New Contributors
- @Cheemsandfriends made their first contribution in https://github.com/larsiusprime/polymod/pull/75
### Added
- All compile defines can now also be edited at runtime.
  - For example, you can enable Debug logging in code by using `PolymodConfig.debug = true;`
  - If you use these to set asset library locations, etc., be sure to set them before instantiating any classes which utilize script files.
- Added a config option to customize the mod append folder.
  - Modify this option by adding `POLYMOD_APPEND_FOLDER` as a compile define, or by setting `PolymodConfig.appendFolder` in your code.
  - Defaults to `_append` for backwards compatibility.
- Added a config option to customize the mod merge folder.
  - Modify this option by adding `POLYMOD_MERGE_FOLDER` as a compile define, or by setting `PolymodConfig.mergeFolder` in your code.
  - Defaults to `_merge` for backwards compatibility.
- Added a config option to customize the mod metadata file.
  - Modify this option by adding `POLYMOD_MOD_METADATA_FILE` as a compile define, or by setting `PolymodConfig.modMetadataFile` in your code.
  - Defaults to `_polymod_meta.json` for backwards compatibility.
- Added a config option to customize the mod icon file.
  - Modify this option by adding `POLYMOD_MOD_ICON_FILE` as a compile define, or by setting `PolymodConfig.modIconFile` in your code.
  - Defaults to `_polymod_icon.png` for backwards compatibility.
- Added a config option to customize the mod pack definition file.
  - Modify this option by adding `POLYMOD_MOD_PACK_FILE` as a compile define, or by setting `PolymodConfig.modPackFile` in your code.
  - Defaults to `_polymod_pack.txt` for backwards compatibility.
- Added a config option to customize the ignore list for Polymod mod files.
  - Modify this option by adding `POLYMOD_MOD_IGNORE` as a compile define (use a comma separated list), or by setting `PolymodConfig.modIgnoreFiles` in your code (use an `Array<String>`).
  - Defaults to `LICENSE.txt,ASSET_LICENSE.txt,CODE_LICENSE.txt` for backwards compatibility.
- Added `optional` as an `@:hscript` parameter.
  - This suppresses the error thrown when a script file is missing.
### Changed
- Missing scripts are now handled gracefully rather than throwing an unhandled missing asset exception.
  - Added a debug print call when the script is missing but `optional` is set to `true`.
### Fixed
- Fixed a bug where scripted function that define a `pathName` function fail to retrieve the script.
- Fixed compilation errors when using the HEAPS backend.
  - The HEAPS sample now compiles and runs without errors.
- Fixed a deprecation warning in the CSV.hx file.


## [1.3.0] - 2021-11-18
This release marks the transition to [Eric Myllyoja](https://github.com/MasterEric) as the lead maintainer for the repository.
This release is backwards compatible with 1.0.0 as no breaking changes have been made.
### Added
- Added the `NodeFileSystem` class and `OpenFLWithNodeBackend`, for use with projects built in HTML5 for use with Electron.
  - Provided by [TamarCurry](https://github.com/MasterEric/polymod/pull/35).
- The `@:hscript` annotation can now be defined on classes and interfaces.
  - Defining a `@:hscript` annotation on a class or interface will add the constants provided to them to the context of any script functions of any of that class's children.
    - For example, `@:hscript(Std, Math)` on a class will allow any of that class's script functions to access `Std` and `Math` from the context as though they had defined them, without having to manually define these values for each individual function.
  - These values are parsed recursively, so any superclass, supersuperclass, interfaces of those classes, etc. will also be added to the context.
  - Updated the `openfl_hscript` sample to demonstrate this new syntax.
- The `@:hscript` annotation can now be defined as a parameter object.
  - This allows for additional types of configuration to be passed, aside from the script context.
  - Parameter objects can now be passed when using `@:hscript` on a class or interface.
    - Parameters are defined recursively, and values defined on a superclass or interface will be overridden by child classes.
    - The exception is the `context` parameter, which merges the provided contexts together.
  - If an identifier is provided in the annotation on a parent class or interface, the identifier need not necessarily be defined in the upper context.
      - For example, an interface can require that the variable `scriptPath` be included in the context or used as the script path name, without defining that variable itself, as long as any implementing classes that include a script function define that variable.
  - Updated the `openfl_hscript` sample to demonstrate this new syntax.
- Added `context` as an `@:hscript` parameter.
  - This achieves the existing functionality of providing constants to the script context.
  - Example: `@:hscript({context: [Std, Math]})`
- Added `cancellable` as an `@:hscript` parameter.
  - This allows for a script to be cancelled by the user. Defaults to `false`.
    - A new function `cancel()` is added to the context, which can be used to cancel the execution of the rest of the provided script body.
    - For example, you can add `@:hscript({cancellable: true})` to allow users to cancel an event before you perform an action.
  - Example: `@:hscript({context: [Std, Math], cancellable: true})`
- Added `pathName` as an `@:hscript` parameter.
  - This allows for a script to specify the specific pathname to access.
    - This ignores the `POLYMOD_ROOT_PATH` and `POLYMOD_USE_NAMESPACE` settings.
    - The value of `POLYMOD_SCRIPT_EXT` is still appended to the final path.
  - Example: `@:hscript({context: [Std, Math], pathName: "assets/scripts/initBee"})`
- The `pathName` parameter can now use an identifier. This allows for the pathname to be defined dynamically by the object.
  - If a constant is provided, the value is used as the pathname.
    - Example: `@:hscript({context: [Std, Math], pathName: "assets/scripts/initBee"})`
  - If an identifier is provided, the value of that identifier is accessed at the time the function is called.
    - Example: `@:hscript({context: [Std, Math], pathName: getScriptName})`
    - If the resulting value is a string constant, that value is used as the path.
    - If the resulting value is a Function, it will be called and the return value will be used as the path.
- Added `runBefore` as an `@:hscript` parameter.
  - This allows for a script's function body to be called before the script, rather than after. Defaults to `false`.
  - Incompatible with the `cancellable` parameter.
  - Example: `@:hscript({context: [Std, Math], runBefore: true})`
### Fixed
- Fixed a bug where defining `@:hscript` annotations on a parent class or interface would not pass the values down to the child function.


## [1.2.0] - 2021-11-04
### Added
- Added several new compile defines to change the behavior of Polymod
  - `POLYMOD_ROOT_PATH`: Defines the base path from which scripts should be accessed.
  - `POLYMOD_USE_NAMESPACE`: If true, scripts are located in a folder based on the classpath.
    - For example, the script `com.polymod.test#init` will be located at `/data/com/polymod/test/init.txt`.
  - `POLYMOD_SCRIPT_EXT`: Defines the file extension used by all Polymod scripts.
    - This defaults to `.txt` for backwards compatibility, but should be changed to `.hscript` to improve integration with IDEs.
  - `POLYMOD_SCRIPT_LIBRARY`: Defines the asset library used by all Polymod scripts.
    - This defaults to `default`, which should be fine for Lime projects which only utilize the default asset library.
  - Set these values using either of the following methods:
    - For Haxe projects, add something like `-D POLYMOD_SCRIPT_EXT=.hscript` to your Haxe compiler arguments or `hxml`.
    - For Lime projects, add something like `<haxedef name="POLYMOD_SCRIPT_EXT" value=".hscript" />` to your `project.xml`.
- Added the new variable `script_variables`, accessible after the execution of a scripted function.
  - Similar to `script_result`, which provides the return value of the script, and `script_error`, which outputs the error provided by the script, `script_variables` provides access to the named variables created by the script's local scope.
  - One use case for this is to allow a single script to define several named functions, which can be retrieved and stored to use later.


## [1.1.0] - 2021-09-25
### New Contributors
* @MasterEric made their first contribution in https://github.com/larsiusprime/polymod/pull/34
### Added
- Added several new informational error codes to `onError`:
  - `MOD_LOAD_PREPARE`: Called when Polymod is about to load a given mod.
  - `MOD_LOAD_DONE`: Called when Polymod has successfully finished loading a given mod. Useful for logging.
  - `MOD_LOAD_FAIL`: Called when Polymod has failed to load a given mod.
- Fully abstracted the file system and made it a parameter, similar to `IBackend`.
  - This allows users to implement and utilize their own custom file system class.
  - Example: `Polymod.init({customFileSystem: CustomFileSystem})` given a class `CustomFileSystem` which implements `IFileSystem`.
- Added several video file types to the list of default file extensions.
  - Added `.mov`, `.mp4`, `.avi`, `.mkv`, and `.webm`.
### Fixed
- Performed HaxeFormatter cleanup on all source files.
- Fixed a crash when old projects which used multiple asset libraries were not specifying `frameworkParams`.
  - This fix is required for users attempting to build [Friday Night Funkin'](https://github.com/ninjamuffin99/Funkin/) or derivatives.


## [1.0.0] - 2021-09-15
The repository as it existed on 2020-09-15.
### Added
- All basic functionality.
### Changed
- Fixed support for Lime projects utilizing multiple asset libraries.
### Known Issues
- A crash may occur when old projects (which do not specify `frameworkParams.assetLibraryPaths`) are run in this version.
