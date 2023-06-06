
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import haxe.ValueException;
import openfl.display.BitmapData;

import OrganicPixelErasureShader.ManualTexSizeSidePulserOrganicPixelErasureShader;
import editors.ChartingState;

using StringTools;

private final HIGHLIGHT_STRIP_PIXEL_SIZE:Float = 4.0;
private final HIGHLIGHT_STRIP_PIXEL_HEIGHT:Int = 3;

class FreeplaySongData extends SongData {
	// global bs
	var weekIndex:Int;
	var folder:String;

	// nicer way to access the mix arrays
	public var mixId(default, set):Int = 0;
	public var songName(get, null):String;
	public var meta(get, null):MetaFile;
	public var defaultMeta(get, null):MetaFile;
	public var difficulties(get, null):Array<String>;

	public var avaliableMixSongNames:Array<String> = [];
	public var availableMixMetas:Array<MetaFile> = [];
	public var availableMixDifficulties:Array<Array<String>> = [];

	public function new(songData:Array<Dynamic>, weekIndex:Int, ?folder:Null<String>) {
		super(songData);

		this.weekIndex = weekIndex;

		var defaultMeta:MetaFile = Song.getMetaFile(this.name) ?? {};

		defaultMeta.displayName = defaultMeta.displayName ?? this.name;
		defaultMeta.iconHiddenUntilPlayed = defaultMeta.iconHiddenUntilPlayed ?? false;

		for (i => mix in availableMixes) {
			if (mix == SongData.DEFAULT_MIX) {
				this.avaliableMixSongNames[i] = this.name;
				this.availableMixMetas[i] = defaultMeta;
				this.availableMixDifficulties[i] = CoolUtil.getDifficultiesRet(this.name, true, defaultMeta);
			} else {
				var mixSongName = '$name $mix';
				var mixMeta = Song.getMetaFile(mixSongName);

				mixMeta.displayName = mixMeta.displayName ?? '${defaultMeta.displayName} $mix';
				mixMeta.iconHiddenUntilPlayed = mixMeta.iconHiddenUntilPlayed ?? defaultMeta.iconHiddenUntilPlayed;
				mixMeta.composers = mixMeta.composers ?? defaultMeta.composers;

				this.avaliableMixSongNames[i] = mixSongName;
				this.availableMixMetas[i] = mixMeta;
				this.availableMixDifficulties[i] = CoolUtil.getDifficultiesRet(mixSongName, true, mixMeta);
			};
		}

		this.folder = folder ?? "";
	}

	public function setStaticBullcrap(setDiffs:Bool = true) {
		Paths.currentModDirectory = folder;
		PlayState.storyWeek = weekIndex;
		if (setDiffs) CoolUtil.difficulties = difficulties.copy();
	}

	public function set_mixId(newId):Int {
		return mixId = CoolUtil.wrapModulo(newId, availableMixes.length);
	}

	public function get_songName():String return avaliableMixSongNames[mixId];
	public function get_meta():MetaFile return availableMixMetas[mixId];
	public function get_defaultMeta():MetaFile return availableMixMetas[availableMixes.indexOf(SongData.DEFAULT_MIX)];
	public function get_difficulties():Array<String> return availableMixDifficulties[mixId];
}

private enum MenuSection {
	SONG;
	// CANVAS;
	DIFFICULTY;
	MIX;
}


class FreeplayPlaceState extends MusicBeatState {
	static private var selectedSongIdx:Int = 0;
	static private var selectedDifficultyIdx:Int = FlxMath.maxInt(0, CoolUtil.defaultDifficulties.indexOf(CoolUtil.defaultDifficulty));
	static private var selectedMixIdx:Int = 0;
	private var activeElementIdx:Int = 0;
	private var displayedSongs:Array<FreeplaySongData>;
	private var canvasCamera:FlxCamera;
	private var uiCamera:FlxCamera;
	private var cameraTarget:FlxObject;

	private var mixNameText:FlxText;
	private var mixLeftArrow:FlxSprite;
	private var mixRightArrow:FlxSprite;
	private var songNameText:FlxText;
	private var songLeftArrow:FlxSprite;
	private var songRightArrow:FlxSprite;
	private var scoreText:FlxText;
	private var difficultySprite:FlxSprite;
	private var difficultyLeftArrow:FlxSprite;
	private var difficultyRightArrow:FlxSprite;
	private var upperBar:FlxSprite;
	private var lowerBar:FlxSprite;
	private var highlightStrip:FlxSprite;
	private var highlightStripShader:ManualTexSizeSidePulserOrganicPixelErasureShader;
	private var leInfoText:FlxText;

	private final ELEMENT_ORDER:Array<MenuSection> = [SONG, DIFFICULTY, MIX];

	public override function create() {
		displayedSongs = [];

		// @Square789: Copypasted from old playstate
		// God knows what this does, but it does cause an error in the rendering system if super.create()
		// is called beforehand. Very nice.
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		AtlasFrameMaker.clearCache();

		// persistentUpdate = true; // freeze on open substate, this is used in the wrongest way originally
		PlayState.isStoryMode = false; // Worst control flow of all time
		WeekData.reloadWeekFiles(false);
		CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy(); // wtf why

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		for (weekIdx => weekId in WeekData.weeksList) {
			var week:WeekData = WeekData.weeksLoaded[weekId];
			WeekData.setDirectoryFromWeek(week);
			if ((
				!week.startUnlocked &&
				week.weekBefore.length > 0 &&
				!Highscore.completedWeek(week.weekBefore))
			) { // Week is locked
				continue;
			}

			for (song in week.songs) {
				displayedSongs.push(new FreeplaySongData(song, weekIdx));
			}
		}
		// ??? Probably useless, keeping it in regardless
		WeekData.loadTheFirstEnabledMod();

		// Camera setup, required for scenes with more than 1 cam somehow i guess
		uiCamera = new FlxCamera();
		canvasCamera = new FlxCamera();
		canvasCamera.bgColor = 0xff333333;
		uiCamera.bgColor.alpha = 0x00;

		FlxG.cameras.reset(canvasCamera);
		FlxG.cameras.add(uiCamera, false);
		// This is the worst. Needed, otherwise the transition will appear on the canvasCamera
		// and appear behind UI elements.
		CustomFadeTransition.nextCamera = uiCamera;
		cameraTarget = new FlxObject(0, 0, 1, 1);
		canvasCamera.follow(cameraTarget);

		// Populate canvas cam
		var orrSloshPlace = new FlxSprite(0, 0, Paths.image("place_edit"));
		orrSloshPlace.antialiasing = false;

		var edge = new FlxSprite(0, 0, Paths.image("snoo_edge"));
		edge.setGraphicSize(Std.int(edge.width / 60));
		edge.updateHitbox();
		edge.x = orrSloshPlace.x - (edge.width * 0.33);
		edge.y = orrSloshPlace.x - (edge.height * 0.67);
		edge.angle = 3.21;

		var c = [canvasCamera];
		for (canvasItem in [edge, orrSloshPlace]) {
			canvasItem.cameras = c;
			add(canvasItem);
		}

		// Populate UI cam
		upperBar = new FlxSprite(-1, -1).makeGraphic(FlxG.width + 2, Std.int(FlxG.height * 0.23 + 1), 0xFF030303);
		lowerBar = new FlxSprite(-1).makeGraphic(FlxG.width + 2, Std.int(FlxG.height * /*0.35*/ 0.23 + 1), 0xFF030303);
		lowerBar.y = FlxG.height - lowerBar.height + 1;

		highlightStrip = new FlxSprite().makeGraphic(
			1, HIGHLIGHT_STRIP_PIXEL_HEIGHT * Std.int(HIGHLIGHT_STRIP_PIXEL_SIZE), FlxColor.WHITE
		);
		highlightStripShader = new ManualTexSizeSidePulserOrganicPixelErasureShader();
		highlightStripShader.eraser_color.value = [0x00, 0x00, 0x00, 0xFF];
		highlightStripShader.pixel_dimensions.value = [HIGHLIGHT_STRIP_PIXEL_SIZE, HIGHLIGHT_STRIP_PIXEL_SIZE];
		highlightStrip.shader = highlightStripShader;

		mixNameText = new FlxText(0, 6, 0);
		mixNameText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, RIGHT);

		songNameText = new FlxText(0, 64, 0);
		songNameText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		scoreText = new FlxText(0, songNameText.y + songNameText.size + 8, 0);
		scoreText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, RIGHT);

		difficultySprite = new FlxSprite();

		mixLeftArrow = new FlxSprite();
		mixRightArrow = new FlxSprite();
		songLeftArrow = new FlxSprite();
		songRightArrow = new FlxSprite();
		difficultyLeftArrow = new FlxSprite();
		difficultyRightArrow = new FlxSprite();
		var arrowFrames = Paths.getSparrowAtlas("menu_arrows");
		for (i in [
			{o: mixLeftArrow,         name: "long_left",  size: 1.5},
			{o: mixRightArrow,        name: "long_right", size: 1.5},
			{o: songLeftArrow,        name: "long_left",  size: 2},
			{o: songRightArrow,       name: "long_right", size: 2},
			{o: difficultyLeftArrow,  name: "big_left",   size: 2},
			{o: difficultyRightArrow, name: "big_right",  size: 2},
		]) {
			i.o.frames = arrowFrames;
			i.o.frame = arrowFrames.getByName(i.name);
			i.o.antialiasing = false;
			i.o.setGraphicSize(Std.int(i.o.width * i.size));
			i.o.updateHitbox();
		}

		leInfoText = new FlxText(0, FlxG.height, FlxG.width);
		leInfoText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
		leInfoText.text = 'Press CTRL to open the Gameplay Changers Menu\nPress RESET [${controls.getFormattedInputNames(RESET)}] to Reset your Score and Accuracy.';
		leInfoText.y -= leInfoText.height;

		c = [uiCamera];
		for (uiItem in [
			upperBar, lowerBar, leInfoText, mixNameText, songNameText, scoreText, difficultySprite,
			songLeftArrow, songRightArrow, difficultyLeftArrow, difficultyRightArrow,
			mixLeftArrow, mixRightArrow, highlightStrip
		]) {
			uiItem.cameras = c;
			add(uiItem);
		}

		super.create();
		readdOrSetAchievementNotificationBoxCamera(uiCamera);

		changeSelectedSong(0);
	}

	override function destroy() {
		FlxG.cameras.bgColor = 0xff000000;
		super.destroy();
	}

	public override function update(dt:Float) {
		super.update(dt);

		// Snap camera if it's close enough
		var diffX = 0.0;
		var diffY = 0.0;
		@:privateAccess {
			diffX = Math.abs(canvasCamera._scrollTarget.x - canvasCamera.scroll.x);
			diffY = Math.abs(canvasCamera._scrollTarget.y - canvasCamera.scroll.y);
		}
		// Snapping 2 canvas pixels on zoom 1 does not matter.
		// Snapping 2 canvas pixels on zoom 8 very much does, so prevent that by multiplying with zoom.
		diffX *= canvasCamera.zoom;
		diffY *= canvasCamera.zoom;
		if (diffX < 1.5 && diffY < 1.5) {
			canvasCamera.snapToTarget();
		}

		highlightStripShader.update(dt);

		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
			CustomFadeTransition.nextCamera = uiCamera;
			MusicBeatState.switchState(new MainMenuF4rpState(true));
			return;
		}

		if (FlxG.keys.justPressed.CONTROL) {
			openSubState(new GameplayChangersSubState(uiCamera));
			return;
		}

		if (controls.RESET) {
			var selectedSong = displayedSongs[selectedSongIdx];
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			// [[See the `Highscore.formatSong` rant below]]
			selectedSong.setStaticBullcrap();
			openSubState(new ResetScoreSubState(selectedSong.songName, selectedDifficultyIdx, selectedSong.presentedOpponent, '', selectedSong.meta.displayName, uiCamera));
			return;
		}

		if (controls.ACCEPT) {
			var selectedSong = displayedSongs[selectedSongIdx];
			if (selectedSong.difficulties.length > 0) {
				// Highscore(why the fuck does Highscore deliver the json filename anyways (at least that is
				// what i think this method does)).formatSong relies on the CONTENTS of
				// CoolUtil.difficulties, which it accesses via an index instead of - oh idk maybe just
				// the difficulty as the string? Fuck this so much, dude
				selectedSong.setStaticBullcrap();
				var name = selectedSong.songName;
				var poop:String = Highscore.formatSong(name, selectedDifficultyIdx, false);

				// Set some more global static magic garbage
				PlayState.SONG = Song.loadFromJson(poop, name);
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = selectedDifficultyIdx;
				PlayState.SONG.meta = selectedSong.meta;
				PlayState.SONG.freeplaySongData = selectedSong;

				CustomFadeTransition.nextCamera = uiCamera;

				trace('CURRENT WEEK: ${WeekData.getWeekName()}');

				#if CHART_EDITOR_ALLOWED
				if (FlxG.keys.pressed.SHIFT) {
					PlayState.chartingMode = true;
					LoadingState.loadAndSwitchState(new ChartingState(false));
				} else {
				#end
				LoadingState.loadAndSwitchState(new PlayState());
				#if CHART_EDITOR_ALLOWED
				}
				#end

				FlxG.sound.music.volume = 0;

				#if PRELOAD_ALL
				destroyFreeplayVocals();
				#end
			}
			return;
		}

		if (controls.UI_UP_P != controls.UI_DOWN_P) {
			var change = controls.UI_DOWN_P ? 1 : -1;
			changeActiveElement(change);
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}

		if (controls.UI_LEFT_P != controls.UI_RIGHT_P) {
			var change = controls.UI_RIGHT_P ? 1 : -1;
			switch (ELEMENT_ORDER[activeElementIdx]) {
			case SONG:
				changeSelectedSong(change);
			case DIFFICULTY:
				changeSelectedDifficulty(change);
			case MIX:
				changeSelectedMix(change);
			}
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}
	}

	public function changeActiveElement(by:Int) {
		var currentSong = displayedSongs[selectedSongIdx];
		activeElementIdx = CoolUtil.wrapModulo(activeElementIdx + by, ELEMENT_ORDER.length);
		if (by != 0) {
			var selectionOk = false;
			while (true) {
				selectionOk = switch (ELEMENT_ORDER[activeElementIdx]) {
					case SONG:       true;
					case DIFFICULTY: currentSong.difficulties.length > 0;
					case MIX:        currentSong.availableMixes.length > 1;
				};
				if (selectionOk) {
					break;
				}
				activeElementIdx = CoolUtil.wrapModulo(activeElementIdx + FlxMath.signOf(by), ELEMENT_ORDER.length);
			}
		}
		repositionHighlightStrip();
	}

	public function changeSelectedSong(by:Int) {
		selectedSongIdx = CoolUtil.wrapModulo(selectedSongIdx + by, displayedSongs.length);

		var newSong = displayedSongs[selectedSongIdx];

		songNameText.text = newSong.defaultMeta.displayName;
		songNameText.screenCenter(X);

		newSong.mixId = selectedMixIdx;
		retainOldDifficulty(by, 0);

		// Sic camera onto new location
		var eases = [FlxEase.quintOut, FlxEase.quintIn];
		if (canvasCamera.zoom > newSong.placeZoom) eases = [FlxEase.quintInOut, FlxEase.quintOut];
		var duration = Math.max(1, FlxMath.vectorLength(cameraTarget.x - newSong.placePos.x, cameraTarget.y - newSong.placePos.y) / 500);
		FlxTween.cancelTweensOf(cameraTarget);
		FlxTween.cancelTweensOf(canvasCamera);
		FlxTween.tween(cameraTarget, {x: newSong.placePos.x, y: newSong.placePos.y}, duration, {ease: eases[0]});
		FlxTween.tween(canvasCamera, {zoom: newSong.placeZoom}, duration, {ease: eases[1]});

		// Recolor highlight to the song's color
		highlightStrip.color = newSong.color;

		repositionSongArrows();
		changeSelectedMix(0);
	}

	public function changeSelectedDifficulty(by:Int) {
		var currentSong = displayedSongs[selectedSongIdx];
		var diffs = currentSong.difficulties;
		var brandNewDifficulty:String;
		var hasDiffs = diffs.length > 0;
		difficultySprite.visible = hasDiffs;
		difficultyLeftArrow.visible = hasDiffs;
		difficultyRightArrow.visible = hasDiffs;
		if (hasDiffs) {
			selectedDifficultyIdx = CoolUtil.wrapModulo(selectedDifficultyIdx + by, diffs.length);
			brandNewDifficulty = diffs[selectedDifficultyIdx].toLowerCase().replace(' ', '-');
			difficultySprite.loadGraphic(Paths.image('menudifficulties/$brandNewDifficulty'));
		}

		repositionDifficultySection();

		#if HIGHSCORE_ALLOWED
		CoolUtil.difficulties = diffs.copy(); // fuck this
		var name = currentSong.songName;
		var score = Highscore.getScore(name, selectedDifficultyIdx);
		var ratingStr = Std.string(Std.int(Math.fround(
			Highscore.getRating(name, selectedDifficultyIdx) * 10000
		)));
		if (ratingStr.length <= 2) {
			ratingStr = "0." + ratingStr.rpad('0', 2);
		} else {
			ratingStr = ratingStr.substr(0, ratingStr.length - 2) + '.' + ratingStr.substr(ratingStr.length - 2, 2);
		}
		scoreText.text = '$score ($ratingStr%)';
		scoreText.screenCenter(X);
		#end
		repositionHighlightStrip();
	}

	public function changeSelectedMix(by:Int) {
		var currentSong = displayedSongs[selectedSongIdx];
		var mixes = currentSong.availableMixes;

		if (mixes.length > 1) {
			selectedMixIdx = currentSong.mixId += by;

			var newMix:String = mixes[currentSong.mixId];
			var mixDisplayName:String = newMix;

			retainOldDifficulty(0, by);

			mixNameText.visible = true;
			mixLeftArrow.visible = true;
			mixRightArrow.visible = true;

			mixNameText.text = mixDisplayName;
			mixNameText.screenCenter(X);
			repositionMixArrows();

			repositionHighlightStrip();
		} else {
			mixNameText.visible = false;
			mixLeftArrow.visible = false;
			mixRightArrow.visible = false;
		}

		changeSelectedDifficulty(0);
	}

	private function retainOldDifficulty(songBy:Int, mixBy:Int) {
		var oldSongIdx = CoolUtil.wrapModulo(selectedSongIdx - songBy, displayedSongs.length);
		var oldSong = displayedSongs[oldSongIdx];
		var oldSongMixIdx = CoolUtil.wrapModulo(oldSong.mixId - mixBy, oldSong.availableMixDifficulties.length);
		var oldDifficulty = oldSong.availableMixDifficulties[oldSongMixIdx][selectedDifficultyIdx];

		var currentSong = displayedSongs[selectedSongIdx];

		// It is possible that the new song has different difficulties from
		// the other one. Rectify here.
		var x = currentSong.difficulties.indexOf(oldDifficulty);
		// The old freeplay state had a bunch of code here that checks for a title-cased,
		// capitalized and lowercased variant, but we can fix this problem by staying uniform
		// in one naming style! (pfft yeah, as if)
		if (x == -1) {
			x = FlxMath.maxInt(0, currentSong.difficulties.indexOf(CoolUtil.defaultDifficulty));
		}
		selectedDifficultyIdx = x;
	} 

	private function repositionSongArrows() {
		songLeftArrow.x = songNameText.x - songLeftArrow.width - 5;
		songLeftArrow.y = songNameText.y + (songNameText.size - songLeftArrow.height) / 2;
		songRightArrow.x = songNameText.x + songNameText.width + 5;
		songRightArrow.y = songNameText.y + (songNameText.size - songRightArrow.height) / 2;
	}

	private function repositionMixArrows() {
		mixLeftArrow.x = mixNameText.x - mixLeftArrow.width - 5;
		mixLeftArrow.y = mixNameText.y + (mixNameText.size - mixLeftArrow.height) / 2;
		mixRightArrow.x = mixNameText.x + mixNameText.width + 5;
		mixRightArrow.y = mixNameText.y + (mixNameText.size - mixRightArrow.height) / 2;
	}

	private function repositionDifficultySection() {
		difficultySprite.screenCenter(X);
		difficultySprite.y = lowerBar.y + (lowerBar.height - difficultySprite.height) / 2;
		difficultyLeftArrow.x = difficultySprite.x - difficultyLeftArrow.width - 5;
		difficultyLeftArrow.y = difficultySprite.y + (difficultySprite.height - difficultyLeftArrow.height) / 2;
		difficultyRightArrow.x = difficultySprite.x + difficultySprite.width + 5;
		difficultyRightArrow.y = difficultySprite.y + (difficultySprite.height - difficultyRightArrow.height) / 2;
	}

	private function repositionHighlightStrip() {
		var newStripWidth:Float;
		switch (ELEMENT_ORDER[activeElementIdx]) {
		case SONG:
			newStripWidth = songRightArrow.x + songRightArrow.width - songLeftArrow.x;
			highlightStrip.y = scoreText.y + scoreText.size + 8;
			highlightStrip.x = songLeftArrow.x;
		case DIFFICULTY:
			newStripWidth = difficultyRightArrow.x + difficultyRightArrow.width - difficultyLeftArrow.x;
			highlightStrip.y = difficultySprite.y + difficultySprite.height + 16;
			highlightStrip.x = difficultyLeftArrow.x;
		case MIX:
			newStripWidth = mixRightArrow.x + mixRightArrow.width - mixLeftArrow.x;
			highlightStrip.y = mixNameText.y + mixNameText.size + 8;
			highlightStrip.x = mixLeftArrow.x;
		}
		var trueStripWidth:Int = Std.int(Math.ceil(newStripWidth / HIGHLIGHT_STRIP_PIXEL_SIZE) * HIGHLIGHT_STRIP_PIXEL_SIZE);
		highlightStrip.setGraphicSize(trueStripWidth, highlightStrip.graphic.bitmap.height);
		highlightStrip.updateHitbox();
		highlightStrip.x -= Math.floor((trueStripWidth - newStripWidth) / 2.0);
		highlightStripShader.manual_texture_size.value = [highlightStrip.width, highlightStrip.height];
	}
}
