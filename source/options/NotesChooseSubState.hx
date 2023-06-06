package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;

class NotesChooseSubState extends MusicBeatSubState {
    private static var curSelected:Int = 0;
    var optionShit:Array<String> = [];

	var grpOptions:FlxTypedGroup<TitleCardFont>;

    override function create()
	{
        #if MULTI_KEY_ALLOWED
        for (i in 0...Note.MAX_KEYS) {
        #else
        for (i in 0...4) {
        #end
			optionShit.push('${i + 1}K');
		}

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFea71fd;
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);

		grpOptions = new FlxTypedGroup<TitleCardFont>();
		add(grpOptions);

		for (i in 0...optionShit.length) {
			var optionText:TitleCardFont = new TitleCardFont(0, (10 * i), optionShit[i], true, false);
			optionText.isMenuItem = true;
            optionText.screenCenter(X);
            optionText.forceX = optionText.x;
            optionText.yAdd = -55;
			optionText.yMult = 60;
			optionText.targetY = i;
			grpOptions.add(optionText);
		}
		changeSelection();
        super.create();
	}

    override function update(elapsed:Float) {
        var shiftMult:Int = 1;
        if (FlxG.keys.pressed.SHIFT) shiftMult = 3;
        if (controls.UI_UP_P) {
            changeSelection(-shiftMult);
        }
        if (controls.UI_DOWN_P) {
            changeSelection(shiftMult);
        }

        if (controls.BACK) {
            close();
            FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
        }

        if (controls.ACCEPT) {
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
            openSubState(new options.NotesSubState(curSelected + 1));
        }
		super.update(elapsed);
	}

    function changeSelection(change:Int = 0) {
        curSelected += change;
        if (curSelected < 0)
            curSelected = optionShit.length - 1;
        if (curSelected >= optionShit.length)
            curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpOptions.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

            item.alpha = 0.6;
            if (item.targetY == 0) {
                item.alpha = 1;
            }
		}
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}
}