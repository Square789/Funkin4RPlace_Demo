package;

import flixel.FlxCamera;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.FlxSprite;
import flixel.math.FlxPoint;

class BGSprite extends FarpSprite
{
	public var originalPosition:FlxPoint;

	public var danceEveryNumBeats = 2;

	private var idleAnim:String;
	public function new(image:String, x:Float = 0, y:Float = 0, ?scrollX:Float = 1, ?scrollY:Float = 1, ?animArray:Array<String> = null, ?loop:Bool = false, ?fps = 24) {
		super(x, y);

		originalPosition = new FlxPoint(x, y);

		if (animArray != null) {
			if (Paths.fileExists('images/$image}.txt', TEXT))
			{
				frames = Paths.getPackerAtlas(image);
			}
			else if (Paths.fileExists('images/$image.json', TEXT))
			{
				frames = Paths.getTexturePackerAtlas(image);
			}
			else if (Paths.fileExists('images/$image/Animation.json', TEXT))
			{
				frames = AtlasFrameMaker.construct(image);	
			}
			else
			{
				frames = Paths.getSparrowAtlas(image);
			}
			for (i in 0...animArray.length) {
				var anim:String = animArray[i];
				animation.addByPrefix(anim, anim, fps, loop);
				if (idleAnim == null) {
					idleAnim = anim;
					animation.play(anim);
				}
			}
		} else {
			if (image != null) {
				loadGraphic(Paths.image(image));
			}
			active = false;
		}
		scrollFactor.set(scrollX, scrollY);
		antialiasing = ClientPrefs.globalAntialiasing;
	}

	public function pixelSetup(adjustPos:Bool = true) {
		if (adjustPos) {
			x *= PlayState.daPixelZoom;
			y *= PlayState.daPixelZoom;
			originalPosition.x *= PlayState.daPixelZoom;
			originalPosition.y *= PlayState.daPixelZoom;
		}
		scale.set(PlayState.daPixelZoom, PlayState.daPixelZoom);
		updateHitbox();
		antialiasing = false;
		snapToPixelGrid = true;
		pixelSize = Std.int(PlayState.daPixelZoom);
	}

	public function dance(?forceplay:Bool = false) {
		if (idleAnim != null) {
			animation.play(idleAnim, forceplay);
		}
	}
}