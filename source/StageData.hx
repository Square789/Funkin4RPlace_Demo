package;

#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#else
import openfl.utils.Assets;
#end
import haxe.Json;

using StringTools;

typedef StageFile = {
	var directory:String;
	var defaultZoom:Float;
	var ?opponentZoom:Float; // farp addition
	var ?isPixelStage:Bool;

	var ?pixelCoords:Bool; // farp addition
	var boyfriend:Array<Float>;
	var girlfriend:Array<Float>;
	var opponent:Array<Float>;
	var ?hide_girlfriend:Bool;

	var ?camera_boyfriend:Array<Float>;
	var ?camera_opponent:Array<Float>;
	var ?camera_girlfriend:Array<Float>;
	var ?camera_boyfriend_fixed:Bool;
	var ?camera_opponent_fixed:Bool;
	var ?camera_girlfriend_fixed:Bool;
	var ?camera_speed:Float;
	var ?camera_ease:String; // farp addition
}

class StageData {
	public static var forceNextDirectory:String = null;
	public static function loadDirectory(SONG:SwagSong) {
		var stage:String = '';
		if (SONG.stage != null) {
			stage = SONG.stage;
		} else {
			stage = 'stage';
		}
		// @Square789: There used to be a massive switch-case here that set the stage
		// depending on the base game's song names in SONG.song.

		var stageFile:StageFile = getStageFile(stage);
		if (stageFile == null) { //preventing crashes
			forceNextDirectory = '';
		} else {
			forceNextDirectory = stageFile.directory;
		}
	}

	public static function getStageFile(stage:String):StageFile {
		var rawJson:String = null;
		var path:String = Paths.getPreloadPath('stages/$stage.json');

		#if MODS_ALLOWED
		var modPath:String = Paths.modFolders('stages/$stage.json');
		if (FileSystem.exists(modPath)) {
			rawJson = File.getContent(modPath);
		} else if (FileSystem.exists(path)) {
			rawJson = File.getContent(path);
		}
		#else
		if (Assets.exists(path)) {
			rawJson = Assets.getText(path);
		}
		#end
		else
		{
			return null;
		}

		var stageFile:StageFile = cast Json.parse(rawJson);
		if (stageFile.isPixelStage == null) {
			stageFile.isPixelStage = false;
		}
		if (stageFile.opponentZoom == null) {
			stageFile.opponentZoom = stageFile.defaultZoom;
		}
		if (stageFile.hide_girlfriend == null) {
			stageFile.hide_girlfriend = false;
		}
		if (stageFile.camera_boyfriend == null) {
			stageFile.camera_boyfriend = [0, 0];
		}
		if (stageFile.camera_opponent == null) {
			stageFile.camera_opponent = [0, 0];
		}
		if (stageFile.camera_girlfriend == null) {
			stageFile.camera_girlfriend = [0, 0];
		}
		if (stageFile.camera_boyfriend_fixed == null) {
			stageFile.camera_boyfriend_fixed = false;
		}
		if (stageFile.camera_opponent_fixed == null) {
			stageFile.camera_opponent_fixed = false;
		}
		if (stageFile.camera_girlfriend_fixed == null) {
			stageFile.camera_girlfriend_fixed = false;
		}
		if (stageFile.camera_speed == null) {
			stageFile.camera_speed = 1;
		}
		if (stageFile.pixelCoords == null) {
			stageFile.pixelCoords = false;
		}
		if (stageFile.camera_ease == null) {
			stageFile.camera_ease = "expoOut";
		}

		if (stageFile.pixelCoords) {
			var coords = [
				stageFile.boyfriend, stageFile.girlfriend, stageFile.opponent,
				stageFile.camera_boyfriend, stageFile.camera_opponent, stageFile.camera_girlfriend,
			];
			for (coord in coords) {
				for (i in 0...coord.length) {
					coord[i] *= PlayState.daPixelZoom;
				}
			}
			stageFile.defaultZoom /= PlayState.daPixelZoom;
			stageFile.opponentZoom /= PlayState.daPixelZoom;
		}

		return stageFile;
	}
}