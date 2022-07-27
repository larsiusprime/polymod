import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.ui.FlxInputText;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import haxe.io.Bytes;
import openfl.events.Event;
import openfl.net.FileFilter;
import openfl.net.FileReference;
import openfl.utils.AssetManifest;
import openfl.utils.AssetType;
import openfl.utils.Assets;
import openfl.utils.ByteArray;
import polymod.Polymod.Framework;
import polymod.Polymod;
import polymod.fs.ZipFileSystem;

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

	public override function create()
	{
		super.create();

		// Load with zero mods first?
		loadMods([]);

		this.bgColor = 0xFFFFFFFF;

		makeButtons();
		makeZipLoadingButton();
		drawImages();
		drawText();
	}

	var ziploader:ZipLoader;

	private function makeZipLoadingButton()
	{
		var loadZipButton = new FlxButton(0, FlxG.height - 50, "Load a zipped mod", () ->
		{
			ziploader = new ZipLoader(() ->
			{
				trace('zip name: ${ziploader.zipname}');
				var rootfolder = ziploader.zipname.substring(0, ziploader.zipname.length - 4);
				trace('rootfolder: $rootfolder');
				var loadedmods = Polymod.scan(rootfolder, "*.*.*", (e) ->
				{
					trace('[polymod]: $e');
				}, ziploader.zfs);
				trace('mods: ${loadedmods}');
				// makeButtons([for (m in loadedmods) m.id]);
				refresh();
			});
			ziploader.loadZip();
		});
		loadZipButton.scale.set(loadZipButton.scale.x * 2.5, loadZipButton.scale.y * 2.5);
		loadZipButton.updateHitbox();
		loadZipButton.screenCenter(X);
		add(loadZipButton);
	}

	private function makeButtons()
	{
		var modDir:String = '../../../mods';
		#if mac
		// account for <APPLICATION>.app/Contents/Resources
		modDir = '../../../../../../mods';
		#end
		#if sys
		var mods = sys.FileSystem.readDirectory(modDir);
		#else
		var mods = [];
		#end
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

	public override function update(elapsed:Float)
	{
		super.update(elapsed);
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
		loadMods(theMods);
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

class ZipLoader
{
	var _download_fileref:FileReference;
	var zipBytes:Bytes;

	public var zipname:String;
	public var zfs:ZipFileSystem;

	var postLoad:Void->Void;

	public function new(?postLoad:Void->Void)
	{
		init();
		this.postLoad = postLoad;
	}

	function init()
	{
		_download_fileref = new FileReference();
		_download_fileref.addEventListener(Event.SELECT, (e) ->
		{
			_download_fileref.load();
		});
		_download_fileref.addEventListener(Event.COMPLETE, onLoadComplete);
	}

	public function loadZip()
	{
		if (_download_fileref == null)
		{
			init();
		}
		_download_fileref.browse([new FileFilter("Zip files", "*.zip")]);
	}

	function onLoadComplete(e:Event)
	{
		zipBytes = getHaxeBytes(_download_fileref.data);
		zipname = _download_fileref.name;

		_download_fileref.removeEventListener(Event.SELECT, (e) ->
		{
			_download_fileref.load();
		});
		_download_fileref.removeEventListener(Event.COMPLETE, onLoadComplete);
		_download_fileref = null;

		zfs = new ZipFileSystem({
			zipBytes: zipBytes,
			zipName: zipname
		});
		if (postLoad != null)
		{
			postLoad();
		}
	}

	function getHaxeBytes(b:ByteArray)
	{
		// not sure how else to convert a ByteArray into haxe.io.Bytes :/
		var el_bytes = Bytes.alloc(b.length);
		for (i in 0...b.length)
		{
			el_bytes.fill(i, 1, b.readByte());
		}
		return el_bytes;
	}
}
