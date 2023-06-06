package;

import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.text.FlxBitmapText;
import flixel.graphics.frames.FlxBitmapFont;
import flixel.system.FlxAssets.FlxAngelCodeSource;

class TitleCardFont extends FlxBitmapText {
	public var forceX:Float = Math.NEGATIVE_INFINITY;
	public var targetY:Float = 0;
	public var isMenuItem:Bool = false;
	public var yMult:Float = 120;
	public var yAdd:Float = 0;
	public var xAdd:Float = 0;


    public function new(x:Float, y:Float, text:String, ?bold:Bool = false, _typed:Bool = false, ?_typingSpeed:Float = 0.05, ?textSize:Float = 1) {
        var fontName = bold ? "titlecard-font-bold" : "titlecard-font";

        // the image also has to be different because of haxeflixels stupid caching
        super(FlxBitmapFont.fromAngelCode(Paths.font('$fontName.png'), Paths.font('$fontName.fnt')));

		forceX = Math.NEGATIVE_INFINITY;

        if (bold) autoUpperCase = true;

        this.x = x;
        this.y = y;
        this.text = text;

        antialiasing = false;
        scale.set(4 * textSize, 4 * textSize);
        updateHitbox();
    }

    override function update(elapsed:Float) {
        if (isMenuItem) {
            var scaledY = FlxMath.remapToRange(targetY, 0, 1, 0, 1.3);

            var lerpVal:Float = CoolUtil.boundTo(elapsed * 9.6, 0, 1);
            y = FlxMath.lerp(y, (scaledY * yMult) + (FlxG.height * 0.48) + yAdd, lerpVal);
            if (forceX != Math.NEGATIVE_INFINITY) {
                x = forceX;
            } else {
                x = FlxMath.lerp(x, (targetY * 20) + 90 + xAdd, lerpVal);
            }
        }

        super.update(elapsed);
    }

    public function instantlySetPosition() {
		if (isMenuItem) {
			var scaledY = FlxMath.remapToRange(targetY, 0, 1, 0, 1.3);
			y = (scaledY * yMult) + (FlxG.height * 0.48) + yAdd;
			if (forceX != Math.NEGATIVE_INFINITY) {
				x = forceX;
			} else {
				x = (targetY * 20) + 90 + xAdd;
			}
		}
	}
}