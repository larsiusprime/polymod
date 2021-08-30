package polymod.backends;
import lime.graphics.Image;
import lime.media.AudioBuffer;
import lime.text.Font;
import lime.utils.AssetType;
import lime.utils.Assets;
import openfl.events.Event;
import openfl.events.EventDispatcher;
import polymod.backends.LimeBackend.LimeModLibrary;

/**
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

/**
 * This class is so mods can be loaded by OpenFL applications running in Electron/Node.
 * IMPORTANT:
 * In order for this to work, you need to configure the BrowserWindow's webPreference
 * for your node application to have 'nodeIntegration' to 'true' and 'contextIsolation' set to 'false'
 * Otherwise, you will not get access to the file system
 * 
 * For example:
 * const { app, BrowserWindow } = require('electron')
 * function createWindow () {
 *  const win = new BrowserWindow({
 *    width: 1600,
 *    height: 900,
 *	// frame: false,
 *	useContentSize: true,
 *    webPreferences: { // !!! THE IMPORTANT PART
 *	    nodeIntegration: true, // required for file system access
 *      contextIsolation: false // required for file system access
 *    }
 *  })
 *}
 * 
 */

/**
 * @author Tamar Curry
 */
#if (!openfl || nme)
class OpenFLWithNodeBackend extends StubBackend
{
	/**
	 * Event that is dispatched when all assets are finished preloading.
	 */
	public static inline var FINISHED_PRELOADING_ASSETS:String = "OpenFLWithNodeBackend.finishedPreloadingAssets";
	private static var _dispatcher:EventDispatcher;
	
	public static var dispatcher(get, null):EventDispatcher;
	
	// -----------------------------------------------------------------------------------------------
	// -----------------------------------------------------------------------------------------------
    public function new()
    {
        super();
        Polymod.error(FAILED_CREATE_BACKEND,"OpenFLWithNodeBackend requires the openfl library, did you forget to install it?"); 
    }
	
	// -----------------------------------------------------------------------------------------------
	private static function get_dispatcher():EventDispatcher
	{
		if ( _dispatcher == null ) {
			_dispatcher = new EventDispatcher();
		}
		return _dispatcher;
	}
}
#else
#if !nme
class OpenFLWithNodeBackend extends OpenFLBackend
{
	/**
	 * Event that is dispatched when all assets are finished preloading.
	 */
	public static inline var FINISHED_PRELOADING_ASSETS:String = "OpenFLWithNodeBackend.finishedPreloadingAssets";
	private static var _dispatcher:EventDispatcher;
	
	public static var dispatcher(get, null):EventDispatcher;
	
	// -----------------------------------------------------------------------------------------------
	// -----------------------------------------------------------------------------------------------
	public function new() 
	{
		super();
	}
	
	// -----------------------------------------------------------------------------------------------
	override public function init()
    {
        fallback = Assets.getLibrary("default");
        modLibrary = new OpenFLNodeModLibrary(this);
        Assets.registerLibrary("default", modLibrary);
    }
	
	// -----------------------------------------------------------------------------------------------
	private static function get_dispatcher():EventDispatcher
	{
		if ( _dispatcher == null ) {
			_dispatcher = new EventDispatcher();
		}
		return _dispatcher;
	}
}

//////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * 
 */
class OpenFLNodeModLibrary extends LimeModLibrary
{
	private var _imagePreloadCount:Int;
	private var _audioPreloadCount:Int;
	private var _textPreloadCount:Int;
	private var _fontPreloadCount:Int;
	
	// -----------------------------------------------------------------------------------------------
	/**
	 * Constructor
	 * @param	backend
	 */
	public function new(backend:OpenFLWithNodeBackend)
    {
		super(backend);
		preloadAssets();
	}
	
	// -----------------------------------------------------------------------------------------------
	/**
	 * Checks to see what assets were preloaded and if there are any corresponding mod assets to load in their place.
	 */
	private function preloadAssets():Void
	{
		var imagesToPreload:Array<String> = [];
		var audioToPreload:Array<String> = [];
		var textToPreload:Array<String> = [];
		var fontsToPreload:Array<String> = [];
		
		// if any embedded assets have been loaded already, attempt to load any replacements
		if ( hasFallback ) {
			for ( s in fallback.cachedImages.keys() )
			{
				if ( p.check(s) ) {
					imagesToPreload.push(s);
				}
			}
			
			for ( s in fallback.cachedAudioBuffers.keys() )
			{
				if ( p.check(s) ) {
					audioToPreload.push(s);
				}
			}
			
			for ( s in fallback.cachedText.keys() )
			{
				if ( p.check(s) ) {
					textToPreload.push(s);
				}
			}
			
			for ( s in fallback.cachedFonts.keys() )
			{
				if ( p.check(s) ) {
					fontsToPreload.push(s);
				}
			}
		}
		
		_imagePreloadCount 	= imagesToPreload.length;
		_audioPreloadCount 	= audioToPreload.length;
		_textPreloadCount 	= textToPreload.length;
		_fontPreloadCount 	= fontsToPreload.length;
		
		for ( s in imagesToPreload ) {
			loadImage(s).onComplete( onImagePreloaded );
		}
		
		for ( s in audioToPreload ) {
			loadAudioBuffer(s).onComplete( onAudioPreloaded );
		}
		
		for ( s in textToPreload ) {
			loadText(s).onComplete( onTextPreloaded );
		}
		
		for ( s in fontsToPreload ) {
			loadFont(s).onComplete( onFontPreloaded );
		}
		
		checkIfPreloadFinished();
	}
	
	// -----------------------------------------------------------------------------------------------
	/**
	 * Callback for images that are preloading.
	 * @param	x
	 */
	private function onImagePreloaded(x:Image):Void
	{
		--_imagePreloadCount;
		checkIfPreloadFinished();
	}
	
	// -----------------------------------------------------------------------------------------------
	/**
	 * Callback for audio that is preloading.
	 * @param	x
	 */
	private function onAudioPreloaded(x:AudioBuffer):Void
	{
		--_audioPreloadCount;
		checkIfPreloadFinished();
	}
	
	// -----------------------------------------------------------------------------------------------
	/**
	 * Callback for text that is preloading.
	 * @param	x
	 */
	private function onTextPreloaded(x:String):Void
	{
		--_textPreloadCount;
		checkIfPreloadFinished();
	}
	
	// -----------------------------------------------------------------------------------------------
	/**
	 * Callback for font that is preloading.
	 * @param	x
	 */
	private function onFontPreloaded(x:Font):Void
	{
		--_fontPreloadCount;
		checkIfPreloadFinished();
	}
	
	// -----------------------------------------------------------------------------------------------
	/**
	 * Check if all assets are finished preloading.
	 * If so, dispatch OpenFLWithNodeBackend.FINISHED_PRELOADING_ASSETS
	 */
	private function checkIfPreloadFinished():Void
	{
		var isFinished:Bool = true;
		isFinished = isFinished && _imagePreloadCount <= 0;
		isFinished = isFinished && _audioPreloadCount <= 0;
		isFinished = isFinished && _textPreloadCount <= 0;
		isFinished = isFinished && _fontPreloadCount <= 0;
		
		if ( isFinished ) {
			OpenFLWithNodeBackend.dispatcher.dispatchEvent( new Event(OpenFLWithNodeBackend.FINISHED_PRELOADING_ASSETS) );
		}
	}
	
	// -----------------------------------------------------------------------------------------------
    public override function isLocal (id:String, type:String):Bool
    {
		// because images and other assets are loaded asynchronously in HTML5 even if set the data directly,
		// we need to modify the isLocal call to check the cached assets
        if (p.check(id))
		{
			return checkIfAssetIsCached(id, type);
		}
        else if (hasFallback)
		{
            return fallback.isLocal(id, type);
		}
        return false;
    }
	
	// -----------------------------------------------------------------------------------------------
	/**
	 * Checks if the specified asset has already been loaded.
	 * Copied from the origina isLocal function in lime.utils.AssetLibrary
	 * @param	id
	 * @param	type
	 * @return
	 */
	private function checkIfAssetIsCached(id:String, type:String):Bool
	{
		if (classTypes.exists(id))
		{
			return true;
		}

		var requestedType = type != null ? cast(type, AssetType) : null;

		return switch (requestedType)
		{
			case IMAGE:
				cachedImages.exists(id);

			case MUSIC, SOUND:
				cachedAudioBuffers.exists(id);

			case FONT:
				cachedFonts.exists(id);

			default: cachedBytes.exists(id) || cachedText.exists(id);
		}
	}
}
#end
#end