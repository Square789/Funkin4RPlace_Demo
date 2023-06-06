package editors;

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

using StringTools;

class MasterEditorMenu extends MusicBeatState
{
	var options:Array<String> = [
		#if CHART_EDITOR_ALLOWED
		'Character Editor',
		'Chart Editor',
		#else
		'Character Editor',
		#end
		'Dialogue Editor',
		'Dialogue Portrait Editor',
		'Menu Character Editor',
		'Week Editor'
	];
	private var grpTexts:FlxTypedGroup<TitleCardFont>;
	private var directories:Array<String> = [null];

	private var curSelected = 0;
	private var curDirectory = 0;
	private var directoryTxt:FlxText;

	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Editors Main Menu", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF353535;
		add(bg);

		grpTexts = new FlxTypedGroup<TitleCardFont>();
		add(grpTexts);

		for (i in 0...options.length)
		{
			var leText:TitleCardFont = new TitleCardFont(0, (70 * i) + 30, options[i], true, false);
			leText.isMenuItem = true;
			leText.targetY = i;
			grpTexts.add(leText);
		}
		
		#if MODS_ALLOWED
		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 42).makeGraphic(FlxG.width, 42, 0xFF000000);
		textBG.alpha = 0.6;
		add(textBG);

		directoryTxt = new FlxText(textBG.x, textBG.y + 4, FlxG.width, '', 32);
		directoryTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		directoryTxt.scrollFactor.set();
		add(directoryTxt);
		
		for (folder in Paths.getModDirectories())
		{
			directories.push(folder);
		}

		var found:Int = directories.indexOf(Paths.currentModDirectory);
		if (found > -1) curDirectory = found;
		changeDirectory();
		#end
		changeSelection();

		FlxG.mouse.visible = false;
		super.create();
	}

	var holdTime:Float = 0;
	override function update(elapsed:Float)
	{
		if (controls.UI_UP_P)
		{
			changeSelection(-1);
			holdTime = 0;
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
			holdTime = 0;
		}
		var down = controls.UI_DOWN;
		var up = controls.UI_UP;
		if (down || up)
		{
			var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
			holdTime += elapsed;
			var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

			if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
			{
				changeSelection((checkNewHold - checkLastHold) * (up ? -1 : 1));
			}
		}
		#if MODS_ALLOWED
		if (controls.UI_LEFT_P)
		{
			changeDirectory(-1);
		}
		if (controls.UI_RIGHT_P)
		{
			changeDirectory(1);
		}
		#end

		if (controls.BACK)
		{
			MusicBeatState.switchState(new MainMenuF4rpState(true));
		}

		if (controls.ACCEPT)
		{
			switch(options[curSelected]) {
				case 'Character Editor':
					PlayState.SONG = null;
					LoadingState.loadAndSwitchState(new CharacterEditorState(Character.DEFAULT_CHARACTER, false));
				case 'Week Editor':
					MusicBeatState.switchState(new WeekEditorState());
				case 'Menu Character Editor':
					MusicBeatState.switchState(new MenuCharacterEditorState());
				case 'Dialogue Portrait Editor':
					PlayState.SONG = null;
					LoadingState.loadAndSwitchState(new DialogueCharacterEditorState());
				case 'Dialogue Editor':
					PlayState.SONG = null;
					LoadingState.loadAndSwitchState(new DialogueEditorState());
				#if CHART_EDITOR_ALLOWED
				case 'Chart Editor'://felt it would be cool maybe
					PlayState.SONG = null;
					PlayState.chartingMode = true;
					LoadingState.loadAndSwitchState(new ChartingState(true));
				#end
			}
			FlxG.sound.music.volume = 0;
		}
		
		var bullShit:Int = 0;
		for (item in grpTexts.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;

			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
		super.update(elapsed);
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = options.length - 1;
		if (curSelected >= options.length)
			curSelected = 0;
	}

	#if MODS_ALLOWED
	function changeDirectory(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curDirectory += change;

		if (curDirectory < 0)
			curDirectory = directories.length - 1;
		if (curDirectory >= directories.length)
			curDirectory = 0;
	
		WeekData.setDirectoryFromWeek();
		if (directories[curDirectory] == null || directories[curDirectory].length < 1)
			directoryTxt.text = '< No Mod Directory Loaded >';
		else
		{
			Paths.currentModDirectory = directories[curDirectory];
			directoryTxt.text = '< Loaded Mod Directory: ${Paths.currentModDirectory} >';
		}
		directoryTxt.text = directoryTxt.text.toUpperCase();
	}
	#end
}