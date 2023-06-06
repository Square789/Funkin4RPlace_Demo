package;

import flixel.math.FlxMath;

/**
 * ...
 * @author
 */

typedef BPMChangeEvent =
{
	var stepTime:Int;
	var songTime:Float;
	var bpm:Float;
	var timeSignature:Array<Int>;
	@:optional var stepCrochet:Float;
}

class Conductor
{
	public static var bpm:Float = 100;
	public static var timeSignature:Array<Int> = [4, 4];
	public static var crochet:Float = ((60 / bpm) * 4000) / timeSignature[1]; // beats in milliseconds
	public static var normalizedCrochet(get, never):Float;
	public static var stepCrochet:Float = crochet / 4; // steps in milliseconds
	public static var normalizedStepCrochet(get, never):Float;
	public static var songPosition:Float = 0;
	public static var playbackRate:Float = 1;

	public static var safeZoneOffset:Float = (ClientPrefs.safeFrames / 60) * 1000; // is calculated in create(), is safeFrames in milliseconds

	public static var bpmChangeMap:Array<BPMChangeEvent> = [];

	public static function get_normalizedCrochet():Float {
		return crochet * (timeSignature[1] / 4);
	}

	public static function get_normalizedStepCrochet():Float {
		return stepCrochet * (timeSignature[1] / 4);
	}

	public static function judgeNote(note:Note, diff:Float = 0):Rating // die
	{
		var data:Array<Rating> = PlayState.instance.ratingsData; //shortening cuz fuck u
		for(i in 0...data.length - 1) //skips last window (Shit)
		{
			if (diff <= data[i].hitWindow * playbackRate)
			{
				return data[i];
			}
		}
		return data[data.length - 1];
	}

	public static function getCrotchetAtTime(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepCrochet * 4;
	}

	public static function getBPMFromSeconds(time:Float){
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			timeSignature: timeSignature,
			stepCrochet: stepCrochet
		}
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (time >= Conductor.bpmChangeMap[i].songTime)
				lastChange = Conductor.bpmChangeMap[i];
		}

		return lastChange;
	}

	public static function getBPMFromStep(step:Float){
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			timeSignature: timeSignature,
			stepCrochet: stepCrochet
		}
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (Conductor.bpmChangeMap[i].stepTime <= step)
				lastChange = Conductor.bpmChangeMap[i];
		}

		return lastChange;
	}

	public static function beatToSeconds(beat:Float): Float{
		var step = beat * 4;
		var lastChange = getBPMFromStep(step);
		return lastChange.songTime + ((step - lastChange.stepTime) / (lastChange.bpm / 60)/lastChange.timeSignature[1]) * 1000; // TODO: make less shit and take BPM into account PROPERLY
	}

	public static function getStep(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + (time - lastChange.songTime) / lastChange.stepCrochet;
	}

	public static function getStepRounded(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return Math.floor(lastChange.stepTime + (time - lastChange.songTime) / lastChange.stepCrochet);
	}

	public static function getBeat(time:Float){
		return getStep(time)/4;
	}

	public static function getBeatRounded(time:Float):Int{
		return Math.floor(getStepRounded(time)/4);
	}

	/**
	 * Creates a new `bpmChangeMap` and `signatureChangeMap` from the inputted song.
	 *
	 * @param	song	Song to take the BPM and time signature changes from.
	 */
	public static function mapBPMChanges(song:SwagSong)
	{
		bpmChangeMap = [];

		var curBPM:Float = song.bpm;
		var curSignature:Array<Int> = song.timeSignature.copy();
		var totalSteps:Int = 0;
		var totalPos:Float = 0;
		for (i in 0...song.notes.length)
		{
			var sec = song.notes[i];
			var doPush = false;
			if (sec.changeBPM)
			{
				curBPM = sec.bpm;
				doPush = true;
			}
			if (sec.changeSignature)
			{
				curSignature = sec.timeSignature.copy();
				doPush = true;
			}
			if (doPush) {
				var event:BPMChangeEvent = {
					stepTime: totalSteps,
					songTime: totalPos,
					bpm: curBPM,
					timeSignature: curSignature,
					stepCrochet: calculateCrochet(curBPM, curSignature[1])/4
				};
				bpmChangeMap.push(event);
			}

			var deltaSteps:Int = sec.lengthInSteps;
			totalSteps += deltaSteps;
			totalPos += calculateCrochet(curBPM, curSignature[1])/4 * deltaSteps;
		}
	}

	inline public static function calculateCrochet(bpm:Float, denominator:Int){
		return ((60 / bpm) * 4000) / denominator;
	}

	/**
	 * Changes the Conductor's BPM.
	 *
	 * @param	newBpm	The BPM to change to.
	 */
	public static function changeBPM(newBpm:Float)
	{
		if (newBpm > 0) {
			bpm = newBpm;
			updateCrochet();
		}
	}

	/**
	 * Changes the Conductor's time signature.
	 *
	 * @param	newNumerator	The numerator (beats per section) to change to.
	 * @param   newDenominator	The denominator (step length, 4 means 1/4 of a whole note) to change to.
	 */
	public static function changeSignature(newSignature:Array<Int>)
	{
		if (newSignature[0] > 0 && newSignature[1] > 0) {
			timeSignature = newSignature.copy();
			updateCrochet();
		}
	}

	static function updateCrochet() {
		crochet = calculateCrochet(bpm, timeSignature[1]);
		stepCrochet = crochet / 4;
	}

	/**
	 * Gets the latest BPM and time signature based on the current step and changes the Conductor values if necessary.
	 *
	 * @param	song	Song to take the BPM and time signature changes from.
	 * @param   step	The current step of the song.
	 */
	public static function getLastBPM(song:SwagSong, step:Int) {
		var daBPM:Float = song.bpm;
		var daSignature:Array<Int> = song.timeSignature;
		for (i in 0...bpmChangeMap.length) {
			if (step >= bpmChangeMap[i].stepTime) {
				daBPM = bpmChangeMap[i].bpm;
				daSignature = bpmChangeMap[i].timeSignature;
			}
		}
		changeBPM(daBPM);
		changeSignature(daSignature);
	}

	/**
	 * Gets the current beat of a song, starting from the last numerator change. Used for camera bopping
	 *
	 * @param	song	Song to take the BPM and time signature changes from.
	 * @param   beat	The current beat of the song.
	 * @return	The current beat of the song, starting from the last numerator change.
	 */
	public static function getCurNumeratorBeat(song:SwagSong, beat:Int):Int {
		var lastBeat = 0;
		var daBeat = 0;
		var daNumerator = song.timeSignature[0];
		for (i in 0...song.notes.length) {
			if (song.notes[i] != null && beat >= daBeat) {
				if (song.notes[i].changeSignature) {
					daNumerator = song.notes[i].timeSignature[0];
					lastBeat = daBeat;
				}
				daBeat += daNumerator;
			}
		}
		return beat - lastBeat;
	}

	/**
	 * @Square789: No real idea what this function does, but it was copypasted in the BeatStates
	 * and only uses global static fields so I pulled it out.
	 * @CoolingTool: Yeah same.
	 */
	public static function getCurStep():CurSteps {
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		return {
			curDecStep: lastChange.stepTime + shit,
			curStep: lastChange.stepTime + Math.floor(shit)
		};
	}
}

typedef CurSteps = {curDecStep:Float, curStep:Int};

class Rating
{
	public var name:String = '';
	public var displayName:String = 'Sick!!';
	public var image:String = '';
	public var counter:String = '';
	public var hitWindow:Null<Int> = 0; //ms
	public var ratingMod:Float = 1;
	public var score:Int = 350;
	public var noteSplash:Bool = true;
	public var causesMiss = false;

	public function new(name:String)
	{
		this.name = name;
		this.image = name;
		this.counter = name + 's';
		this.hitWindow = Reflect.field(ClientPrefs, name + 'Window');
		if(hitWindow == null)
		{
			hitWindow = 0;
		}
	}

	public function increase(blah:Int = 1)
	{
		Reflect.setField(PlayState.instance, counter, Reflect.field(PlayState.instance, counter) + blah);
	}
}