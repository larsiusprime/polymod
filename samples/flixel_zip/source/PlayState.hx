import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.ui.FlxInputText;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.graphics.Image;
import lime.utils.Bytes;
import openfl.display.BitmapData;
import openfl.events.Event;
import openfl.net.FileFilter;
import openfl.net.FileReference;
import openfl.utils.AssetManifest;
import openfl.utils.AssetType;
import openfl.utils.Assets;
import polymod.Polymod.Framework;
import polymod.Polymod;
import polymod.fs.MemoryZipFileSystem;

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

	var dirty = false;

	public override function create()
	{
		super.create();

		initPolymod();

		this.bgColor = 0xFFFFFFFF;

		makeButtons();
		#if html5
		makeHelpText();
		#end
		refresh();
	}

	#if html5
	var helpText:FlxText;

	private function makeHelpText()
	{
		helpText = new FlxText(0, FlxG.height - 150, 0, "Press SPACE to load a mod from a .ZIP file");
		helpText.setFormat(null, 12, FlxColor.BLACK);
		helpText.screenCenter(X);
		add(helpText);
	}

	function loadZipFile()
	{
		// Load a zip file as bytes and pass it to the MemoryZipFileSystem.
		var fileRef = new FileReference();
		fileRef.addEventListener(Event.SELECT, (e) ->
		{
			fileRef.load();
		});
		fileRef.addEventListener(Event.COMPLETE, (e) ->
		{
			var zipBytes:Bytes = fileRef.data;
			var zipName:String = fileRef.name;

			var fileSystem:MemoryZipFileSystem = cast Polymod.getFileSystem();
			if (fileSystem == null)
			{
				trace('Could not retrieve file system, got null');
				return;
			}
			fileSystem.addZipFile(zipName, zipBytes);

			trace('Loaded zip file $zipName, updating mod list');

			// We can't update the UI from a callback.
			dirty = true;
		});
		fileRef.browse([new FileFilter("Zip files", "*.zip")]);
	}
	#end

	private function makeButtons()
	{
		var modDir:String = '../../../mods';
		#if mac
		// account for <APPLICATION>.app/Contents/Resources
		modDir = '../../../$modDir';
		#end

		var modList = Polymod.scan({
			modRoot: modDir,
		});

		var xx = 10;
		var yy = 300;
		for (modMeta in modList)
		{
			trace('Adding widget for mod ${modMeta.title}');
			var w = new ModWidget(modMeta.id, onWidgetMove);
			w.x = xx;
			w.y = yy;

			widgets.push(w);

			xx += Std.int(w.width) + 10;

			w.fixButtons();

			add(w);
		}

		updateWidgets();
	}

	private function removeButtons()
	{
		for (w in widgets)
		{
			remove(w);
		}
		widgets.splice(0, widgets.length);
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
		#if html5
		if (FlxG.keys.justPressed.SPACE)
			loadZipFile();
		#end

		if (dirty)
		{
			dirty = false;

			removeButtons();
			makeButtons();
			refresh();
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
			trace('Drawing image $image');
			var sprite = new FlxSprite(xx, yy);

			var atlasPath = image.replace('.png', '.xml');
			if (Assets.exists(atlasPath))
			{
				trace('Building animated image $image');

				sprite.frames = FlxAtlasFrames.fromSparrow(image, Assets.getText(atlasPath));
				trace('Sprite graphic');
				trace(sprite.graphic);
				sprite.animation.addByPrefix('idle', 'idle', 24, true);
				sprite.animation.play('idle');
			}
			else
			{
				trace('Building static image $image');
				sprite.loadGraphic(image);
			}

			sprite.setGraphicSize(256, 256);
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

			var str = Assets.getText(t);
			if (str == null)
				str = 'null';

			var text = new FlxInputText(xx, yy, 250, str);
			text.setFormat("Arial", 12, 0xFF000000, FlxTextAlign.LEFT);
			text.height = 150;
			text.wordWrap = true;
			text.lines = 10;

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

	private function initPolymod()
	{
		var modDir:String = '../../../mods';
		#if mac
		// account for <APPLICATION>.app/Contents/Resources
		modDir = '../../../$modDir';
		#end

		Polymod.init({
			modRoot: modDir,
			dirs: [],
			errorCallback: onError,
			ignoredFiles: Polymod.getDefaultIgnoreList(),
			framework: Framework.FLIXEL,
			// Use the ZipFileSystem, which automatically works for either HTML5 or Desktop.
			customFilesystem: polymod.fs.ZipFileSystem
		});
	}

	private function loadMods(dirs:Array<String>)
	{
		trace('Loading mods: ${dirs}');

		var modDir:String = '../../../mods';
		#if mac
		// account for <APPLICATION>.app/Contents/Resources
		modDir = '../../../$modDir';
		#end

		var results = Polymod.loadOnlyMods(dirs);

		// Reload graphics before rendering again.
		var loadedMods = results.map(function(item:ModMetadata)
		{
			return item.id;
		});
		trace('Loaded mods: ${loadedMods}');

		#if html5
		for (thing in stuff)
		{
			remove(thing);
		}
		stuff.splice(0, stuff.length);

		new flixel.util.FlxTimer().start(0.5, (_) ->
		{
			trace('Delayed refresh');

			drawImages();
			drawText();
		}, 1);
		#else
		trace('Instant refresh');
		refresh();
		#end
	}

	private function onError(error:PolymodError)
	{
		trace('[${error.severity}] (${Std.string(error.code).toUpperCase()}): ${error.message}');
	}
}
