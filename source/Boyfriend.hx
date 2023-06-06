package;

using StringTools;

class Boyfriend extends Character
{
	public var startedDeath:Bool = false;
	public var endingDeath:Bool = false;
	
	var beatBopper:Bool = false;
	var deathBeats:Array<String> = []; // DEADBEATS!!!!!
	var curIdle:Int = 0;

	public function new(x:Float, y:Float, ?char:String = 'bf') {
		super(x, y, char, true);

		var i = 0;
		final deathBeat = 'deathBeat';
		while (animation.getByName(deathBeat+i) != null) {
			deathBeats.push(deathBeat+i);
			i++;
		}

		beatBopper = deathBeats.length > 0;
	}

	override function update(elapsed:Float) {
		if (!debugMode && animation.curAnim != null) {
			if (animation.curAnim.name == 'firstDeath' && animation.curAnim.finished && startedDeath) {
				if (beatBopper)
					dance(true, true);
				else
					playAnim('deathLoop');
			}
		}

		super.update(elapsed);
	}

	override function dance(?forceplay:Bool = false, ?special:Bool = false) {
		if (!beatBopper || !startedDeath || endingDeath) return;

		if (!debugMode && !skipDance && !specialAnim && !specialDance) {
			playAnim(deathBeats[curIdle], forceplay);
			specialDance = special;
			curIdle = (curIdle + 1) % deathBeats.length;
		}
	}
}
