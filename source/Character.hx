package;

import flixel.util.FlxSort;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.input.keyboard.FlxKey;
import flixel.tweens.FlxTween;
import haxe.Json;
#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#else
import openfl.utils.Assets;
#end

using StringTools;

typedef CharacterFile = {
	var animations:Array<AnimArray>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var flip_x:Bool;
	var no_antialiasing:Bool;
	var pixel_snap:Bool;
	var healthbar_colors:Array<Int>;
}

typedef AnimArray = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Float>;
}

typedef CharacterGroupFile = {
	var characters:Array<GroupCharacter>;
	var position:Array<Float>;
	var healthicon:String;
	var camera_position:Array<Float>;
	var healthbar_colors:Array<Int>;
	var reversed_layers:Bool;
}

typedef GroupCharacter = {
	var name:String;
	var position:Array<Float>;
	var insert:Int;
}

class Character extends FarpSprite
{
	//public var animOffsets:Map<String, Array<Float>>;
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var colorTween:FlxTween;
	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var specialDance:Bool = false; // @CoolingTool: for dances that shouldnt be canceled by other dances
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	public var singDuration:Float = 4; //Multiplier of how long a character holds the sing pose
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; //Character use "danceLeft" and "danceRight" instead of "idle"
	public var danceEveryNumBeats:Float = 2;
	public var keysPressed:Array<FlxKey> = [];

	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];

	public var hasMissAnimations:Bool = false;

	//for double trails
	public var lastAnim:String = '';

	//Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var healthColorArray:Array<Int> = [255, 0, 0];
	public var healthbarYOffset:Float = 0;

	public static var DEFAULT_CHARACTER:String = 'bf'; //In case a character is missing, it will use BF on its place
	public function new(x:Float, y:Float, ?character:String = 'bf', ?flipped:Bool = false)
	{
		super(x, y);

		//animOffsets = new Map();
		curCharacter = character;
		antialiasing = ClientPrefs.globalAntialiasing;

		switch (curCharacter)
		{
			//case 'your character name in case you want to hardcode them instead':

			default:
				var json:CharacterFile = getFile(curCharacter);

				if (Paths.fileExists('images/${json.image}.txt', TEXT))
				{
					frames = Paths.getPackerAtlas(json.image);
				}
				else if (Paths.fileExists('images/${json.image}.json', TEXT))
				{
					frames = Paths.getTexturePackerAtlas(json.image);
				}
				else if (Paths.fileExists('images/${json.image}/Animation.json', TEXT))
				{
					frames = AtlasFrameMaker.construct(json.image);	
				}
				else
				{
					frames = Paths.getSparrowAtlas(json.image);
				}
				
				imageFile = json.image;

				if (json.scale != 1) {
					jsonScale = json.scale;
					setGraphicSize(Std.int(width * jsonScale));
					updateHitbox();
				}

				positionArray = json.position;
				cameraPosition = json.camera_position;

				healthIcon = json.healthicon;
				singDuration = json.sing_duration;
				flipX = !!json.flip_x;
				noAntialiasing = !!json.no_antialiasing;

				if (json.pixel_snap) {
					snapToPixelGrid = true;
					pixelSize = Std.int(jsonScale);
				}

				if (json.healthbar_colors != null && json.healthbar_colors.length > 2)
					healthColorArray = json.healthbar_colors;
				
				antialiasing = ClientPrefs.globalAntialiasing && !noAntialiasing;

				animationsArray = json.animations;
				if (animationsArray != null && animationsArray.length > 0) {
					for (anim in animationsArray) {
						var animAnim:String = '${anim.anim}';
						var animName:String = '${anim.name}';
						var animFps:Int = anim.fps;
						var animLoop:Bool = !!anim.loop; //Bruh
						var animIndices:Array<Int> = anim.indices;
						if (animIndices != null && animIndices.length > 0) {
							animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
						} else {
							animation.addByPrefix(animAnim, animName, animFps, animLoop);
						}

						if (anim.offsets != null && anim.offsets.length > 1) {
							addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
						}
					}
				} else {
					quickAnimAdd('idle', 'BF idle dance');
				}
		}
		originalFlipX = flipX;

		hasMissAnimations = (animOffsets.exists('singLEFTmiss') || animOffsets.exists('singDOWNmiss') || animOffsets.exists('singUPmiss') || animOffsets.exists('singRIGHTmiss'));
		recalculateDanceIdle();
		dance();

		if (flipped)
		{
			flipX = !flipX;
		}

		switch(curCharacter)
		{
			case 'pico-speaker':
				skipDance = true;
				loadMappedAnims();
				playAnim("shoot1");
		}
	}

	override function update(elapsed:Float)
	{
		if (!debugMode && animation.curAnim != null)
		{
			if (heyTimer > 0)
			{
				heyTimer -= elapsed;
				if (heyTimer <= 0)
				{
					if (specialAnim && animation.curAnim.name == 'hey' || animation.curAnim.name == 'cheer')
					{
						specialAnim = false;
						dance(false, true);
					}
					heyTimer = 0;
				}
			} else if (specialAnim && animation.curAnim.finished)
			{
				specialAnim = false;
				dance(false, true);
			}

			if (specialDance && animation.curAnim.finished)
				specialDance = false;

			switch(curCharacter)
			{
				case 'pico-speaker':
					if(animationNotes.length > 0 && Conductor.songPosition >= animationNotes[0][0])
					{
						var noteData:Int = 1;
						if(animationNotes[0][1] > 2) noteData = 3;

						noteData += FlxG.random.int(0, 1);
						playAnim('shoot' + noteData, true);
						animationNotes.shift();
					}
					if(animation.curAnim.finished) playAnim(animation.curAnim.name, false, false, animation.curAnim.frames.length - 3);
			}

			if (isPlayer) {
				if (singing()) {
					holdTimer += elapsed;
				} else {
					holdTimer = 0;
				}

				/*if (animation.curAnim.name.endsWith('miss') && animation.curAnim.finished)
				{
					dance();
					playAnim(animation.curAnim.name, true, false, animation.curAnim.numFrames - 1);
				}*/
			} else {
				if (singing()) {
					holdTimer += elapsed;
				}

				if (holdTimer >= getSingDuration() && finished()) {
					dance(false, true);
					holdTimer = 0;
				}
			}

			if (animation.curAnim.finished && animation.getByName('${animation.curAnim.name}-loop') != null)
			{
				playAnim('${animation.curAnim.name}-loop');
			}
		}
		super.update(elapsed);
	}

	public inline function singing() {
		return animation.curAnim != null && (animation.curAnim.name.startsWith('sing') || animation.curAnim.name.startsWith('dodge')) && !animation.curAnim.name.endsWith('-end');
	}

	// "*-loop" animations basically mean that the main animation finished
	public inline function finished() {
		return (animation.curAnim == null || animation.curAnim.name.endsWith('-loop') || animation.curAnim.finished);
	}

	public inline function getSingDuration() {
		return Conductor.normalizedStepCrochet * 0.0011 * ((animation.curAnim != null && animation.curAnim.name.startsWith('sing')) ? singDuration : 0.1e-9);
	}

	public function checkAnimEnd() {
		if (animation.curAnim != null && animation.getByName('${animation.curAnim.name}-end') != null) {
			playAnim('${animation.curAnim.name}-end', true);
			specialAnim = true;
			return true;
		}
		return false;
	}

	public var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance(?forceplay:Bool = false, ?special:Bool = false)
	{
		if (checkAnimEnd()) return;

		if (!debugMode && !skipDance && !specialAnim && !specialDance)
		{
			if (danceIdle)
			{
				danced = !danced;
				var idlePrefix = danced ? 'danceRight' : 'danceLeft';

				if (animation.getByName('$idlePrefix$idleSuffix') != null) {
					playAnim('$idlePrefix$idleSuffix', forceplay);
					specialDance = special;
				}
			}
			else if (animation.getByName('idle$idleSuffix') != null) {
				playAnim('idle$idleSuffix', forceplay);
				specialDance = special;
			}
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		specialAnim = false;
		specialDance = false;
		animation.play(AnimName, Force, Reversed, Frame);

		var daOffset = animOffsets.get(AnimName);
		if (animOffsets.exists(AnimName))
		{
			offset.set(daOffset[0], daOffset[1]);
		}
		else
			offset.set(0, 0);

		if (curCharacter.startsWith('gf'))
		{
			if (AnimName == 'singLEFT')
			{
				danced = true;
			}
			else if (AnimName == 'singRIGHT')
			{
				danced = false;
			}

			if (AnimName == 'singUP' || AnimName == 'singDOWN')
			{
				danced = !danced;
			}
		}
	}

	function loadMappedAnims():Void
	{
		if (PlayState.instance != null) {
			var song = Song.loadFromJson('picospeaker', Paths.formatToSongPath(PlayState.SONG.song));
			if (song != null) {
				var noteData:Array<SwagSection> = song.notes;
				for (section in noteData) {
					for (songNotes in section.sectionNotes) {
						animationNotes.push(songNotes);
					}
				}
				animationNotes.sort(sortAnims);
			}
		}
	}

	function sortAnims(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	private var settingCharacterUp:Bool = true;
	public function recalculateDanceIdle() {
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (animation.getByName('danceLeft$idleSuffix') != null && animation.getByName('danceRight$idleSuffix') != null);
		if(settingCharacterUp)
		{
			danceEveryNumBeats = (danceIdle ? 1 : 2);
			settingCharacterUp = false;
		}
		else if(lastDanceIdle != danceIdle)
		{
			var calc:Float = danceEveryNumBeats;
			if(danceIdle)
				calc /= 2;
			else
				calc *= 2;

			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = [x, y];
	}

	public function quickAnimAdd(name:String, anim:String)
	{
		animation.addByPrefix(name, anim, 24, false);
	}

	public static function getFile(name:String):Dynamic {
		var characterPath:String = 'characters/$name.json';
		#if MODS_ALLOWED
		var path:String = Paths.modFolders(characterPath);
		if (!FileSystem.exists(path)) {
			path = Paths.getPreloadPath(characterPath);
		}

		if (!FileSystem.exists(path))
		#else
		var path:String = Paths.getPreloadPath(characterPath);
		if (!Assets.exists(path))
		#end
		{
			path = Paths.getPreloadPath('characters/$DEFAULT_CHARACTER.json'); //If a character couldn't be found, change them to BF just to prevent a crash
		}

		#if MODS_ALLOWED
		var rawJson = File.getContent(path);
		#else
		var rawJson = Assets.getText(path);
		#end

		if (rawJson == null) {
			return null;
		}

		var json = cast Json.parse(rawJson);
		return json;
	}
}
