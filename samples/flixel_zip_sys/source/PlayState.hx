import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.ui.FlxInputText;
import flixel.addons.ui.FlxUIInputText;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.io.Bytes;
import haxe.io.Path;
import openfl.desktop.Clipboard;
import openfl.events.Event;
import openfl.net.FileFilter;
import openfl.net.FileReference;
import openfl.utils.AssetManifest;
import openfl.utils.AssetType;
import openfl.utils.Assets;
import openfl.utils.ByteArray;
import polymod.Polymod;
import polymod.fs.MemoryZipFileSystem;
import polymod.fs.PolymodFileSystem.IFileSystem;
import polymod.fs.SysZipFileSystem;

using StringTools;

class PlayState extends FlxState
{
	/**
	 * The mod widgets.
	 */
	private var widgets:Array<ModWidget> = [];

	/**
	 * Things that aren't the widgets (the images and texts).
	 * These get destroyed and reloaded when refreshing.
	 */
	private var stuff:Array<FlxSprite> = [];

	private var helpText:FlxText;
	private var zippathTextbox:FlxUIInputText;

	public override function create()
	{
		super.create();

		// Load with zero mods first?
		loadMods([]);

		this.bgColor = 0xFFFFFFFF;

		makeButtons();
		makeHelpText();
		makeZippathTextBox();
	}

	private function makeHelpText()
	{
		helpText = new FlxText(0, FlxG.height - 150, 0, "Type in the path to your zipped mod and press ENTER to load it");
		helpText.setFormat(null, 12, FlxColor.BLACK);
		helpText.screenCenter(X);
		add(helpText);
	}

	private function makeZippathTextBox()
	{
		zippathTextbox = new FlxUIInputText(helpText.x, 425, 500);
		add(zippathTextbox);
	}

	private function makeButtons(?loadedmods:Array<String>)
	{
		var modDir:String = '../../../mods';
		#if mac
		// account for <APPLICATION>.app/Contents/Resources
		modDir = '../../../../../../mods';
		#end
		var mods = (loadedmods == null) ? [] : loadedmods;
		var xx = 10;
		var yy = 200;
		for (mod in mods)
		{
			trace('Adding widget for mod $mod');
			var w = new ModWidget(mod, onWidgetMove);
			w.x = xx;
			w.y = yy;

			widgets.push(w);

			xx += Std.int(w.width) + 10;

			w.fixButtons();

			add(w);
		}

		updateWidgets();
	}

	public function refresh()
	{
		for (thing in stuff)
		{
			remove(thing);
		}
		stuff.splice(0, stuff.length);

		drawImages();
		drawText();
	}

	private function onWidgetMove(w:ModWidget, i:Int)
	{
		trace('onWidgetMove ${w.modId} : $i');
		if (i != 0)
		{
			var temp = widgets.indexOf(w);
			var newI = temp + i;
			if (newI < 0 || newI >= widgets.length)
			{
				return;
			}
			var other = widgets[newI];

			var oldX = w.x;
			var oldY = w.y;

			widgets[newI] = w;
			widgets[temp] = other;

			w.x = other.x;
			w.y = other.y;

			other.x = oldX;
			other.y = oldY;

			w.fixButtons();
			other.fixButtons();
		}

		reloadMods();
		updateWidgets();
	}

	private function updateWidgets()
	{
		if (widgets == null)
			return;
		for (i in 0...widgets.length)
		{
			var showLeft = i != 0;
			var showRight = i != widgets.length - 1;
			widgets[i].showButtons(showLeft, showRight);
		}
	}

	private function removeButtons()
	{
		for (btngrp in widgets)
		{
			remove(btngrp, true);
		}
		widgets.splice(0, widgets.length);
	}

	private var syszipfs:IFileSystem;
	public override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(FlxG.keys.pressed.CONTROL && FlxG.keys.pressed.V)
		{
			if(Clipboard.generalClipboard.hasFormat(TEXT_FORMAT))
			{
				zippathTextbox.text = Clipboard.generalClipboard.getData(TEXT_FORMAT, ORIGINAL_PREFERRED);
			}
		}
		if(FlxG.keys.justPressed.ENTER)
		{
			var zippath_normalized = Path.normalize(zippathTextbox.text);
			if(sys.FileSystem.exists(zippath_normalized) && !sys.FileSystem.isDirectory(zippath_normalized))
			{
				syszipfs = new SysZipFileSystem({
					zipPath: zippath_normalized,
					zipName: Path.withoutDirectory(zippath_normalized),
					modRoot: 'mods/'
				});
				removeButtons();
				trace('zip name: $zippath_normalized');
				var mods = syszipfs.readDirectory('mods');
				trace('mods: $mods');
				makeButtons(mods);
				refresh();
			}
			else
			{
				// just flashes red for a bit to indicate that it's an invalid path
				var loopnum = 0, n_loops = 5;
				new FlxTimer().start(0.1, (tmr)->{
					if(loopnum == n_loops-1)
					{
						zippathTextbox.color = FlxColor.BLACK;
						return;
					}
					if(loopnum % 2 == 0)
						zippathTextbox.color = FlxColor.RED;
					else
						zippathTextbox.color = FlxColor.BLACK;

					loopnum++;
				}, n_loops);
			}
		}
	}

	private function drawImages()
	{
		trace('Drawing images...');
		var xx = 10;
		var yy = 10;

		var images = Assets.list(AssetType.IMAGE).filter(function(item:String)
		{
			return item.startsWith('assets/img/') && item.endsWith('.png');
		});
		images.sort(function(a:String, b:String):Int
		{
			if (a < b)
				return -1;
			if (a > b)
				return 1;
			return 0;
		});

		trace('Drawing ${images.length} images...');
		for (image in images)
		{
			// #if html5
			/* trace('Drawing image $image');
			var img_f = Assets.loadBitmapData(image, false);
			img_f.onError((e)->{ trace('aaaaaaa error: $e'); });
			img_f.onProgress((i1, i2)->{ trace('idk: $i1 $i2'); });
			img_f.onComplete((bmpd) ->
			{
				trace('Got bitmapdata? ${bmpd != null}');
				var sprite = new FlxSprite(xx, yy);
				var atlasPath = image.replace('.png', '.xml');
				if (Assets.exists(atlasPath))
				{
					trace('Building animated image $image');
					sprite.frames = FlxAtlasFrames.fromSparrow(bmpd, Assets.getText(atlasPath));
					sprite.animation.addByPrefix('idle', 'idle', 24, true);
					sprite.animation.play('idle');
				}
				else
				{
					trace('Building static image $image');
					sprite.loadGraphic(bmpd);
				}
				sprite.setGraphicSize(72, 72);
				sprite.updateHitbox();

				var text = new FlxText(xx, sprite.y + sprite.height, sprite.width, image);
				text.setFormat("Arial", 12, 0xFF000000, FlxTextAlign.CENTER);

				add(sprite);
				add(text);
				stuff.push(text);
				stuff.push(sprite);

				xx += Std.int(sprite.width + 10);
			}); */
			// #else
			trace('Drawing image $image');
			var sprite = new FlxSprite(xx, yy);

			var atlasPath = image.replace('.png', '.xml');
			if (Assets.exists(atlasPath))
			{
				trace('Building animated image $image');
				sprite.frames = FlxAtlasFrames.fromSparrow(image, Assets.getText(atlasPath));
				sprite.animation.addByPrefix('idle', 'idle', 24, true);
				sprite.animation.play('idle');
			}
			else
			{
				trace('Building static image $image');
				sprite.loadGraphic(image);
			}

			sprite.setGraphicSize(72, 72);
			sprite.updateHitbox();

			var text = new FlxText(xx, sprite.y + sprite.height, sprite.width, image);
			text.setFormat("Arial", 12, 0xFF000000, FlxTextAlign.CENTER);

			add(sprite);
			add(text);
			stuff.push(text);
			stuff.push(sprite);

			xx += Std.int(sprite.width + 10);
			// #end
		}
	}

	private function drawText()
	{
		var xx = FlxG.width - 250 - 10;
		var yy = 10;

		var texts = Assets.list(AssetType.TEXT).filter(function(item:String)
		{
			return item.startsWith('assets/data/');
		});

		texts.sort(function(a:String, b:String)
		{
			if (a < b)
				return -1;
			if (a > b)
				return 1;
			return 0;
		});

		trace('Drawing ${texts.length} texts...');

		for (t in texts)
		{
			trace('Drawing text $t');
			var isXML:Bool = false;
			if (t.indexOf('xml') != -1 || t.indexOf('json') != -1)
			{
				isXML = true;
			}

			var text = new FlxInputText(xx, yy, 250);
			// these 2 lines break on html5 for some reason
			// text.setFormat("Arial", 12, 0xFF000000, FlxTextAlign.CENTER);
			// text.height = 150;
			text.wordWrap = true;
			text.lines = 10;

			var str = Assets.getText(t);
			text.text = (str != null ? str : 'null');

			var caption = new FlxText(xx, text.y + text.height, text.width, "UNKNOWN");
			caption.setFormat("Arial", 12, 0xFF000000, FlxTextAlign.CENTER);
			caption.text = t;

			add(text);
			add(caption);
			stuff.push(text);
			stuff.push(caption);

			yy += Std.int(text.height + 35);
		}
	}

	private function reloadMods()
	{
		trace('Reloading mods...');
		var theMods = [];
		for (w in widgets)
		{
			if (w.isModActive)
			{
				theMods.push(w.modId);
			}
		}
		loadModsHTML5(theMods);
	}

	private function loadModsHTML5(dirs:Array<String>)
	{
		trace('Loading mods: ${dirs}');
		var modRoot = 'mods/';
		var results = Polymod.init({
			dirs: dirs,
			errorCallback: onError,
			ignoredFiles: Polymod.getDefaultIgnoreList(),
			framework: Framework.FLIXEL,
			customFilesystem: syszipfs,
			fileSystemParams: {
				modRoot: modRoot
			},
			skipDependencyChecks: true
		});
		// Reload graphics before rendering again.
		var loadedMods = results.map(function(item:ModMetadata)
		{
			return item.id;
		});
		trace('Loaded mods: ${loadedMods}');
		refresh();
	}

	private function initModsHTML5()
	{
		if (syszipfs == null)
		{
			return;
		}
		var results = Polymod.init({
			dirs: [],
			errorCallback: onError,
			ignoredFiles: Polymod.getDefaultIgnoreList(),
			customFilesystem: syszipfs,
			fileSystemParams: {modRoot: 'mods/'},
			skipDependencyChecks: true,
			modRoot: 'mods/'
		});
		trace('results: $results');
	}


	private function loadMods(dirs:Array<String>)
	{
		trace('Loading mods: ${dirs}');
		var modRoot = '../../../mods/';
		#if mac
		// account for <APPLICATION>.app/Contents/Resources
		var modRoot = '../../../../../../mods';
		#end
		var results = Polymod.init({
			modRoot: modRoot,
			dirs: dirs,
			errorCallback: onError,
			ignoredFiles: Polymod.getDefaultIgnoreList(),
			framework: Framework.FLIXEL
		});
		// Reload graphics before rendering again.
		var loadedMods = results.map(function(item:ModMetadata)
		{
			return item.id;
		});
		trace('Loaded mods: ${loadedMods}');
		refresh();
	}

	private function onError(error:PolymodError)
	{
		trace('[${error.severity}] (${error.code.toUpperCase()}): ${error.message}');
	}
}

// class ZipLoader
// {
// 	var _download_fileref:FileReference;
// 	var zipBytes:Bytes;

// 	public var zipname:String;
// 	public var zippath:String;
// 	public var zfs:IFileSystem;

// 	var postLoad:Void->Void;

// 	public function new(modroot:String, ?postLoad:Void->Void)
// 	{
// 		init();
// 		this.postLoad = postLoad;
// 		zippath = modroot;
// 	}

// 	function init()
// 	{
// 		_download_fileref = new FileReference();
// 		_download_fileref.addEventListener(Event.SELECT, (e) ->
// 		{
// 			_download_fileref.load();
// 		});
// 		_download_fileref.addEventListener(Event.COMPLETE, onLoadComplete);
// 	}

// 	public function loadZip()
// 	{
// 		if (_download_fileref == null)
// 		{
// 			init();
// 		}
// 		_download_fileref.browse([new FileFilter("Zip files", "*.zip")]);
// 	}

// 	function onLoadComplete(e:Event)
// 	{
// 		// zipBytes = getHaxeBytes(_download_fileref.data);
// 		zipname = _download_fileref.name;
// 		zippath = Path.join([zippath, zipname]);

// 		_download_fileref.removeEventListener(Event.SELECT, (e) ->
// 		{
// 			_download_fileref.load();
// 		});
// 		_download_fileref.removeEventListener(Event.COMPLETE, onLoadComplete);
// 		_download_fileref = null;

// 		// zfs = new MemoryZipFileSystem({
// 		// 	zipBytes: zipBytes,
// 		// 	zipName: zipname,
// 		// });
// 		zfs = new SysZipFileSystem({
// 			zipPath: zippath,
// 			zipName: zipname,
// 			modRoot: 'mods/'
// 		});
// 		if (postLoad != null)
// 		{
// 			postLoad();
// 		}
// 	}

// 	function getHaxeBytes(b:ByteArray)
// 	{
// 		// not sure how else to convert a ByteArray into haxe.io.Bytes :/
// 		var el_bytes = Bytes.alloc(b.length);
// 		for (i in 0...b.length)
// 		{
// 			el_bytes.fill(i, 1, b.readByte());
// 		}
// 		return el_bytes;
// 	}
// }
