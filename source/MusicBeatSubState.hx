package;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSubState;
import flixel.math.FlxPoint;
import flixel.util.FlxDestroyUtil;
import flixel.input.FlxInput.FlxInputState;

import AchievementManager.AchievementRegistryEntry;
import AchievementNotification.AchievementNotificationBox;

class MusicBeatSubState extends FlxSubState
{
	public var resetCameraOnClose:Bool = false;
	var lastScroll:FlxPoint = FlxPoint.get();
	public function new()
	{
		lastScroll.copyFrom(FlxG.camera.scroll);
		super();
		closeCallback = onClose;
	}

	private var lastBeat:Float = 0;
	private var lastStep:Float = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	private var controls(get, never):Controls;

	private var achievementNotificationBox:AchievementNotificationBox;

	inline function get_controls():Controls {
		return PlayerSettings.player1.controls;
	}

	override function create() {
		super.create();

		achievementNotificationBox = new AchievementNotificationBox(40, 0);
		add(achievementNotificationBox);
	}

	override function update(elapsed:Float) {
		var oldStep:Int = curStep;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep && curStep >= 0) {
			stepHit();
		}

		super.update(elapsed);

		// @Square789: Le copypaste. Why the hell are SubStates their own thing????
		@:privateAccess
		for (key in FlxG.keys._keyListArray) {
			if (key != null && FlxG.keys.checkStatus(key.ID, FlxInputState.JUST_PRESSED)) {
				AchievementManager.notify(KEY_PRESSED, key.ID);
			}
		}
		processAchievementsToShow();
	}

	private function processAchievementsToShow(?onDisplayDone:Null<Void->Void>):Null<AchievementRegistryEntry> {
		return MusicBeatState.stat_processAchievementsToShow(achievementNotificationBox, onDisplayDone);
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep/4;
	}

	private function updateCurStep():Void {
		var curSteps = Conductor.getCurStep();
		curDecStep = curSteps.curDecStep;
		curStep = curSteps.curStep;
	}

	public function stepHit():Void
	{
		if (curStep % 4 == 0)
			beatHit();
	}

	public function beatHit():Void
	{
		//do literally nothing dumbass
	}

	function onClose() {
		if (resetCameraOnClose) {
			FlxG.camera.follow(null);
			FlxG.camera.scroll.set();
		}

		lastScroll = FlxDestroyUtil.put(lastScroll);
	}
}
