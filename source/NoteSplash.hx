package;

import SkinData.SkinFileData;
import flixel.FlxG;
import flixel.FlxSprite;

using StringTools;

class NoteSplash extends FarpSprite
{
	public var colorSwap:ColorSwap = null;
	public var skinFile:SkinFileData = null;
	private var textureLoaded:String = null;

	var daNote:Note = null;
	var daStrum:StrumNote = null;
	var colors:Array<String>;
	public var alphaMult:Float = 0.6;

	public function new(x:Float = 0, y:Float = 0, ?note:Note = null) {
		super(x, y);

		var skin:String = 'noteSplashes';
		if(PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) skin = PlayState.SONG.splashSkin;

		loadAnims(skin);
		
		colorSwap = new ColorSwap();
		shader = colorSwap.shader;

		antialiasing = ClientPrefs.globalAntialiasing;
	}

	public function setupNoteSplash(x:Float = 0, y:Float = 0, note:Note = null, texture:String = null, hueColor:Float = 0, satColor:Float = 0, brtColor:Float = 0, keyAmount:Int = 4, strum:StrumNote = null) {
		if (note != null) {
			daNote = note;
		}
		if (strum != null) {
			daStrum = strum;
		}
		colors = CoolUtil.coolArrayTextFile(Paths.txt('note_colors'))[keyAmount-1];
		updateHitbox();

		if (texture == null || texture.length < 1 || texture == 'noteSplashes') {
			texture = 'noteSplashes';
			if(PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) texture = PlayState.SONG.splashSkin;
		}

		if(textureLoaded != texture) {
			loadAnims(texture);
		}
		colorSwap.hue = hueColor;
		colorSwap.saturation = satColor;
		colorSwap.brightness = brtColor;

		var animNum:Int = FlxG.random.int(1, 2);
		if (note != null) {
			animation.play('note${note.noteData}-$animNum', true);
		} else {
			animation.play('note0-1', true);
		}
		if (animation.curAnim != null) animation.curAnim.frameRate = 24 + FlxG.random.int(-2, 2);
		updateHitbox();
        centerOrigin();
		if (note != null) {
			positionSplash();
			alpha = note.alpha;
			angle = note.angle;
		}
	}

	function positionSplash() {
		var note:Dynamic = daStrum != null ? daStrum : daNote;
		if (note != null) {
			var ox = (note.width - width) / 2;
			var oy = (note.height - height) / 2;

			if (skinFile.pixel) {
				ox = Math.floor(ox / PlayState.daPixelZoom) * PlayState.daPixelZoom;
				oy = Math.floor(oy / PlayState.daPixelZoom) * PlayState.daPixelZoom;
			}

			if (note != null) setPosition(note.x + ox, note.y + oy);
		}
	}

	function scaleSplash() {
		var note:Dynamic = daStrum != null ? daStrum : daNote;
		if (note != null) {
			var size:Float;
			var ratio = note.noteSize / Note.DEFAULT_NOTE_SIZE;
			if (skinFile.pixel) {
				size = Math.floor(ratio) * PlayState.daPixelZoom;
				snapToPixelGrid = true;
				pixelSize = scale.x;
			} else { 
				size = ratio;
			}
			scale.set(size, size);
		}
	}

	function loadAnims(skin:String) {
		if (daNote == null) {
			skinFile = SkinData.getSkinFile(Noteskin, skin);
			frames = Paths.getSparrowAtlas(skinFile.image);
			animation.addByPrefix("note0-1", "note splash left 1", 24, false);
		} else {
			skinFile = SkinData.getSkinFile(Noteskin, skin, daNote.skinFile.folder);
			frames = Paths.getSparrowAtlas(skinFile.image);
			for (i in 1...3) {
				animation.addByPrefix('note${daNote.noteData}-$i', 'note splash ${colors[daNote.noteData]} ${i}0', 24, false);
			}
			if (animation.getByName('note${daNote.noteData}-1') == null) {
				for (i in 1...3) {
					animation.addByPrefix('note0-$i', 'note splash purple ${i}0', 24, false);
					animation.addByPrefix('note1-$i', 'note splash blue ${i}0', 24, false);
					animation.addByPrefix('note2-$i', 'note splash green ${i}0', 24, false);
					animation.addByPrefix('note3-$i', 'note splash red ${i}0', 24, false);
				}
			}
			antialiasing = ClientPrefs.globalAntialiasing && !skinFile.pixel;

			scaleSplash();
		}

		if (skinFile.folder.endsWith('place'))
			alphaMult = 1;
		else
			alphaMult = 0.6;
	}

	override function update(elapsed:Float) {
		if (animation.curAnim != null) if (animation.curAnim.finished) kill();

		if (daNote != null) {
			positionSplash();
			alpha = daNote.alpha * alphaMult;
			angle = daNote.angle;
		} else {
			alpha = alphaMult;
		}

		super.update(elapsed);
	}
}