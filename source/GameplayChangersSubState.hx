package;

import flixel.FlxCamera;
import flixel.text.FlxText;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;

using StringTools;

class GameplayChangersSubState extends MusicBeatSubState
{
	private var _initialCameras:Null<Array<FlxCamera>>;

	private var curOption:GameplayOption = null;
	private var curSelected:Int = 0;
	private var optionsArray:Array<GameplayOption> = [];

	private var grpOptions:FlxTypedGroup<TitleCardFont>;
	private var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	private var grpTexts:FlxTypedGroup<AttachedTitleCardFont>;

	private var descBox:FlxSprite;
	private var descText:FlxText;

	#if mobile
	var buttonUP:Button;
	var buttonDOWN:Button;
	var buttonLEFT:Button;
	var buttonRESET:Button;
	var buttonRIGHT:Button;
	var buttonENTER:Button;
	var buttonESC:Button;
	#end

	function getOptions()
	{
		var goption:GameplayOption = new GameplayOption('Scroll Type',
			'How should the scroll speed be affected?',
			'scrolltype',
			'string',
			'multiplicative',
			["multiplicative", "constant"]);
		optionsArray.push(goption);

		var option:GameplayOption = new GameplayOption('Scroll Speed',
			'',
			'scrollspeed',
			'float',
			1);
		option.scrollSpeed = 1.5;
		option.minValue = 0.5;
		option.changeValue = 0.1;
		if (goption.getValue() != "constant")
		{
			option.description = "Multiplies the chart's scroll speed.";
			option.displayFormat = '%vX';
			option.maxValue = 3;
		}
		else
		{
			option.description = 'Forces a single scroll speed for every chart.';
			option.displayFormat = "%v";
			option.maxValue = 6;
		}
		optionsArray.push(option);

		#if cpp
		var option:GameplayOption = new GameplayOption('Playback Rate',
			"Changes the song's playback rate, making it go faster.",
			'songspeed',
			'float',
			1);
		option.scrollSpeed = 0.5;
		option.minValue = 1;
		option.maxValue = 2.5;
		option.decimals = 2;
		option.changeValue = 0.01;
		option.displayFormat = '%vX';
		optionsArray.push(option);
		#end

		var option:GameplayOption = new GameplayOption('Health Gain Multiplier',
			"Multiplies the health gained from hitting notes.",
			'healthgain',
			'float',
			1);
		option.scrollSpeed = 2.5;
		option.minValue = 0;
		option.maxValue = 5;
		option.changeValue = 0.1;
		option.displayFormat = '%vX';
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption('Health Loss Multiplier',
			"Multiplies the health lost from missing notes or hitting hurt notes.",
			'healthloss',
			'float',
			1);
		option.scrollSpeed = 2.5;
		option.minValue = 0.5;
		option.maxValue = 5;
		option.changeValue = 0.1;
		option.displayFormat = '%vX';
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption('Play as Opponent',
			"Self-explanatory! Does not save your score.",
			'opponentplay',
			'bool',
			false);
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption('Instakill on Miss',
			"Instantly die if you miss a note or hit a hurt note.",
			'instakill',
			'bool',
			false);
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption('Practice Mode',
			"Prevents you from dying. Does not save your score.",
			'practice',
			'bool',
			false);
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption('Botplay',
			"Let the game play by itself!",
			'botplay',
			'bool',
			false);
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption('Demo Mode',
			"Hides most HUD elements so you can showcase the song. Botplay is activated.",
			'demomode',
			'bool',
			false);
		optionsArray.push(option);
	}

	public function getOptionByName(name:String)
	{
		for(i in optionsArray)
		{
			var opt:GameplayOption = i;
			if (opt.name == name)
				return opt;
		}
		return null;
	}

	public function new(?initialCamera:Null<FlxCamera>) {
		super();
		_initialCameras = initialCamera == null ? null : [initialCamera];
	}

	public override function create() {
		super.create();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.6;

		// avoids lagspikes while scrolling through menus!
		grpOptions = new FlxTypedGroup<TitleCardFont>();

		grpTexts = new FlxTypedGroup<AttachedTitleCardFont>();

		checkboxGroup = new FlxTypedGroup<CheckboxThingie>();

		descBox = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		descBox.alpha = 0.6;

		descText = new FlxText(50, 600, 1180, "", 32);
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 2.4;
		
		getOptions();

		for (element in [bg, grpOptions, grpTexts, checkboxGroup, descBox, descText]) {
			add(element);
			element.cameras = _initialCameras;
		}
		achievementNotificationBox.cameras = _initialCameras;

		for (i in 0...optionsArray.length)
		{
			var optionText:TitleCardFont = new TitleCardFont(0, 70 * i, optionsArray[i].name, true, false, 0.05, 0.8);
			optionText.isMenuItem = true;
			optionText.x += 300;
			optionText.xAdd = 120;
			optionText.targetY = i;
			grpOptions.add(optionText);

			if (optionsArray[i].type == 'bool') {
				var checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105, optionText.y, optionsArray[i].getValue() == true);
				checkbox.sprTracker = optionText;
				checkbox.ID = i;
				checkboxGroup.add(checkbox);
				optionText.xAdd += 80;
			} else {
				var valueText:AttachedTitleCardFont = new AttachedTitleCardFont('${optionsArray[i].getValue()}', optionText.width + 80, true, 0.8);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				grpTexts.add(valueText);
				optionsArray[i].setChild(valueText);
			}
			updateTextFrom(optionsArray[i]);
		}

		changeSelection();
		reloadCheckboxes();

		#if mobile
		buttonUP = new Button(10, 130, 'UP');
		add(buttonUP);
		buttonDOWN = new Button(buttonUP.x, buttonUP.y + buttonUP.height + 10, 'DOWN');
		add(buttonDOWN);
		buttonLEFT = new Button(834, 564, 'LEFT');
		add(buttonLEFT);
		buttonRESET = new Button(984, buttonLEFT.y, 'RESET');
		add(buttonRESET);
		buttonRIGHT = new Button(buttonLEFT.x + 300, buttonLEFT.y, 'RIGHT');
		add(buttonRIGHT);
		buttonENTER = new Button(492, 564, 'ENTER');
		add(buttonENTER);
		buttonESC = new Button(buttonENTER.x + 136, buttonENTER.y, 'ESC');
		add(buttonESC);
		#end

		// Throw it at the end of the group to actually have it in the front
		remove(achievementNotificationBox, true);
		add(achievementNotificationBox);
	}

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;
	override function update(elapsed:Float)
	{
		if (controls.UI_UP_P #if mobile || buttonUP.justPressed #end)
		{
			changeSelection(-1);
			holdTime = 0;
		}
		if (controls.UI_DOWN_P #if mobile || buttonDOWN.justPressed #end)
		{
			changeSelection(1);
			holdTime = 0;
		}

		var down = controls.UI_DOWN #if mobile || buttonDOWN.pressed #end;
		var up = controls.UI_UP #if mobile || buttonUP.pressed #end;
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

		if (controls.BACK #if mobile || buttonESC.justPressed #end) {
			close();
			ClientPrefs.saveSettings();
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
		}

		if (nextAccept <= 0)
		{
			var usesCheckbox = true;
			if (curOption.type != 'bool')
			{
				usesCheckbox = false;
			}

			if (usesCheckbox)
			{
				if (controls.ACCEPT #if mobile || buttonENTER.justPressed #end)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					curOption.setValue((curOption.getValue() == true) ? false : true);
					curOption.change();
					reloadCheckboxes();
				}
			} else if (!down && !up) {
				if (controls.UI_LEFT || controls.UI_RIGHT #if mobile || buttonLEFT.pressed || buttonRIGHT.pressed #end) {
					var pressed = (controls.UI_LEFT_P || controls.UI_RIGHT_P #if mobile || buttonLEFT.pressed || buttonRIGHT.pressed #end );
					if (holdTime > 0.5 || pressed) {
						if (pressed) {
							var add:Dynamic = null;
							if (curOption.type != 'string') {
								add = (controls.UI_LEFT #if mobile || buttonLEFT.pressed #end) ? -curOption.changeValue : curOption.changeValue;
							}

							switch(curOption.type)
							{
								case 'int' | 'float' | 'percent':
									holdValue = curOption.getValue() + add;
									if (holdValue < curOption.minValue) holdValue = curOption.minValue;
									else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

									switch(curOption.type)
									{
										case 'int':
											holdValue = Math.round(holdValue);
											curOption.setValue(holdValue);

										case 'float' | 'percent':
											holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
											curOption.setValue(holdValue);
									}

								case 'string':
									var num:Int = curOption.curOption; //lol
									if (controls.UI_LEFT_P #if mobile || buttonLEFT.justPressed #end) --num;
									else num++;

									if (num < 0) {
										num = curOption.options.length - 1;
									} else if (num >= curOption.options.length) {
										num = 0;
									}

									curOption.curOption = num;
									curOption.setValue(curOption.options[num]); //lol
									
									if (curOption.name == "Scroll Type")
									{
										var oOption:GameplayOption = getOptionByName("Scroll Speed");
										if (oOption != null)
										{
											if (curOption.getValue() == "constant")
											{
												oOption.description = 'Forces a single scroll speed for every chart.';
												oOption.displayFormat = "%v";
												oOption.maxValue = 6;
											}
											else
											{
												oOption.description = "Multiplies the chart's scroll speed.";
												oOption.displayFormat = "%vX";
												oOption.maxValue = 3;
												if (oOption.getValue() > 3) oOption.setValue(3);
											}
											updateTextFrom(oOption);
										}
									}
							}
							updateTextFrom(curOption);
							curOption.change();
							FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
						} else if (curOption.type != 'string') {
							holdValue += curOption.scrollSpeed * elapsed * ((controls.UI_LEFT #if mobile || buttonLEFT.pressed #end) ? -1 : 1);
							if (holdValue < curOption.minValue) holdValue = curOption.minValue;
							else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

							switch(curOption.type)
							{
								case 'int':
									curOption.setValue(Math.round(holdValue));
								
								case 'float' | 'percent':
									curOption.setValue(FlxMath.roundDecimal(holdValue, curOption.decimals));
							}
							updateTextFrom(curOption);
							curOption.change();
						}
					}

					if (curOption.type != 'string') {
						holdTime += elapsed;
					}
				} else if (controls.UI_LEFT_R || controls.UI_RIGHT_R #if mobile || buttonLEFT.justReleased || buttonRIGHT.justReleased #end) {
					clearHold();
				}
			}

			if (controls.RESET #if mobile || buttonRESET.justPressed #end)
			{
				for (i in 0...optionsArray.length)
				{
					var leOption:GameplayOption = optionsArray[i];
					leOption.setValue(leOption.defaultValue);
					if (leOption.type != 'bool')
					{
						if (leOption.type == 'string')
						{
							leOption.curOption = leOption.options.indexOf(leOption.getValue());
						}
						updateTextFrom(leOption);
					}

					if (leOption.name == 'Scroll Speed')
					{
						leOption.displayFormat = "%vX";
						leOption.maxValue = 3;
						if (leOption.getValue() > 3)
						{
							leOption.setValue(3);
						}
						updateTextFrom(leOption);
					}
					leOption.change();
				}
				FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
				reloadCheckboxes();
			}
		}

		if (nextAccept > 0) {
			nextAccept -= 1;
		}
		super.update(elapsed);
	}

	function updateTextFrom(option:GameplayOption) {
		var text:String = option.displayFormat;
		var val:Dynamic = option.getValue();
		if (option.type == 'percent') val *= 100;
		var def:Dynamic = option.defaultValue;
		option.text = text.replace('%v', val).replace('%d', def);
	}

	function clearHold()
	{
		if (holdTime > 0.5) {
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}
		holdTime = 0;
	}
	
	function changeSelection(change:Int = 0)
	{
		curSelected += change;
		if (curSelected < 0)
			curSelected = optionsArray.length - 1;
		if (curSelected >= optionsArray.length)
			curSelected = 0;

		descText.text = optionsArray[curSelected].description;
		descText.screenCenter(Y);
		descText.y += 270;

		var bullShit:Int = 0;

		for (item in grpOptions.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;
			if (item.targetY == 0) {
				item.alpha = 1;
			}
		}
		for (text in grpTexts) {
			text.alpha = 0.6;
			if (text.ID == curSelected) {
				text.alpha = 1;
			}
		}

		descBox.setPosition(descText.x - 10, descText.y - 10);
		descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
		descBox.updateHitbox();

		curOption = optionsArray[curSelected]; //shorter lol
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function reloadCheckboxes() {
		for (checkbox in checkboxGroup) {
			checkbox.daValue = (optionsArray[checkbox.ID].getValue() == true);
		}
	}
}

class GameplayOption
{
	private var child:AttachedTitleCardFont;
	public var text(get, set):String;
	public var onChange:Void->Void = null; //Pressed enter (on Bool type options) or pressed/held left/right (on other types)

	public var type(get, default):String = 'bool'; //bool, int (or integer), float (or fl), percent, string (or str)
	// Bool will use checkboxes
	// Everything else will use a text

	public var showBoyfriend:Bool = false;
	public var scrollSpeed:Float = 50; //Only works on int/float, defines how fast it scrolls per second while holding left/right

	private var variable:String = null; //Variable from ClientPrefs.hx's gameplaySettings
	public var defaultValue:Dynamic = null;

	public var curOption:Int = 0; //Don't change this
	public var options:Array<String> = null; //Only used in string type
	public var changeValue:Dynamic = 1; //Only used in int/float/percent type, how much is changed when you PRESS
	public var minValue:Dynamic = null; //Only used in int/float/percent type
	public var maxValue:Dynamic = null; //Only used in int/float/percent type
	public var decimals:Int = 1; //Only used in float/percent type

	public var displayFormat:String = '%v'; //How String/Float/Percent/Int values are shown, %v = Current value, %d = Default value
	public var description:String = '';
	public var name:String = 'Unknown';

	public function new(name:String, description:String = '', variable:String, type:String = 'bool', defaultValue:Dynamic = 'null variable value', ?options:Array<String> = null)
	{
		this.name = name;
		this.description = description;
		this.variable = variable;
		this.type = type;
		this.defaultValue = defaultValue;
		this.options = options;

		if (defaultValue == 'null variable value')
		{
			switch(type)
			{
				case 'bool':
					defaultValue = false;
				case 'int' | 'float':
					defaultValue = 0;
				case 'percent':
					defaultValue = 1;
				case 'string':
					defaultValue = '';
					if (options.length > 0) {
						defaultValue = options[0];
					}
			}
		}

		if (getValue() == null) {
			setValue(defaultValue);
		}

		switch(type)
		{
			case 'string':
				var num:Int = options.indexOf(getValue());
				if (num > -1) {
					curOption = num;
				}
	
			case 'percent':
				displayFormat = '%v%';
				changeValue = 0.01;
				minValue = 0;
				maxValue = 1;
				scrollSpeed = 0.5;
				decimals = 2;
		}
	}

	public function change()
	{
		//nothing lol
		if (onChange != null) {
			onChange();
		}
	}

	public function getValue():Dynamic
	{
		return ClientPrefs.gameplaySettings.get(variable);
	}
	public function setValue(value:Dynamic)
	{
		ClientPrefs.gameplaySettings.set(variable, value);
	}

	public function setChild(child:AttachedTitleCardFont)
	{
		this.child = child;
	}

	private function get_text()
	{
		if (child != null) {
			return child.text;
		}
		return null;
	}
	private function set_text(newValue:String = '')
	{
		if (child != null) {
			child.text = newValue;
			child.updateHitbox();
		}
		return null;
	}

	private function get_type()
	{
		var newValue:String = 'bool';
		switch(type.toLowerCase().trim())
		{
			case 'int' | 'float' | 'percent' | 'string': newValue = type;
			case 'integer': newValue = 'int';
			case 'str': newValue = 'string';
			case 'fl': newValue = 'float';
		}
		type = newValue;
		return type;
	}
}
