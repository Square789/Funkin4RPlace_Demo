import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.text.FlxText;

/*

    FOR MOBILE

*/

class Button extends FlxButton {
    public function new(x:Float = 0, y:Float = 0, text:String = '', size:Float = 1) {
        super(x, y, text);
        scrollFactor.set();

        loadGraphic(Paths.image('button'));
        antialiasing = ClientPrefs.globalAntialiasing;
        setGraphicSize(Std.int(width * size));
        updateHitbox();
        alpha = 0.5;

        var txtSize = Std.int(20 * size);
        label = new FlxText(0, (height / 2) - (txtSize / 2), width, text, txtSize);
		label.setFormat(Paths.font("vcr.ttf"), txtSize, FlxColor.BLACK, CENTER);
		label.scrollFactor.set();
    }

    override public function update(elapsed:Float) {
        super.update(elapsed);

        if (pressed) {
            alpha = 0.25;
        } else {
            alpha = 0.5;
        }
    }

    override function updateStatusAnimation() {}

    override function updateLabelPosition()
	{
		if (_spriteLabel != null) // Label positioning
		{
			_spriteLabel.x = (pixelPerfectPosition ? Math.floor(x) : x) + labelOffsets[status].x;
			_spriteLabel.y = (pixelPerfectPosition ? Math.floor(y) : y) + ((height / 2) - (label.size / 2)) + labelOffsets[status].y;
		}
	}

    override function updateLabelAlpha() {}
}