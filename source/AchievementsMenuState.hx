package;

import flixel.addons.transition.TransitionData;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxCamera;
#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.text.FlxText;

import AchievementManager;
import OrganicPixelErasureShader.ManualTexSizeOrganicPixelErasureShader;
import RoundedCornerShader.ManualTexSizeRoundedCornerShader;

using CoolUtil.InflatedPixelSpriteExt;
using StringTools;



typedef AchievementDisplayStruct = {
	icon:FlxSprite,
	nameText:FlxText,
	descText:FlxText,
	entry:AchievementRegistryEntry,
}

private final INTER_ACHIEVEMENT_PADDING = 42;
private final BORDER_PADDING = 32;


class AchievementsMenuState extends MusicBeatState {
	private var initialSelectionTarget:Null<String>;
	private var mainCam:FlxCamera;
	private var displayedAchievements:Array<AchievementDisplayStruct>;
	private var background:FlxSprite;
	private var curSelected:Int;
	private var holdTimer:HoldTimer;

	public override function new(
		?transIn:Null<TransitionData>, ?transOut:Null<TransitionData>, ?initialSelectionTarget:Null<String>
	) {
		super(transIn, transOut);
		this.initialSelectionTarget = initialSelectionTarget;
	}

	public override function create() {
		super.create();

		mainCam = new FlxCamera();
		mainCam.bgColor = 0xFF030303;
		FlxG.cameras.reset(mainCam);

		background = new FlxSprite(128, 0);
		background.makeInflatedPixelGraphic(0xFF1A1A1B, FlxG.width - 256, 32);
		background.shader = new ManualTexSizeRoundedCornerShader(24.0, FlxG.width - 256, 32, 3.0, 0xFF474748);
		add(background);

		displayedAchievements = [];
		for (entry in AchievementManager.getAchievements()) {
			if (entry.unlockProgress <= 0 && entry.achievement.isSecret()) {
				continue;
			}

			_insertAchievementLine(entry);
		}
		_setBackgroundHeight(displayedAchievements[displayedAchievements.length - 1].icon.y + 150 + BORDER_PADDING);

		holdTimer = new HoldTimer(0.5, 0.18, 0.12);
		holdTimer.listen(controls.ui_downP, controls.ui_down, changeSelection, 1);
		holdTimer.listen(controls.ui_upP, controls.ui_up, changeSelection, -1);
		curSelected = 0;
		if (initialSelectionTarget != null) {
			for (i => s in displayedAchievements) {
				if (s.entry.achievement.id == initialSelectionTarget) {
					curSelected = i;
					break;
				}
			}
		}

		mainCam.scroll.y = Std.int(
			displayedAchievements[curSelected].icon.y +
			displayedAchievements[curSelected].icon.height * 0.5 -
			mainCam.height * 0.5
		);
	}

	public override function update(dt:Float) {
		super.update(dt);

		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
			MusicBeatState.switchState(new MainMenuF4rpState(true));
			return;
		}

		holdTimer.update(dt);
	}

	private function changeSelection(by:Int) {
		curSelected = CoolUtil.wrapModulo(curSelected + by, displayedAchievements.length);
		tweenScrollCameraTo(
			displayedAchievements[curSelected].icon.y +
			displayedAchievements[curSelected].icon.height * 0.5
		);
	}

	private function tweenScrollCameraTo(y:Float) {
		FlxTween.cancelTweensOf(mainCam);
		FlxTween.tween(mainCam, {"scroll.y": Std.int(y - mainCam.height * 0.5)}, 0.3, {ease: FlxEase.quintOut});
	}

	private function _insertAchievementLine(entry:AchievementRegistryEntry, idx:Int = -1) {
		if (idx < 0 || idx > displayedAchievements.length) {
			idx = displayedAchievements.length;
		}

		// Push following achievement listings away
		for (i in idx...(displayedAchievements.length)) {
			displayedAchievements[i].icon.y += 150 + INTER_ACHIEVEMENT_PADDING;
			displayedAchievements[i].nameText.y += 150 + INTER_ACHIEVEMENT_PADDING;
			displayedAchievements[i].descText.y += 150 + INTER_ACHIEVEMENT_PADDING;
		}

		var icon = new FlxSprite(
			background.x + BORDER_PADDING,
			background.y + BORDER_PADDING + (150 + INTER_ACHIEVEMENT_PADDING) * idx
		);
		if (entry.isLocked() && entry.achievement.shouldHideIconWhenLocked()) {
			icon.loadGraphic(Paths.image('achievement_locked'));
		} else {
			icon.loadGraphic(Paths.image('achievements/${entry.achievement.id}'));
		}
		icon.shader = new RoundedCornerShader(16.0);

		var nameText = new FlxText(icon.x + icon.width + 12, icon.y + 24);
		nameText.setFormat("IBM Plex Sans Bold", 32, 0xFFD7DADC);
		nameText.text = (
			(entry.isLocked() && entry.achievement.shouldHideNameWhenLocked()) ?
				"?" :
				entry.getLayerInfo().name
		);

		var descText = new FlxText(icon.x + icon.width + 12, icon.y + 24 + 32 + 12);
		descText.fieldWidth = (background.x + background.width - BORDER_PADDING) - descText.x;
		descText.setFormat("IBM Plex Sans", 24, 0xFFD7DADC);
		descText.text = (
			(entry.isLocked() && entry.achievement.shouldHideDescriptionWhenLocked()) ?
				"?" :
				entry.getLayerInfo().desc
		);

		add(icon);
		add(nameText);
		add(descText);

		displayedAchievements.insert(idx, {icon: icon, nameText: nameText, descText: descText, entry: entry});
	}

	private function _setBackgroundHeight(newHeight:Float) {
		background.scale.y = newHeight;
		background.height = newHeight;
		cast(background.shader, ManualTexSizeRoundedCornerShader).texture_size.value[1] = newHeight;
	}

	private override function processAchievementsToShow(?onDisplayDone:Null<Void->Void>):Null<AchievementRegistryEntry> {
		var newEntry = super.processAchievementsToShow(onDisplayDone);
		if (newEntry == null) {
			return null;
		}

		var newAchievement = newEntry.achievement;
		// There is a pending achievement that needs to be inserted into the currently displayed ones.
		if (newEntry.unlockProgress <= 0) {
			// Mega strange and should not happen probably idk why i am writing this if statement
			return newEntry;
		}

		var idx:Int = -1;
		for (i => trio in displayedAchievements) {
			if (trio.entry.achievement.id == newEntry.achievement.id) {
				idx = i;
				break;
			}
		}
		if (idx == -1) {
			// Must be a secret achievement, find and prepare insertion point
			var insertionIdx = displayedAchievements.length;
			for (i => trio in displayedAchievements) {
				if (trio.entry.index > newEntry.index) {
					insertionIdx = i;
					break;
				}
			}

			_insertAchievementLine(newEntry, insertionIdx);
			_setBackgroundHeight(displayedAchievements[displayedAchievements.length - 1].icon.y + 150 + BORDER_PADDING);
		} else {
			var info = newEntry.getLayerInfo();
			displayedAchievements[idx].nameText.text = info.name;
			displayedAchievements[idx].descText.text = info.desc;
		}

		return newEntry;
	}
}
