package;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.math.FlxPoint;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.system.FlxSound;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

using StringTools;


class GameOverSubState extends MusicBeatSubState {
	public var boyfriend:Boyfriend;
	public var camGame:FlxCamera;
	var camFollow:FlxPoint;
	var camFollowPos:FlxObject;
	var deathSound:FlxSound;
	var totalElapsed:Float;
	var playingDeathSound:Bool = false;

	var stageSuffix:String = "";

	// @Square789: Do what the main menu did and throw in a new camera
	// for death achievements
	private var camAchievement:FlxCamera;
	// @Square789: A bunch of setup was done in `new` which the state docs specifically
	// say not to do and i guess the separate cameras finally screwed it all up.
	// Store variables here to have them available in `create`.
	// Ok i think actually i just forgot to set bgColor.alpha to 0 but uuh lmao
	private var creationVars:{bfx:Float, bfy:Float, zoom:Float} = null;

	public static var defaultCamZoom:Float = 1;
	public static var camStartTime:Float = 0.5;
	public static var camDuration:Float = 9;
	public static var camEasing:EaseFunction = FlxEase.expoOut;
	public static var deathSoundEndTime:Float = 2.41;
	public static var loopSoundBPM:Float = 100;
	public static var characterName:String = 'bf-dead';
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'gameOver';
	public static var endSoundName:String = 'gameOverEnd';
	public static var quitSoundName:String = 'gameOverQuit';
	public static var retrySpriteData: Null<{name:String, x:Int, y:Int}>;

	public static var instance:GameOverSubState;

	#if mobile
	var buttonENTER:Button;
	var buttonESC:Button;
	#end

	public static function resetVariables() {
		defaultCamZoom = 1;
		camStartTime = 0.5;
		camDuration = 9;
		camEasing = FlxEase.expoOut;
		deathSoundEndTime = 2.41;
		loopSoundBPM = 100;
		characterName = 'bf-dead';
		deathSoundName = 'fnf_loss_sfx';
		loopSoundName = 'gameOver';
		endSoundName = 'gameOverEnd';
		quitSoundName = 'gameOverQuit';
		retrySpriteData = null;
	}

	public static function selfAssignVariables(char:String, voided:Float) {
		switch(char) {
			case 'flag-bf':
				characterName = voided >= 1.399 ? 'flag-bf-void-death' : 'flag-bf';
				deathSoundName = 'fnf_loss_sfx_no_mic';
				deathSoundEndTime = 1.07;
				retrySpriteData = {name: "flag", x: 3, y: -16};
			case 'bf-pixel': // irrelevant just for testing
				characterName = 'bf-pixel-dead';
				deathSoundName = 'fnf_loss_sfx-pixel';
				loopSoundName = 'gameOver-pixel';
				endSoundName = 'gameOverEnd-pixel';
			case 'bf-holding-gf': // why'not
				characterName = 'bf-holding-gf-dead';
		}
	}

	override function create()
	{
		instance = this;
		PlayState.instance.callOnScripts('onGameOverStart', []);

		super.create();

		camGame = new FlxCamera();
		camAchievement = new FlxCamera();
		camAchievement.bgColor.alpha = 0;
		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camAchievement, false);
		achievementNotificationBox.cameras = [camAchievement];

		camGame.zoom = creationVars.zoom;

		boyfriend = new Boyfriend(creationVars.bfx, creationVars.bfy, characterName);
		boyfriend.x += boyfriend.positionArray[0];
		boyfriend.y += boyfriend.positionArray[1];
		add(boyfriend);

		deathSound = FlxG.sound.play(Paths.sound(deathSoundName));
		Conductor.changeBPM(100);
		FlxG.camera.scroll.set();
		FlxG.camera.target = null;

		boyfriend.playAnim('firstDeath');

		var container = boyfriend.getScreenBounds();

		if (retrySpriteData != null) {
			// Attempt to compensate for topleft weirdness introduced by scaling:
			var scaleDiff = (1.0 - 6.0) * 0.5;
			var trueTopLX = boyfriend.x + (boyfriend.frame.frame.width * scaleDiff);
			var trueTopLY = boyfriend.y + (boyfriend.frame.frame.height * scaleDiff);

			var retrySprite = new FarpSprite(
				trueTopLX + (retrySpriteData.x * 6), (trueTopLY + retrySpriteData.y * 6)
			);
			retrySprite.loadGraphic(Paths.image('retry/${retrySpriteData.name}'));
			retrySprite.pixelSize = 6;
			retrySprite.snapToPixelGrid = true;
			retrySprite.antialiasing = false;
			retrySprite.origin.set(0.0, 0.0);
			retrySprite.setGraphicSize(Std.int(retrySprite.width) * 6);
			add(retrySprite);

			container.union(retrySprite.getScreenBounds());
		}

		camFollow = new FlxPoint(container.x + container.width / 2, container.y + container.height / 2);

		camFollowPos = new FlxObject(0, 0, 1, 1);
		camFollowPos.setPosition(FlxG.camera.scroll.x + (FlxG.camera.width / 2), FlxG.camera.scroll.y + (FlxG.camera.height / 2));
		add(camFollowPos);

		#if mobile
		buttonENTER = new Button(492, 564, 'ENTER');
		add(buttonENTER);
		buttonESC = new Button(buttonENTER.x + 136, buttonENTER.y, 'ESC');
		add(buttonESC);
		#end
	}

	public function new(x:Float, y:Float, zoom:Float)
	{
		super();
		creationVars = {bfx: x, bfy: y, zoom: zoom};

		PlayState.instance.callOnScripts('inGameOver', [true]);

		totalElapsed = 0;
		Conductor.songPosition = 0;
	}

	var isFollowingAlready:Bool = false;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		totalElapsed += elapsed;

		PlayState.instance.callOnScripts('onUpdate', [elapsed]);

		if (controls.ACCEPT #if mobile || buttonENTER.justPressed #end)
		{
			endBullshit();
		}

		if (controls.BACK #if mobile || buttonESC.justPressed #end)
		{
			quitBullshit();
		}

		if (boyfriend.animation.curAnim.name == 'firstDeath' && !boyfriend.startedDeath && !boyfriend.endingDeath)
		{
			// @CoolingTool: why was it hardcoded to only start moving camera on the 12th frame lol
			// well i understand why but still
			if (!isFollowingAlready)
			{	
				isFollowingAlready = true;
				startCamera();
			}

			if (boyfriend.animation.curAnim.finished && (deathSoundEndTime < totalElapsed))
			{
				coolStartDeath();
				boyfriend.startedDeath = true;
			}
		}

		if (FlxG.sound.music.playing)
		{
			Conductor.songPosition = FlxG.sound.music.time;
		}
		PlayState.instance.callOnScripts('onUpdatePost', [elapsed]);
	}

	override function beatHit()
	{
		super.beatHit();
		boyfriend.dance(true);
	}

	function coolStartDeath(?volume:Float = 1):Void {
		FlxG.sound.playMusic(Paths.music(loopSoundName), volume);
		Conductor.changeBPM(loopSoundBPM);
	}

	function startCamera(?delay:Float):Void {
		var options:TweenOptions = {ease: camEasing, startDelay: delay != null ? delay : camStartTime}
		FlxG.camera.follow(camFollowPos, LOCKON, 1);
		FlxTween.tween(camFollowPos, {x: camFollow.x, y: camFollow.y}, camDuration, options);
		FlxTween.tween(camGame, {zoom: defaultCamZoom}, camDuration, options);
	}

	function endBullshit():Void {
		if (!boyfriend.endingDeath)
		{
			boyfriend.endingDeath = true;
			if (boyfriend.animOffsets.exists('deathConfirm'))
				boyfriend.playAnim('deathConfirm', true);
			FlxG.sound.music.stop();
			FlxG.sound.play(Paths.music(endSoundName));
			new FlxTimer().start(0.7, function(tmr:FlxTimer)
			{
				FlxG.camera.fade(FlxColor.BLACK, 2, false, MusicBeatState.resetState);
			});
			PlayState.instance.callOnScripts('onGameOverConfirm', [true]);
		}
	}

	// @CoolingTool: death quit animation
	function quitBullshit():Void
	{
		if (!boyfriend.endingDeath)
		{
			boyfriend.endingDeath = true;
			if (boyfriend.animOffsets.exists('deathCancel'))
				boyfriend.playAnim('deathCancel', true);
			else if (boyfriend.animOffsets.exists('deathConfirm'))
				boyfriend.playAnim('deathConfirm', true);

			FlxG.sound.play(Paths.music(quitSoundName));

			FlxG.sound.music.stop();
			PlayState.deathCounter = 0;
			PlayState.seenCutscene = false;
			PlayState.chartingMode = false;

			new FlxTimer().start(0.3, function(tmr:FlxTimer)
			{
				FlxG.camera.fade(FlxColor.BLACK, .4, false, function() 
				{
					WeekData.loadTheFirstEnabledMod();
					if (PlayState.isStoryMode)
						MusicBeatState.switchState(new MainMenuF4rpState(true));
					else
						MusicBeatState.switchState(new FreeplayPlaceState());

					CoolUtil.playMenuMusic();
				});
			});
		}
		PlayState.instance.callOnScripts('onGameOverConfirm', [false]);
	}
}
