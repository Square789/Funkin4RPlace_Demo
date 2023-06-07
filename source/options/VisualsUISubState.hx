package options;

import flixel.FlxG;
import flixel.group.FlxGroup.FlxTypedGroup;

using StringTools;

class VisualsUISubState extends BaseOptionsMenu
{
	var strumGroup:FlxTypedGroup<StrumNote> = new FlxTypedGroup();

	public function new()
	{
		title = 'Visuals and UI';
		rpcTitle = 'Visuals & UI Settings Menu'; //for Discord Rich Presence

		var noteskinList = Paths.getTextFromFile('images/noteskins/noteskinList.txt').trim().split('\n');
		for (i => skin in noteskinList) noteskinList[i] = skin.trim();

		var option:Option = new Option('Noteskin:',
			"What noteskin to use?",
			'noteSkin',
			'string',
			'Default',
			noteskinList);
		option.props["showNotes"] = true;
		option.onChange = reloadNotes;
		addOption(option);

		var option:Option = new Option('Note Splashes',
			"If unchecked, hitting \"Sick!!\" notes won't show particles.",
			'noteSplashes',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Hide HUD',
			'If checked, hides most HUD elements.',
			'hideHud',
			'bool',
			false);
		addOption(option);
		
		var option:Option = new Option('Time Bar:',
			"What should the time bar display?",
			'timeBarType',
			'string',
			'Time Left',
			['Time Left', 'Time Elapsed', 'Song Name', 'Disabled']);
		addOption(option);

		var option:Option = new Option('Karma Seperator:',
			"How should the Karma (Score) be seperated?",
			'scoreSeperator',
			'string',
			'Comma',
			['Comma', 'Period', 'None']);
		addOption(option);

		var option:Option = new Option('Flashing Lights',
			"Uncheck this if you're sensitive to flashing lights!",
			'flashing',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Camera Zooms',
			"If unchecked, the camera won't zoom in on a beat hit.",
			'camZooms',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Show Number of Ratings',
			"Display the number of \"Sick!\"s, \"Good\"s, \"Bad\"s, and \"Shit\"s you've gotten.",
			'showRatings',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Score Text Zoom on Hit',
			"If unchecked, disables the score and rating texts zooming everytime you hit a note.",
			'scoreZoom',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Note Underlay Transparency',
			'How visible the background behind the notes should be.',
			'underlayAlpha',
			'percent',
			0);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('Full Underlay',
			"If checked, the note underlay will fill up the whole screen instead of just the notes. Works better for modcharts.",
			'underlayFull',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Keybind Reminders',
			'If checked, shows your note keybinds when starting a song.',
			'keybindReminders',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Health Bar Transparency',
			'How visible the health bar and icons should be.',
			'healthBarAlpha',
			'percent',
			1);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('Smooth Health Bar',
			'If checked, the health bar will move smoother.',
			'smoothHealth',
			'bool',
			false);
		addOption(option);
		
		var option:Option = new Option('FPS & Memory Counter',
			'If unchecked, hides the FPS & memory counter.',
			'showFPS',
			'bool',
			false);
		addOption(option);
		option.onChange = onChangeFPSCounter;

		var option:Option = new Option('Menu Screen Song:',
			"What song would you prefer for the menus?",
			'menuMusic',
			'string',
			'Random',
			['Random', 'GoddessAwe', 'Micah', 'Freaky'/*, 'None'*/]);
		addOption(option);
		option.onChange = onChangeMenuMusic;

		var option:Option = new Option('Pause Screen Song:',
			"What song do you prefer for the Pause Screen?",
			'pauseMusic',
			'string',
			'Cooldown',
			['None', 'Cooldown', 'Breakfast', 'Tea Time']);
		addOption(option);
		option.onChange = onChangePauseMusic;

		#if CHECK_FOR_UPDATES
		var option:Option = new Option('Check for Updates',
			'On Release builds, turn this on to check for updates when you start the game.',
			'checkForUpdates',
			'bool',
			true);
		addOption(option);
		#end

		super();
	}

	override function create() {
		for (i in 0...4) {
			var babyArrow:StrumNote = new StrumNote(PlayState.STRUM_X_MIDDLESCROLL, 200, i, 1, 4);
			strumGroup.add(babyArrow);
			babyArrow.postAddedToGroup();
		}
		add(strumGroup);

		strumGroup.visible = optionsArray[curSelected].props["showNotes"] == true;

		super.create();
	}

	function reloadNotes() {
		for (babyArrow in strumGroup) {
			babyArrow.reloadNote();
			babyArrow.x = PlayState.STRUM_X_MIDDLESCROLL;
			babyArrow.postAddedToGroup();
		}
	} 

	override function changeSelection(change:Int = 0) {
		super.changeSelection(change);

		strumGroup.visible = optionsArray[curSelected].props["showNotes"] == true;
	}

	function onChangeMenuMusic()
	{
		CoolUtil.playMenuMusic(changedMusic);
		changedMusic = false;
	}

	var changedMusic:Bool = false;
	function onChangePauseMusic()
	{
		if(ClientPrefs.pauseMusic == 'None')
			FlxG.sound.music.volume = 0;
		else
			FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.pauseMusic)));

		changedMusic = true;
	}

	override function destroy()
	{
		if(changedMusic) CoolUtil.playMenuMusic();
		super.destroy();
	}

	function onChangeFPSCounter()
	{
		if (Main.fpsVar != null)
			Main.fpsVar.visible = ClientPrefs.showFPS;
	}
}