import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.FlxCamera;

using StringTools;

class ResetScoreSubState extends MusicBeatSubState
{
	var bg:FlxSprite;
	var alphabetArray:Array<TitleCardFont> = [];
	var icon:HealthIcon;
	var onYes:Bool = false;
	var yesText:TitleCardFont;
	var noText:TitleCardFont;

	var song:String;
	var difficulty:Int;
	var week:String;
	var displayName:String;

	#if mobile
	var buttonLEFT:Button;
	var buttonRIGHT:Button;
	var buttonENTER:Button;
	var buttonESC:Button;
	#end

	// Week '' = Freeplay
	public function new(song:String, difficulty:Int, character:String, week:String = '', ?displayName:String, ?camera:Null<FlxCamera>)
	{
		this.song = song;
		this.difficulty = difficulty;
		this.week = week;
		this.displayName = displayName;

		super();

		var name:String = displayName;
		if (week.length > 0) {
			name = WeekData.weeksLoaded.get(week).weekName;
		}
		name += ' (${CoolUtil.difficulties[difficulty]})?';

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var tooLong:Float = (name.length > 18) ? 0.8 : 1; //Fucking Winter Horrorland
		var text:TitleCardFont = new TitleCardFont(0, 180, "Reset the score of", true);
		text.screenCenter(X);
		alphabetArray.push(text);
		text.alpha = 0;
		add(text);
		var text:TitleCardFont = new TitleCardFont(0, text.y + 90, name, true, false, 0.05, tooLong);
		text.screenCenter(X);
		if (week.length < 1) text.x += 60 * tooLong;
		alphabetArray.push(text);
		text.alpha = 0;
		add(text);
		if (week.length < 1) {
			icon = new HealthIcon(character);
			icon.setGraphicSize(Std.int(icon.width * tooLong));
			icon.updateHitbox();
			icon.setPosition(text.x - icon.width + (10 * tooLong), text.y - 30);
			icon.alpha = 0;
			add(icon);
		}

		yesText = new TitleCardFont(0, text.y + 150, 'Yes', true);
		yesText.screenCenter(X);
		yesText.x -= 200;
		add(yesText);
		noText = new TitleCardFont(0, text.y + 150, 'No', true);
		noText.screenCenter(X);
		noText.x += 200;
		add(noText);
		updateOptions();

		var cams = camera == null ? null : [camera];
		for (element in [bg, icon, yesText, noText].concat(cast alphabetArray)) {
			if (element != null) {
				element.cameras = cams;
			}
		}

		#if mobile
		buttonENTER = new Button(573, 564, 'ENTER');
		add(buttonENTER);
		buttonLEFT = new Button(buttonENTER.x - buttonENTER.width - 10, buttonENTER.y, 'LEFT');
		add(buttonLEFT);
		buttonRIGHT = new Button(buttonENTER.x + buttonENTER.width + 10, buttonENTER.y, 'RIGHT');
		add(buttonRIGHT);
		buttonESC = new Button(10, buttonENTER.y, 'ESC');
		add(buttonESC);
		#end
	}

	override function update(elapsed:Float)
	{
		bg.alpha += elapsed * 1.5;
		if (bg.alpha > 0.6) bg.alpha = 0.6;

		for (i in 0...alphabetArray.length) {
			var spr = alphabetArray[i];
			spr.alpha += elapsed * 2.5;
		}
		if (week.length < 1) icon.alpha += elapsed * 2.5;

		if (controls.UI_LEFT_P || controls.UI_RIGHT_P #if mobile || buttonLEFT.justPressed || buttonRIGHT.justPressed #end) {
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			onYes = !onYes;
			updateOptions();
		}
		if (controls.BACK #if mobile || buttonESC.justPressed #end) {
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
			close();
		} else if (controls.ACCEPT #if mobile || buttonENTER.justPressed #end) {
			if (onYes) {
				if (week.length < 1) {
					Highscore.resetSong(song, difficulty);
				} else {
					Highscore.resetWeek(week, difficulty);
				}
			}
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
			close();
		}
		super.update(elapsed);
	}

	function updateOptions() {
		var scales:Array<Float> = [0.75 * 4, 1 * 4];
		var alphas:Array<Float> = [0.6, 1.25];
		var confirmInt:Int = onYes ? 1 : 0;

		yesText.alpha = alphas[confirmInt];
		yesText.scale.set(scales[confirmInt], scales[confirmInt]);
		noText.alpha = alphas[1 - confirmInt];
		noText.scale.set(scales[1 - confirmInt], scales[1 - confirmInt]);
		if (week.length < 1) icon.animation.play(onYes ? 'losing' : 'winning');
	}
}