package;

import flixel.input.actions.FlxAction.FlxActionDigital;
import haxe.ValueException;
import flixel.math.FlxMath;

class HoldTimer {

	var initialWait:Float;
	var intervalIni:Float;
	var intervalHrz:Float;
	var lastInterval:Float;
	var intervalLerp:Float;
	var timeUntilScroll:Float;
	private var listeners:Array<{ini:FlxActionDigital, hold:FlxActionDigital, callback:Int->Void, param:Int}>;
	public var activeListener(default, null):Int;

	public function new(initialWait:Float, intervalIni:Float, ?intervalHorizon:Null<Float>, horizonApproachFactor:Float = 0.5) {
		if (horizonApproachFactor <= 0.001 || intervalIni <= 0.001 || horizonApproachFactor < 0.0 || initialWait < 0.0) {
			throw new ValueException("Some value was too small or less than 0, like come on man");
		}
		this.initialWait = initialWait;
		this.intervalIni = intervalIni;
		this.intervalHrz = intervalHorizon == null ? intervalIni : intervalHorizon;
		this.lastInterval = intervalIni;
		this.intervalLerp = horizonApproachFactor;
		this.timeUntilScroll = initialWait;
		this.listeners = [];
		this.activeListener = -1;
	}

	public function listen(
		initiator:FlxActionDigital, hold:FlxActionDigital, ?callback:Null<Int->Void>, param:Int = 1
	) {
		listeners.push({ini: initiator, hold: hold, callback: callback, param: param});
	}

	public function update(dt:Float, suppressCallbacks:Bool = false):Int {
		var scrolls = 0;
		for (i => listener in listeners) {
			// Check all listeners whether one was started off
			if (listener.ini.check() && activeListener != i) {
				// Otherwise user managed to press a key twice while holding it, so is either a time
				// traveler or in possession of two keyboards. Ignore in that case.
				activeListener = i;
				scrolls += 1;
				lastInterval = intervalIni;
				timeUntilScroll = initialWait + intervalIni + dt;
				break;
			}
		}
		if (activeListener < 0) {
			// No listener running, return 0
			return scrolls;
		}

		var listener = listeners[activeListener];
		if (!listener.hold.check()) {
			// If not held anymore, stop listening.
			// By all means should impossible this runs when one was just activated,
			// but who knows
			activeListener = -1;
			return scrolls;
		}

		timeUntilScroll -= dt;
		while (timeUntilScroll <= 0.0) {
			scrolls += 1;
			lastInterval = FlxMath.lerp(lastInterval, intervalHrz, intervalLerp);
			timeUntilScroll += lastInterval;
		}
		if ((!suppressCallbacks) && scrolls > 0 && listener.callback != null) {
			listener.callback(listener.param * scrolls);
		}
		return scrolls;
	}
}
