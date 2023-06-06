package;


import flixel.FlxG;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.FlxSprite;
import flixel.FlxCamera;
import openfl.display.BitmapData;

import AchievementManager.AchievementRegistryEntry;
import PixelErasureShader.GradientPixelErasureShader;


class CustomFadeTransition extends MusicBeatSubState {
	public static var finishCallback:Void->Void;
	public static var nextCamera:FlxCamera;

	private var leTween:FlxTween = null;
	private var isTransIn:Bool = false;
	private var transSprite:FlxSprite;
	private var gradShader:GradientPixelErasureShader;

	public function new(duration:Float, isTransIn:Bool) {
		super();

		this.isTransIn = isTransIn;

		var zoom:Float = CoolUtil.boundTo(FlxG.camera.zoom, 0.05, 1);
		var width:Int = Std.int(FlxG.width / zoom);
		var height:Int = Std.int(FlxG.height / zoom);

		transSprite = new FlxSprite(0, 0).makeGraphic(width, height + 400, FlxColor.TRANSPARENT);
		transSprite.scrollFactor.set(0, 0);
		gradShader = new GradientPixelErasureShader();
		// played around with a full palette and a high more_void value too, but that doesn't
		// look good, ultimately
		gradShader.palette.input = new BitmapData(1, 1, true, FlxColor.BLACK);
		gradShader.pixel_dimensions.value = [8.0, 8.0];
		gradShader.ignore_alpha.value[0] = true;

		// Remember: A transparent sprite is a healthy sprite
		if (isTransIn) {
			// transition into a new state.
			// restore pixel health from bottom to top
			// Value ([2]) of gradient_stop always needs to be larger than gradient_start's
			gradShader.gradient_start.value[1] = 1.05;
			gradShader.gradient_stop.value[1] = 1.1;
			gradShader.gradient_start.value[2] = 0.0;
			gradShader.gradient_stop.value[2] = 1.0;
			// gradShader.more_void.value[0] = 1.0;

			FlxTween.tween(
				gradShader,
				{gradient_start_y_direct: -0.6, gradient_stop_y_direct: 0.0/*, more_void_direct: 0.994*/},
				duration,
				{
					onComplete: function(twn:FlxTween) {
						close();
					},
					ease: FlxEase.linear
				}
			);
		} else {
			// transition out of a state into something else.
			// Deterioate pixel health from bottom to top
			gradShader.gradient_start.value[1] = 1.1;
			gradShader.gradient_stop.value[1] = 1.05;
			gradShader.gradient_start.value[2] = 0.0;
			gradShader.gradient_stop.value[2] = 1.0;
			// gradShader.more_void.value[0] = 0.994;

			FlxTween.tween(
				gradShader,
				{gradient_start_y_direct: 0.0, gradient_stop_y_direct: -0.6/*, more_void_direct: 1.0*/},
				duration,
				{
					onComplete: function(twn:FlxTween) {
						if (finishCallback != null) {
							finishCallback();
						}
					},
					ease: FlxEase.linear
				}
			);
		}

		transSprite.shader = gradShader;
		add(transSprite);

		if (nextCamera != null) {
			transSprite.cameras = [nextCamera];
		}
		nextCamera = null;
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		gradShader.seed.value[0] += elapsed;
	}

	// Transition scenes must never show achievements
	public override function processAchievementsToShow(?_:() -> Void):Null<AchievementRegistryEntry> {
		return null;
	}

	override function destroy() {
		if (leTween != null) {
			finishCallback();
			leTween.cancel();
		}
		super.destroy();
	}
}
