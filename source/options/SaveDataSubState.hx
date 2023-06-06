package options;

import flixel.FlxG;

using StringTools;

class SaveDataSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Save Data';
		rpcTitle = 'Save Data Menu'; //for Discord Rich Presence

        var option:Option = new Option('Reset Highscores',
			'Clears all song and week highscores.',
			'',
			'button');
        option.onChange = function() {
			FlxG.mouse.visible = true;
            openSubState(new Prompt('Are you sure you want to reset all of your highscores?\n\nThis action is irreversible.', function() {
				clearScores();
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
				hideMouse();
			}, hideMouse));
        }
		addOption(option);

		var option:Option = new Option('Reset Completed Weeks',
			'Clears all week completions.',
			'',
			'button');
		option.onChange = function() {
			FlxG.mouse.visible = true;
			openSubState(new Prompt('Are you sure you want to reset all of your completed weeks?\nThis action is irreversible.', function() {
				clearWeeks();
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
				hideMouse();
			}, hideMouse));
		}
		addOption(option);

		var option:Option = new Option('Reset Achievement Data',
			'Clears all achievement progress.',
			'',
			'button');
		option.onChange = function() {
			FlxG.mouse.visible = true;
			openSubState(new Prompt('Are you sure you want to reset all of your achievement progress?\nThis action is irreversible.', function() {
				clearAchievements();
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
				hideMouse();
			}, hideMouse));
		}
		addOption(option);

		var option:Option = new Option('Reset All Data',
			'Clears all of the above.',
			'',
			'button');
		option.onChange = function() {
			FlxG.mouse.visible = true;
			openSubState(new Prompt('Are you sure you want to reset ALL of your saved data?\n\nThis action is irreversible.', function() {
				clearScores();
				clearWeeks();
				clearAchievements();
				clearFreeplay();
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
				hideMouse();
			}, hideMouse));
		}
		addOption(option);
		
		super();
	}

    function clearScores() {
        Highscore.songScores.clear();
        Highscore.songRating.clear();
        Highscore.weekScores.clear();
        FlxG.save.data.songScores = Highscore.songScores;
        FlxG.save.data.songRating = Highscore.songRating;
        FlxG.save.data.weekScores = Highscore.weekScores;
        FlxG.save.flush();
    }

	function clearWeeks() {
        FlxG.save.data.weekCompleted.clear();
        FlxG.save.flush();
    }

	function clearFreeplay() {
		// @Square789: commented out. Freeplay as it was is gone.
		// FreeplayState.lastPlayed = [];
		// FlxG.save.data.lastPlayed = FreeplayState.lastPlayed;
        // FlxG.save.flush();
    }

	function clearAchievements() {
		AchievementManager.resetAchievements();
		FlxG.save.flush();
	}

	function hideMouse() {
		FlxG.mouse.visible = false;
	}
}