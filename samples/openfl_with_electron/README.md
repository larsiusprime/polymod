# samples/openfl_with_electron

## Running this Sample

Dependencies:
* [Electron](https://github.com/electron/electron/releases/download/v14.2.1/electron-v14.2.1-win32-x64.zip)
* Haxe obvs
* hxnodejs (via `haxelib install hxnodejs`)

Steps:
1. Run `lime build html5` in the `samples/openfl_with_electron` directory.
2. Run `electron main.js` in the `samples/openfl_with_electron/bin/html5/bin` directory.
3. Preview the resulting application.

Eventually `lime test electron` will properly run, pending the resolution of the following fix:
https://github.com/haxelime/lime/issues/1504
