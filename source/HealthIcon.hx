package;

import flixel.math.FlxPoint;
import openfl.utils.Assets;
import haxe.Json;
#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end
import flixel.FlxSprite;
import flixel.math.FlxMath;


using StringTools;

typedef IconFile = {
	var ?noAntialiasing:Bool;
	var ?fps:Int; //Will only affect icons from Sparrow Atlas
	var ?hasWinIcon:Bool; //Will only affect icons from an icon grid, Sparrow Atlas icons have this automatically detected
	var ?yOffset:Float;
	var ?boppiness:Array<Float>;
	var ?oldIcon:String;
}

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	private var isOldIcon:Bool = false;
	private var isPlayer:Bool = false;
	private var char:String = '';
	private var yOffset:Float = 0;
	var originalChar:String = 'bf-old';
	public var iconJson:IconFile;

	public function new(char:String = 'bf', isPlayer:Bool = false)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 10, sprTracker.y - 30);
	}

	public function swapOldIcon() {
		var cur = char;
		var og = originalChar;
		char = og;
		originalChar = cur;
		isOldIcon = !isOldIcon && cur != og;
		changeIcon(char, true);
	}

	private var boppiness:FlxPoint = new FlxPoint(1.2, 1.2);
	private var iconOffsets:Array<Float> = [0, 0, 0];
	public function changeIcon(char:String, old:Bool = false) {
		if (old || this.char != char) {
			if (!old) iconJson = getFile(char);
			var name:String = 'icons/$char';
			if (!Paths.fileExists('images/$name.png', IMAGE)) {
				name = 'icons/icon-$char'; //Older versions of psych engine's support
			}
			if (!Paths.fileExists('images/$name.png', IMAGE)) {
				name = 'icons/icon-face'; //Prevents crash from missing icon
			}

			var div = 2;
			var winIcon = iconJson.hasWinIcon;
			if (Paths.fileExists('images/$name.xml', TEXT)) {
				frames = Paths.getSparrowAtlas(name);
				animation.addByPrefix('normal', 'normal', iconJson.fps, iconJson.fps > 0, isPlayer);
				animation.addByPrefix('losing', 'losing', iconJson.fps, iconJson.fps > 0, isPlayer);
				animation.addByPrefix('winning', 'winning', iconJson.fps, iconJson.fps > 0, isPlayer);
				if (!animation.exists('winning')) {
					animation.addByPrefix('winning', 'normal', iconJson.fps, iconJson.fps > 0, isPlayer);
				}
				animation.play('normal');
			} else {
				var file = Paths.image(name);
				loadGraphic(file); //Load stupidly first for getting the file size

				// to keep davids winning icon system and not the new stinky one
				if (winIcon == null) {
					var aspect3x1 = width / 3 == height;
					if (aspect3x1) div = 3;
					winIcon = winIcon || aspect3x1;
				}

				loadGraphic(file, true, Math.floor(width / div), Math.floor(height)); //Then load it fr

				animation.add('normal', [0], 0, false, isPlayer);
				animation.add('losing', [1], 0, false, isPlayer);
				animation.add('winning', [!!winIcon ? 2 : 0], 0, false, isPlayer);
				animation.play('normal');
			}
			iconOffsets[0] = (width - 150) / div;
			iconOffsets[1] = (width - 150) / div;
			iconOffsets[2] = (width - 150) / div;

			if (!old) {
				this.char = char;
				originalChar = iconJson.oldIcon;
				isOldIcon = false;
			}

			if (iconJson.boppiness != null)
				boppiness = new FlxPoint(iconJson.boppiness[0], iconJson.boppiness[1]);
			yOffset = iconJson.yOffset;
			updateHitbox();

			// make it only aliased when -pixel exists if `iconJson.noAntialiasing` is null
			antialiasing = ClientPrefs.globalAntialiasing && (!(iconJson.noAntialiasing == null && char.endsWith('-pixel')) && !iconJson.noAntialiasing);
		}
	}

	override function updateHitbox()
	{
		super.updateHitbox();
		offset.x = iconOffsets[0];
		offset.y = iconOffsets[1] + yOffset;
	}

	public function lerp(elapsed:Float) {
		scale.set(
			FlxMath.lerp(1, scale.x, CoolUtil.boundTo(1 - (elapsed * 9), 0, 1)),
			FlxMath.lerp(1, scale.y, CoolUtil.boundTo(1 - (elapsed * 9), 0, 1))
		);
		updateHitbox();
	}

	public function bop() {
		scale.copyFrom(boppiness);
		updateHitbox();
	}

	public function getCharacter():String {
		return char;
	}

	private static function checkPath(name:String):Null<String> {
		var charPath = 'images/icons/$name.json';

		#if MODS_ALLOWED
		var path:String = Paths.modFolders(charPath);
		if (FileSystem.exists(path)) return path;
		#end

		var path:String = Paths.getPreloadPath(charPath);
		if (#if MODS_ALLOWED FileSystem.exists(path) #else Assets.exists(path) #end) return path;

		return null;
	}

	public static function getFile(name:String):IconFile {
		var path:String;

		path = checkPath(name);

		// @CoolingTool: dont really wanna add -pixel to every json alright
		if (path == null && name.endsWith('-pixel'))
			path = checkPath(name.substring(0, name.length - ('-pixel').length));

		if (path == null)
			path = checkPath('bf'); //If a character couldn't be found, change them to BF just to prevent a crash

		#if MODS_ALLOWED
		var rawJson = File.getContent(path);
		#else
		var rawJson = Assets.getText(path);
		#end

		var json:IconFile = cast Json.parse(rawJson);
		if (json.fps == null) json.fps = 24;
		if (json.yOffset == null) json.yOffset = 0;
		if (json.oldIcon == null) json.oldIcon = 'bf-old';
		return json;
	}
}
