package;

import flash.media.Sound;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.Json;
import haxe.io.Path;
import lime.app.Promise;
import lime.app.Future;
import lime.utils.AssetLibrary;
import lime.utils.AssetManifest;
import lime.utils.Assets;
import openfl.system.System;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
#if MODS_ALLOWED
import openfl.display.BitmapData;
#end
#if sys
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;

class Paths
{
	inline public static var SOUND_EXT = "ogg";
	public static final VIDEO_EXT = ['mp4', 'webm', 'mov', 'wmv', 'avi', 'flv'];

	#if MODS_ALLOWED
	public static var ignoreModFolders:Array<String> = [
		'characters',
		'custom_events',
		'custom_notetypes',
		'data',
		'songs',
		'music',
		'sounds',
		'videos',
		'images',
		'stages',
		'weeks',
		'fonts',
		'scripts'
	];
	#end
	public static var ignoreLibraries:Array<String> = [
		'default',
		'shared',
		'songs',
		'videos'
	];

	public static function excludeAsset(key:String) {
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static var dumpExclusions:Array<String> =
	[
		'assets/images/alphabet.png',
		'assets/sounds/scrollMenu.$SOUND_EXT',
		'assets/sounds/confirmMenu.$SOUND_EXT',
		'assets/sounds/cancelMenu.$SOUND_EXT',
		'assets/music/freakyMenu.$SOUND_EXT',
		'shared:assets/shared/music/breakfast.$SOUND_EXT',
		'shared:assets/shared/music/cooldown.$SOUND_EXT',
		'shared:assets/shared/music/tea-time.$SOUND_EXT'
	];
	/// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory() {
		// clear non local assets in the tracked assets list
		for (key in currentTrackedAssets.keys()) {
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key) 
				&& !dumpExclusions.contains(key)) {
				// get rid of it
				var obj = currentTrackedAssets.get(key);
				@:privateAccess
				if (obj != null) {
					OpenFlAssets.cache.removeBitmapData(key);
					FlxG.bitmap._cache.remove(key);
					obj.destroy();
					currentTrackedAssets.remove(key);
				}
			}
		}
		// run the garbage collector for good measure lmfao
		System.gc();
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];
	public static function clearStoredMemory() {
		// clear anything not in the tracked assets list
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			var obj = FlxG.bitmap._cache.get(key);
			if (obj != null && !currentTrackedAssets.exists(key)) {
				OpenFlAssets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				obj.destroy();
			}
		}

		// clear all sounds that are cached
		for (key in currentTrackedSounds.keys()) {
			if (key != null && !localTrackedAssets.contains(key) 
			&& !dumpExclusions.contains(key)) {
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}	
		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		OpenFlAssets.cache.clear("songs");
	}

	static public function loadLibraryManifest(id:String):Future<AssetLibrary> {
		var promise = new Promise<AssetLibrary>();

		var library = Assets.getLibrary(id);

		if (library != null)
		{
			return Future.withValue(library);
		}

		var path = id;
		var rootPath = null;

		@:privateAccess
		var libraryPaths = Assets.libraryPaths;
		if (libraryPaths.exists(id))
		{
			path = libraryPaths[id];
			rootPath = Path.directory(path);
		}
		else
		{
			if (StringTools.endsWith(path, ".bundle"))
			{
				rootPath = path;
				path += "/library.json";
			}
			else
			{
				rootPath = Path.directory(path);
			}
			@:privateAccess
			path = Assets.__cacheBreak(path);
		}

		AssetManifest.loadFromFile(path, rootPath).onComplete(function(manifest)
		{
			if (manifest == null)
			{
				promise.error('Cannot parse asset manifest for library "$id"');
				return;
			}

			var library = AssetLibrary.fromManifest(manifest);

			if (library == null)
			{
				promise.error('Cannot open library "$id"');
			}
			else
			{
				@:privateAccess
				Assets.libraries.set(id, library);
				library.onChange.add(Assets.onChange.dispatch);
				promise.completeWith(Future.withValue(library));
			}
		}).onError(function(_)
		{
			promise.error('There is no asset library with an ID of "$id"');
		});

		return promise.future;
	}

	static public function getLibraries(ignore:Bool = false):Array<String> {
		var libraries:Array<String> = [];
		@:privateAccess
		for (i in Assets.libraryPaths.keys()) {
			if (!ignore || !ignoreLibraries.contains(i))
				libraries.push(i);
		}
		return libraries;
	}

	static public var currentModDirectory:String = '';
	static public var currentLevel:String;
	static public function setCurrentLevel(name:String)
	{
		currentLevel = name.toLowerCase();
	}

	public static function getPath(file:String, type:AssetType, library:String = null)
	{
		if (library != null)
			return getLibraryPath(file, library);

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if (currentLevel != 'shared') {
				levelPath = getLibraryPathForce(file, currentLevel);
				if (OpenFlAssets.exists(levelPath, type))
					return levelPath;
			}

			levelPath = getLibraryPathForce(file, "shared");
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}

		return getPreloadPath(file);
	}

	static public function getLibraryPath(file:String, library = "preload")
	{
		return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);
	}

	inline static function getLibraryPathForce(file:String, library:String)
	{
		var returnPath = '$library:assets/$library/$file';
		return returnPath;
	}

	inline public static function getPreloadPath(file:String = '')
	{
		return 'assets/$file';
	}

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
	{
		return getPath(file, type, library);
	}

	inline static public function txt(key:String, ?library:String)
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	inline static public function xml(key:String, ?library:String)
	{
		return getPath('images/$key.xml', TEXT, library);
	}

	inline static public function json(key:String, ?library:String)
	{
		return getPath('data/$key.json', TEXT, library);
	}

	inline static public function lua(key:String, ?library:String)
	{
		return getPath('$key.lua', TEXT, library);
	}

	static public function video(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsVideo(key);
		if (FileSystem.exists(file)) {
			return file;
		}
		#end
		for (i in VIDEO_EXT) {
			var path = 'assets/videos/$key.$i';
			#if MODS_ALLOWED
			if (FileSystem.exists(path))
			#else
			if (OpenFlAssets.exists(path))
			#end
			{
				return path;
			}
		}
		return 'assets/videos/$key.mp4';
	}

	static public function sound(key:String, ?library:String):Sound
	{
		var sound:Sound = returnSound('sounds', key, library);
		return sound;
	}
	
	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	inline static public function music(key:String, ?library:String):Sound
	{
		var file:Sound = returnSound('music', key, library);
		return file;
	}

	inline static public function voices(song:String, ?suffix:String = ''):Sound
	{
		var songKey:String = '${formatToSongPath(song)}';
		var voices = returnSound(songKey, 'Voices$suffix', 'songs', false);
		if (voices == null && suffix.length > 0) {
			voices = returnSound(songKey, 'Voices', 'songs');
		}
		return voices;
	}

	inline static public function inst(song:String, ?suffix:String = ''):Sound
	{
		var songKey:String = '${formatToSongPath(song)}';
		var inst = returnSound(songKey, 'Inst$suffix', 'songs', false);
		if (inst == null && suffix.length > 0) {
			inst = returnSound(songKey, 'Inst', 'songs');
		}
		return inst;
	}

	static public function voicesDad(song:String, ?suffix:String = ''):Sound
	{
		var songKey:String = '${formatToSongPath(song)}';
		var suffixes = ['Dad', 'Opponent'];
		for (dadSuffix in suffixes) {
			var voices = returnSound(songKey, 'Voices$dadSuffix$suffix', 'songs', false);
			if (voices == null && suffix.length > 0) {
				voices = returnSound(songKey, 'Voices$dadSuffix', 'songs', false);
			}
			if (voices != null) {
				return voices;
			}
		}
		return null;
	}

	inline static public function intro(song:String, ?suffix:String = ''):Sound
	{
		var songKey:String = '${song.toLowerCase().replace(' ', '-')}';
		var inst = returnSound(songKey, 'intro$suffix', 'songs');
		return inst;
	}

	inline static public function image(key:String, ?library:String):FlxGraphic
	{
		// streamlined the assets process more
		var returnAsset:FlxGraphic = returnGraphic(key, library);
		return returnAsset;
	}

	static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		#if MODS_ALLOWED
		if (!ignoreMods && FileSystem.exists(modFolders(key)))
			return File.getContent(modFolders(key));

		if (FileSystem.exists(getPreloadPath(key)))
			return File.getContent(getPreloadPath(key));
		#end

		return Assets.getText(getPath(key, TEXT));
	}

	inline static public function font(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsFont(key);
		if (FileSystem.exists(file)) {
			return file;
		}
		#end
		return 'assets/fonts/$key';
	}

	inline static public function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?library:String)
	{
		#if MODS_ALLOWED
		if (!ignoreMods && (FileSystem.exists(mods('$currentModDirectory/' + (library != null ? '$library/' : '') + '$key')) || FileSystem.exists(mods((library != null ? '$library/' : '') + key)))) {
			return true;
		}
		#end
		
		if (OpenFlAssets.exists(getPath(key, type, library))) {
			return true;
		}
		return false;
	}

	inline static public function getSparrowAtlas(key:String, ?library:String)
	{
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key);
		var xmlExists:Bool = false;
		if (FileSystem.exists(modsXml(key))) {
			xmlExists = true;
		}
		return FlxAtlasFrames.fromSparrow((imageLoaded != null ? imageLoaded : image(key, library)), (xmlExists ? File.getContent(modsXml(key)) : file('images/$key.xml', library)));
		#else
		return FlxAtlasFrames.fromSparrow(image(key, library), file('images/$key.xml', library));
		#end
	}


	inline static public function getPackerAtlas(key:String, ?library:String)
	{
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key);
		var txtExists:Bool = false;
		if (FileSystem.exists(modsTxt(key))) {
			txtExists = true;
		}

		return FlxAtlasFrames.fromSpriteSheetPacker((imageLoaded != null ? imageLoaded : image(key, library)), (txtExists ? File.getContent(modsTxt(key)) : file('images/$key.txt', library)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, library), file('images/$key.txt', library));
		#end
	}

	inline static public function getTexturePackerAtlas(key:String, ?library:String)
	{
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key);
		var jsonExists:Bool = false;
		if (FileSystem.exists(modsJson(key))) {
			jsonExists = true;
		}
		return FlxAtlasFrames.fromTexturePackerJson((imageLoaded != null ? imageLoaded : image(key, library)), (jsonExists ? File.getContent(modsJson(key)) : file('images/$key.json', library)));
		#else
		return FlxAtlasFrames.fromTexturePackerJson(image(key, library), file('images/$key.json', library));
		#end
	}

	inline static public function formatToSongPath(path:String) {
		return path.toLowerCase().replace(' ', '-');
	}

	// completely rewritten asset loading? fuck!
	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	public static function returnGraphic(key:String, ?library:String) {
		#if MODS_ALLOWED
		var modKey:String = modsImages(key);
		if(FileSystem.exists(modKey)) {
			if(!currentTrackedAssets.exists(modKey)) {
				var newBitmap:BitmapData = BitmapData.fromFile(modKey);
				var newGraphic:FlxGraphic = FlxGraphic.fromBitmapData(newBitmap, false, modKey);
				newGraphic.persist = true;
				currentTrackedAssets.set(modKey, newGraphic);
			}
			localTrackedAssets.push(modKey);
			return currentTrackedAssets.get(modKey);
		}
		#end
		var path = getPath('images/$key.png', IMAGE, library);
		if (OpenFlAssets.exists(path, IMAGE)) {
			if(!currentTrackedAssets.exists(path)) {
				var newGraphic:FlxGraphic = FlxG.bitmap.add(path, false, path);
				newGraphic.persist = true;
				currentTrackedAssets.set(path, newGraphic);
			}
			localTrackedAssets.push(path);
			return currentTrackedAssets.get(path);
		}
		trace('oh no its returning null NOOOO: $path');
		return null;
	}

	public static var currentTrackedSounds:Map<String, Sound> = [];
	public static function returnSound(path:String, key:String, ?library:String, doTrace:Bool = true) {
		#if MODS_ALLOWED
		var file:String = modsSounds((library != null ? '$library/' : '') + path, key);
		if (FileSystem.exists(file)) {
			if (!currentTrackedSounds.exists(file)) {
				currentTrackedSounds.set(file, Sound.fromFile(file));
			}
			localTrackedAssets.push(file);
			return currentTrackedSounds.get(file);
		}
		#end
		// I hate this so god damn much
		var gottenPath:String = getPath('$path/$key.$SOUND_EXT', SOUND, library);
		if (!OpenFlAssets.exists(gottenPath))
		{
			if (doTrace) trace('oh no its returning null NOOOO: $gottenPath');
			return null;
		}
		if (!currentTrackedSounds.exists(gottenPath)) {
			var folder:String = '';
			if(path == 'songs') folder = 'songs:';
			
			currentTrackedSounds.set(gottenPath, OpenFlAssets.getSound(folder + getPath('$path/$key.$SOUND_EXT', SOUND, library)));
		}
		localTrackedAssets.push(gottenPath);
		return currentTrackedSounds.get(gottenPath);
	}

	inline public static function getContent(path:String) {
		#if sys
		return File.getContent(path);
		#else
		return OpenFlAssets.getText(path);
		#end
	}
	
	#if MODS_ALLOWED
	inline static public function mods(key:String = '') {
		return 'mods/$key';
	}
	
	inline static public function modsFont(key:String) {
		return modFolders('fonts/$key');
	}

	inline static public function modsData(key:String) {
		return modFolders('data/$key.json');
	}

	inline static public function modsDataTxt(key:String) {
		return modFolders('data/$key.txt');
	}

	static public function modsVideo(key:String) {
		for (i in VIDEO_EXT) {
			var path = modFolders('videos/$key.$i');
			if (FileSystem.exists(path))
			{
				return path;
			}
		}
		return modFolders('videos/$key.mp4');
	}

	inline static public function modsSounds(path:String, key:String) {
		return modFolders('$path/$key.$SOUND_EXT');
	}

	inline static public function modsImages(key:String) {
		return modFolders('images/$key.png');
	}

	inline static public function modsXml(key:String) {
		return modFolders('images/$key.xml');
	}

	inline static public function modsTxt(key:String) {
		return modFolders('images/$key.txt');
	}

	inline static public function modsJson(key:String) {
		return modFolders('images/$key.json');
	}

	static public function modFolders(key:String) {
		if (currentModDirectory != null && currentModDirectory.length > 0) {
			var fileToCheck:String = mods('$currentModDirectory/$key');
			if (FileSystem.exists(fileToCheck)) {
				return fileToCheck;
			}
		}
		for(mod in getGlobalMods()){
			var fileToCheck:String = mods(mod + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;

		}
		return 'mods/$key';
	}

	public static var globalMods:Array<String> = [];

	static public function getGlobalMods()
		return globalMods;

	static public function pushGlobalMods() // prob a better way to do this but idc
	{
		globalMods = [];
		var path:String = 'modsList.txt';
		if(FileSystem.exists(path))
		{
			var list:Array<String> = CoolUtil.coolTextFile(path);
			for (i in list)
			{
				var dat = i.split("|");
				if (dat[1] == "1")
				{
					var folder = dat[0];
					var path = Paths.mods(folder + '/pack.json');
					if(FileSystem.exists(path)) {
						try{
							var rawJson:String = File.getContent(path);
							if(rawJson != null && rawJson.length > 0) {
								var stuff:Dynamic = Json.parse(rawJson);
								var global:Bool = Reflect.getProperty(stuff, "runsGlobally");
								if(global)globalMods.push(dat[0]);
							}
						} catch(e:Dynamic){
							trace(e);
						}
					}
				}
			}
		}
		return globalMods;
	}

	static public function getModDirectories():Array<String> {
		var list:Array<String> = [];
		var modsFolder:String = mods();
		if (FileSystem.exists(modsFolder)) {
			for (folder in FileSystem.readDirectory(modsFolder)) {
				var path = Path.join([modsFolder, folder]);
				if (FileSystem.isDirectory(path) && !ignoreModFolders.contains(folder) && !list.contains(folder)) {
					list.push(folder);
				}
			}
		}
		return list;
	}
	#end
}
