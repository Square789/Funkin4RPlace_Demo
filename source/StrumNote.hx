package;

import SkinData.SkinFileData;
import flixel.FlxG;
import flixel.FlxSprite;

using StringTools;

class StrumNote extends FarpSprite
{
	private var colorSwap:ColorSwap;
	public var skinFile:SkinFileData;
	public var skinModifier:String;
	public var resetAnim:Float = 0;
	private var noteData:Int = 0;
	public var direction:Float = 90;
	public var downScroll:Bool = false;
	public var sustainReduce:Bool = true;

	private var player:Int;
	public var postAdded:Bool = false;

	var keyAmount:Int = 4;
	var directions:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
	var colors:Array<String> = ['left', 'down', 'up', 'right'];
	public var swagWidth:Float = 160 * 0.7;
	public var xOff:Float = 54;
	public var noteSize:Float = 0.7;
	
	public var texture(default, set):String = null;
	private function set_texture(value:String):String {
		if (texture != value) {
			texture = value;
			reloadNote();
		}
		return value;
	}

	public function new(x:Float, y:Float, leData:Int, player:Int, ?keyAmount:Int = 4, ?skinModifier:String) {
		colorSwap = new ColorSwap();
		shader = colorSwap.shader;
		noteData = leData;
		this.player = player;
		this.noteData = leData % keyAmount;
		this.keyAmount = keyAmount;
		this.skinModifier = skinModifier;
		super(x, y);

		swagWidth = Std.parseFloat(CoolUtil.coolTextFile(Paths.txt('note_spacings'))[keyAmount-1]);
		directions = CoolUtil.coolArrayTextFile(Paths.txt('note_directions'))[keyAmount-1];
		colors = CoolUtil.coolArrayTextFile(Paths.txt('note_colors'))[keyAmount-1];
		xOff = Std.parseFloat(CoolUtil.coolTextFile(Paths.txt('note_offsets'))[keyAmount-1]);
		noteSize = Std.parseFloat(CoolUtil.coolTextFile(Paths.txt('note_sizes'))[keyAmount-1]);

		var skin:String = 'NOTE_assets';
		if(PlayState.SONG != null && PlayState.SONG.arrowSkin != null && PlayState.SONG.arrowSkin.length > 0) skin = PlayState.SONG.arrowSkin;
		texture = skin; //Load texture and anims

		scrollFactor.set();
	}

	public function reloadNote()
	{
		var lastAnim:String = null;
		if (animation.curAnim != null) lastAnim = animation.curAnim.name;

		skinFile = SkinData.getSkinFile(Noteskin, texture, skinModifier);
		if (!Paths.fileExists('images/${skinFile.image}.xml', TEXT)) { //assume it is pixel notes
			loadGraphic(Paths.image(skinFile.image));
			width = width / 4;
			height = height / 5;
			loadGraphic(Paths.image(skinFile.image), true, Math.floor(width), Math.floor(height));

			setGraphicSize(Std.int((width * (noteSize / Note.DEFAULT_NOTE_SIZE)) * PlayState.daPixelZoom));

			switch (noteData)
			{
				case 0:
					animation.add('static', [0]);
					animation.add('pressed', [4, 8], 12, false);
					animation.add('confirm', [12, 16], 24, false);
				case 1:
					animation.add('static', [1]);
					animation.add('pressed', [5, 9], 12, false);
					animation.add('confirm', [13, 17], 24, false);
				case 2:
					animation.add('static', [2]);
					animation.add('pressed', [6, 10], 12, false);
					animation.add('confirm', [14, 18], 12, false);
				case 3:
					animation.add('static', [3]);
					animation.add('pressed', [7, 11], 12, false);
					animation.add('confirm', [15, 19], 24, false);
			}
		} else {
			frames = Paths.getSparrowAtlas(skinFile.image);
			animation.addByPrefix('static', 'arrow${directions[noteData].toUpperCase()}0');
			animation.addByPrefix('pressed', '${colors[noteData]} press', 24, false);
			animation.addByPrefix('confirm', '${colors[noteData]} confirm', 24, false);
			if (skinFile.pixel) {
				var nWidth = Std.int((width * (noteSize / Note.DEFAULT_NOTE_SIZE)) * PlayState.daPixelZoom);
				setGraphicSize(nWidth);
				snapToPixelGrid = true;
				offsetFix = false;
				pixelSize = scale.x;
				var padding = pixelSize;
				if (skinFile.skin == 'white-outline')
					padding = pixelSize * 3; 
				swagWidth = nWidth + padding;
			} else {
				setGraphicSize(Std.int(width * noteSize));
			}
		}
		updateHitbox();
		antialiasing = ClientPrefs.globalAntialiasing && !skinFile.pixel;

		if (lastAnim != null)
		{
			playAnim(lastAnim, true);
		}
	}

	public function postAddedToGroup() {
		playAnim('static');
		x += swagWidth * noteData;
		x += xOff;
		x += ((FlxG.width / 2) * player);
		if (snapToPixelGrid)
			x = Math.floor(x / pixelSize) * pixelSize;
		ID = noteData;
		postAdded = true;
	}

	override function update(elapsed:Float) {
		if (resetAnim > 0) {
			resetAnim -= elapsed;
			if (resetAnim <= 0) {
				playAnim('static');
				resetAnim = 0;
			}
		}
		if (animation.curAnim != null && animation.curAnim.name == 'confirm' && skinFile.pixel) {
			centerOrigin();
		}

		super.update(elapsed);
	}

	public function playAnim(anim:String, ?force:Bool = false) {
		animation.play(anim, force);
		centerOffsets();
		centerOrigin();
		if (animation.curAnim == null || animation.curAnim.name == 'static') {
			colorSwap.hue = 0;
			colorSwap.saturation = 0;
			colorSwap.brightness = 0;
		} else {
			colorSwap.hue = ClientPrefs.arrowHSV[keyAmount - 1][noteData][0] / 360;
			colorSwap.saturation = ClientPrefs.arrowHSV[keyAmount - 1][noteData][1] / 100;
			colorSwap.brightness = ClientPrefs.arrowHSV[keyAmount - 1][noteData][2] / 100;

			if(animation.curAnim.name == 'confirm' && !skinFile.pixel) {
				centerOrigin();
			}
		}
	}
}
