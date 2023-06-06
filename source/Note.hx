package;

import SkinData.SkinFileData;
import editors.ChartingState;

using StringTools;

typedef EventNote = {
	strumTime:Float,
	event:String,
	value1:String,
	value2:String
}

class Note extends FarpSprite
{
	public var extraData:Map<String,Dynamic> = [];
	
	public var strumTime:Float = 0;

	public var mustPress:Bool = false;
	public var isOpponent:Bool = false;
	public var opponentChart:Bool = false;
	public var noteData:Int = 0;
	public var canBeHit:Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var ignoreNote:Bool = false;
	public var hitByOpponent:Bool = false;
	public var prevNote:Note;
	public var nextNote:Note;
	public var characters:Array<Int> = [0];

	public var spawned:Bool = false;

	public var tail:Array<Note> = []; // for sustains
	public var parent:Note;

	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;
	public var isTailNote:Bool = false;
	public var stepCrochet:Float = 150;
	public var bpm:Float = 100;

	public var noteType(default, set):String = null;

	public var eventName:String = '';
	public var eventLength:Int = 0;
	public var eventVal1:String = '';
	public var eventVal2:String = '';

	public var skinFile:SkinFileData;
	public var colorSwap:ColorSwap;
	public var skinModifier:String;
	public var inEditor:Bool = false;

	public var animSuffix:String = '';
	public var gfNote:Bool = false;
	public var earlyHitMult:Float = 0.5;
	public var lateHitMult:Float = 1;
	public var lowPriority:Bool = false;
	
	#if MULTI_KEY_ALLOWED
	public static var MAX_KEYS:Int = 13;
	#end
	public static var PURP_NOTE:Int = 0;
	public static var BLUE_NOTE:Int = 1;
	public static var GREEN_NOTE:Int = 2;
	public static var RED_NOTE:Int = 3;
	public static var DEFAULT_NOTE_SIZE:Float = 0.7;

	// Lua shit
	public var noteSplashDisabled:Bool = false;
	public var noteSplashTexture:String = null;
	public var noteSplashHue:Float = 0;
	public var noteSplashSat:Float = 0;
	public var noteSplashBrt:Float = 0;

	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var offsetAngle:Float = 0;
	public var multAlpha:Float = 1;
	public var multSpeed(default, set):Float = 1;

	public var centerX:Bool = true;
	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAngle:Bool = true;
	public var copyAlpha:Bool = true;
	public var copyScale:Bool = false;

	public var hitHealth:Float = 0.023;
	public var missHealth:Float = 0.0475;
	public var rating:String = 'unknown';
	public var ratingMod:Float = -1; //-1 = unknown, 0 = shit, 0.5 = bad, 0.75 = good, 1 = sick
	public var ratingDisabled:Bool = false;
	public var comboDisabled:Bool = false; // added by @CoolingTool
	public var alwaysSick:Bool = false; // added by @CoolingTool

	public var texture(default, set):String = null;

	public var noAnimation:Bool = false;
	public var noMissAnimation:Bool = false;
	public var hitCausesMiss:Bool = false;
	public var distance:Float = 2000;

	public var hitsoundDisabled:Bool = false;

	public var keyAmount:Int = 4;
	public var swagWidth:Float = 160 * DEFAULT_NOTE_SIZE;
	public var colors:Array<String> = ['left', 'down', 'up', 'right'];
	public var xOff:Float = 54;
	public var noteSize:Float = DEFAULT_NOTE_SIZE;
	public var pixelNoteSize:Float;

	private function set_multSpeed(value:Float):Float {
		resizeByRatio(value / multSpeed);
		multSpeed = value;
		return value;
	}

	public function scalePixelSustain(Scale:Float, Pad:Float = 1) {
		scale.y = Math.floor((Scale * frameHeight) / pixelSize + Pad) * pixelSize / frameHeight;
	}

	public var storedYscale:Null<Float>;
	public function resizeByRatio(ratio:Float) //haha funny twitter shit
	{
		if(isSustainNote && animation.curAnim != null && !animation.curAnim.name.endsWith('end'))
		{
			if (storedYscale == null)
				storedYscale = scale.y;

			storedYscale *= ratio;

			if (snapToPixelGrid) {
				scalePixelSustain(storedYscale);
			} else {
				scale.y = storedYscale;
			}

			updateHitbox();
		}
	}

	private function set_texture(value:String):String {
		if (texture != value) {
			reloadNote('', value);
		}
		texture = value;
		return value;
	}

	private function set_noteType(value:String):String {
		if (noteData > -1) {
			noteSplashTexture = 'noteSplashes';
			colorSwap.hue = ClientPrefs.arrowHSV[keyAmount - 1][noteData][0] / 360;
			colorSwap.saturation = ClientPrefs.arrowHSV[keyAmount - 1][noteData][1] / 100;
			colorSwap.brightness = ClientPrefs.arrowHSV[keyAmount - 1][noteData][2] / 100;
			if (noteType != value) {
				switch(value) {
					case 'Hurt Note':
						ignoreNote = opponentChart || !isOpponent;
						reloadNote('HURT');
						noteSplashTexture = 'HURTnoteSplashes';
						colorSwap.hue = 0;
						colorSwap.saturation = 0;
						colorSwap.brightness = 0;
						lowPriority = true;

						if (isSustainNote) {
							missHealth = 0.1;
						} else {
							missHealth = 0.3;
						}
						hitCausesMiss = true;
					case 'Alt Animation':
						animSuffix = '-alt';
					case 'Void Note': // @ThaumcraftMC: Void Note, but it's mostly a copy of Hurt Note, feel free to change it as you see fit lol.
						ignoreNote = opponentChart || !isOpponent;
						reloadNote('VOID');
						noteSplashTexture = 'VOIDnoteSplashes';
						colorSwap.hue = 0;
						colorSwap.saturation = 0;
						colorSwap.brightness = 0;
						hitCausesMiss = true;
						lowPriority = true;
						missHealth = 0;
					case 'Void Tendril':
						if (inEditor) reloadNote('TENDRIL'); // only for chart editor
						noteSplashDisabled = true;
						comboDisabled = true;
						alwaysSick = true;
						hitHealth = 0;
						missHealth = 0;
						offsetX = 10000; // basically invisible
					case 'No Animation':
						noAnimation = true;
						noMissAnimation = true;
					case 'GF Sing':
						gfNote = true;
				}
				noteType = value;
			}
			noteSplashHue = colorSwap.hue;
			noteSplashSat = colorSwap.saturation;
			noteSplashBrt = colorSwap.brightness;
		}
		return value;
	}

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?inEditor:Bool = false, ?keyAmount:Int = 4, ?stepCrochet:Float = 150, skinModifier:String)
	{
		super();

		if (prevNote == null)
			prevNote = this;

		this.prevNote = prevNote;
		isSustainNote = sustainNote;
		this.inEditor = inEditor;
		this.keyAmount = keyAmount;
		this.stepCrochet = stepCrochet;
		this.skinModifier = skinModifier;

		swagWidth = Std.parseFloat(CoolUtil.coolTextFile(Paths.txt('note_spacings'))[keyAmount-1]);
		colors = CoolUtil.coolArrayTextFile(Paths.txt('note_colors'))[keyAmount-1];
		xOff = Std.parseFloat(CoolUtil.coolTextFile(Paths.txt('note_offsets'))[keyAmount-1]);
		noteSize = Std.parseFloat(CoolUtil.coolTextFile(Paths.txt('note_sizes'))[keyAmount-1]);
		pixelNoteSize = noteSize / DEFAULT_NOTE_SIZE * PlayState.daPixelZoom;

		x += (ClientPrefs.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X) + xOff;
		// MAKE SURE ITS DEFINITELY OFF SCREEN?
		y -= 2000;
		this.strumTime = strumTime;
		if (!inEditor) this.strumTime += ClientPrefs.noteOffset;

		this.noteData = noteData % keyAmount;
		if (noteData > -1) {
			texture = '';
			colorSwap = new ColorSwap();
			shader = colorSwap.shader;

			x += swagWidth * noteData;
			if (!isSustainNote) { //Doing this 'if' check to fix the warnings on Senpai songs
				animation.play(colors[noteData]);
			}
		}

		if(prevNote != null)
			prevNote.nextNote = this;

		if (isSustainNote && prevNote != null) {
			if (!prevNote.skinFile.folder.endsWith('place')) {
				multAlpha = 0.6;
				alpha = 0.6;
			}

			hitsoundDisabled = true;
			if (ClientPrefs.downScroll) flipY = true;

			offsetX += width / 2;
			copyAngle = false;

			animation.play('${colors[noteData]}holdend');
			isTailNote = true;

			updateHitbox();

			offsetX -= width / 2;

			if (prevNote.isSustainNote)
			{
				prevNote.animation.play('${colors[prevNote.noteData]}hold');
				prevNote.isTailNote = false;

				prevNote.scale.y *= prevNote.stepCrochet / 100 * 1.05;
				if (PlayState.instance != null) {
					prevNote.scale.y *= PlayState.instance.songSpeed;
				}
				if(prevNote.skinFile.pixel) {
					prevNote.scale.y *= 1.19;
					prevNote.scale.y *= (6 / height); //Auto adjust note size
				}

				prevNote.updateHitbox();

				prevNote.resizeByRatio(1);
			}
			if(prevNote.skinFile.pixel) {
				scale.y *= PlayState.daPixelZoom;
				updateHitbox();
			}
		} else if (!isSustainNote) {
			earlyHitMult = 1;
		}
		x += offsetX;
	}

	var lastNoteOffsetXForPixelAutoAdjusting:Float = 0;
	public var originalHeightForCalcs:Float = 6;
	function reloadNote(?prefix:String = '', ?texture:String = '', ?suffix:String = '') {
		if (prefix == null) prefix = '';
		if (texture == null) texture = '';
		if (suffix == null) suffix = '';
		
		var skin:String = texture;
		if (skin == null || skin.length < 1) {
			skin = PlayState.SONG.arrowSkin;
			if(skin == null || skin.length < 1) {
				skin = 'NOTE_assets';
			}
		}

		var animName:String = null;
		if (animation.curAnim != null) {
			animName = animation.curAnim.name;
		}

		var arraySkin:Array<String> = skin.split('/');
		arraySkin[arraySkin.length - 1] = prefix + arraySkin[arraySkin.length - 1] + suffix;
		
		var lastScaleY:Float = scale.y;
		skinFile = SkinData.getSkinFile(Noteskin, arraySkin.join('/'), skinModifier);
		if (!Paths.fileExists('images/${skinFile.image}.xml', TEXT)) { //assume it is pixel notes
			if (isSustainNote) {
				loadGraphic(Paths.image(skinFile.image + 'ENDS'));
				width = width / 4;
				height = height / 2;
				originalHeightForCalcs = height;
				loadGraphic(Paths.image(skinFile.image + 'ENDS'), true, Math.floor(width), Math.floor(height));
			} else {
				loadGraphic(Paths.image(skinFile.image));
				width = width / 4;
				height = height / 5;
				loadGraphic(Paths.image(skinFile.image), true, Math.floor(width), Math.floor(height));
			}
			if (isSustainNote) {
				setGraphicSize(Std.int(width * pixelNoteSize), Std.int(height * PlayState.daPixelZoom));
			} else {
				setGraphicSize(Std.int(width * pixelNoteSize));
			}
			loadPixelNoteAnims();
			
			if(isSustainNote) {
				offsetX += lastNoteOffsetXForPixelAutoAdjusting;
				lastNoteOffsetXForPixelAutoAdjusting = (width - 7) * (PlayState.daPixelZoom / 2);
				offsetX -= lastNoteOffsetXForPixelAutoAdjusting;
			}
		} else {
			frames = Paths.getSparrowAtlas(skinFile.image);
			loadNoteAnims();
		}
		antialiasing = ClientPrefs.globalAntialiasing && !skinFile.pixel;
		if (isSustainNote) {
			scale.y = lastScaleY;
		}
		updateHitbox();

		if (animName != null) {
			animation.play(animName, true);
		}

		if (inEditor) {
			snapToPixelGrid = false;
			setGraphicSize(ChartingState.GRID_SIZE, ChartingState.GRID_SIZE);
			updateHitbox();
		}
	}

	function loadNoteAnims() {
		for (i in colors) {
			animation.addByPrefix(i, '${i}0');
			if (isSustainNote) {
				animation.addByPrefix('${i}hold', '${i} hold0');
				animation.addByPrefix('${i}holdend', '${i} tail0');
			}
		}

		if (colors.length < 1 || animation.getByName(colors[0]) == null) { //didn't find animations, assume it uses the old note assets
			animation.addByPrefix('up', 'green0');
			animation.addByPrefix('right', 'red0');
			animation.addByPrefix('down', 'blue0');
			animation.addByPrefix('left', 'purple0');

			if (isSustainNote)
			{
				animation.addByPrefix('leftholdend', 'pruple end hold0');
				animation.addByPrefix('upholdend', 'green hold end0');
				animation.addByPrefix('rightholdend', 'red hold end0');
				animation.addByPrefix('downholdend', 'blue hold end0');

				animation.addByPrefix('lefthold', 'purple hold piece0');
				animation.addByPrefix('uphold', 'green hold piece0');
				animation.addByPrefix('righthold', 'red hold piece0');
				animation.addByPrefix('downhold', 'blue hold piece0');
			}
		}

		if (skinFile.pixel) {
			if (isSustainNote) {
				setGraphicSize(Std.int((width * pixelNoteSize)), Std.int(height * PlayState.daPixelZoom));
			} else {
				setGraphicSize(Std.int((width * pixelNoteSize)));
			}
			snapToPixelGrid = true;
			pixelSize = pixelNoteSize;
		} else {
			if (isSustainNote) {
				setGraphicSize(Std.int(width * noteSize), Std.int(height * DEFAULT_NOTE_SIZE));
			} else {
				setGraphicSize(Std.int(width * noteSize));
			}
		}
		updateHitbox();
	}

	function loadPixelNoteAnims() {
		if(isSustainNote) {
			animation.add('${colors[0]}holdend', [PURP_NOTE + 4]);
			animation.add('${colors[1]}holdend', [BLUE_NOTE + 4]);
			animation.add('${colors[2]}holdend', [GREEN_NOTE + 4]);
			animation.add('${colors[3]}holdend', [RED_NOTE + 4]);

			animation.add('${colors[0]}hold', [PURP_NOTE]);
			animation.add('${colors[1]}hold', [BLUE_NOTE]);
			animation.add('${colors[2]}hold', [GREEN_NOTE]);
			animation.add('${colors[3]}hold', [RED_NOTE]);
		} else {
			animation.add(colors[0], [PURP_NOTE + 4]);
			animation.add(colors[1], [BLUE_NOTE + 4]);
			animation.add(colors[2], [GREEN_NOTE + 4]);
			animation.add(colors[3], [RED_NOTE + 4]);
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (mustPress)
		{
			// ok river
			if (strumTime > Conductor.songPosition - (Conductor.safeZoneOffset * lateHitMult)
				&& strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult))
				canBeHit = true;
			else
				canBeHit = false;

			if (strumTime < Conductor.songPosition - (Conductor.safeZoneOffset * lateHitMult) && !wasGoodHit)
				tooLate = true;
		}
		else
		{
			canBeHit = false;

			if (strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult))
			{
				if ((isSustainNote && prevNote.wasGoodHit) || strumTime <= Conductor.songPosition)
					wasGoodHit = true;
			}
		}
	}
}
