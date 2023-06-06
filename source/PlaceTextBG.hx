package;

import lime.math.Rectangle;
import flixel.text.FlxText;
import flixel.math.FlxPoint;
import flash.filters.DropShadowFilter;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxFilterFrames;
import flixel.group.FlxSpriteGroup.FlxSpriteGroup;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import TextHelper;

using StringTools;

class PlaceTextBG extends FlxSprite {

	public var rectWidth:Int;
	public var rectHeight:Int;
	public var radius:Int;

	var uhhh:FlxFilterFrames;

	var _regen:Bool = true;

	// 5 is offset, 90 points offset down, black is shadow color, .25 is opacity, 10 is blur amount
	var dropShadow:DropShadowFilter = new DropShadowFilter(5, 90, FlxColor.BLACK, .25, 10, 10);

	public function new(x:Int = 0, y:Int = 0, w:Int = 195, h:Int = 30, r:Int = 16) {
		super(x, y);
		rectWidth = w;
		rectHeight = h;
		radius = r;
		antialiasing = ClientPrefs.globalAntialiasing;
		scrollFactor.set();
	}

	public function rebuildGraphic():Void {
		if (!_regen) {
			return;
		}

		var key:String = FlxG.bitmap.getUniqueKey("placebg");
		makeGraphic(rectWidth, rectHeight, FlxColor.TRANSPARENT, false, key);
		FlxSpriteUtil.drawRoundRect(this, 0, 0, rectWidth, rectHeight, radius * 2, radius * 2);

		offset.x = 0;
		offset.y = 0;

		if (uhhh != null) {
			uhhh.destroy();
		}
		// @Square789: This takes around 2ms on a relatively okay PC and that is certainly not okay
		// Who knows how to do it better though, cause I don't
		// @CoolingTool: the `widthInc` and `heightInc` parameters are horrendously hard coded to
		// barely fit the drop shadow. If the drop shadows blur or offset is ever changed good luck
		// adjusting this.
		uhhh = FlxFilterFrames.fromFrames(frames, 38, 34, [dropShadow]);
		uhhh.applyToSprite(this);

		_regen = false;
	}

	override public function draw():Void {
		rebuildGraphic();
		super.draw();
	}
}

class AttachedPlaceTextBG extends PlaceTextBG
{
	public var sprTracker:FlxText;
	public var xAdd:Float = 0;
	public var yAdd:Float = 0;
	public var wAdd:Int = 56;

	public var centerOffset:Bool = true;
	public var copyScale:Bool = false;
	public var copyWidth:Bool = false;

	public function new(?w:Int, ?h:Int, ?r:Int) {
		super(0, 0, w, h, r);
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (sprTracker == null)
			return;

		var spr = alignmentBounds(sprTracker);

		if (copyWidth) {
			var newRectWidth = Std.int(spr.width + wAdd);
			if (rectWidth != newRectWidth) {
				rectWidth = newRectWidth;
				_regen = true;
			}
		}

		if (copyScale) {
			scale.set(sprTracker.scale.x, sprTracker.scale.y);
		}

		var offx:Float = spr.x + xAdd;
		var offy:Float = spr.y + yAdd;
		if (centerOffset) {
			offx += spr.width / 2 - rectWidth / 2; 
			offy += spr.height / 2 - rectHeight / 2;
		}
		setPosition(offx, offy);
	}
}

// High preformant version of classes above that use static images instead of drawing and rendering
// the drop shadow at runtime. Since this uses images, you can't change the height or radius size.
// If you need to do stuff like that, for example in some place like the options menu for option
// descriptions, then use `PlaceTextBG` and  `AttachedPlaceTextBG`
class CheapPlaceTextBG extends FlxSpriteGroup {
	var left:FlxSprite;
	var mid:FlxSprite;
	var right:FlxSprite;

	// the sizes of the shadows 
	final topShadow = 4;
	final eachSideShadow = 8;

	public var rectWidth:Int;
	public final rectHeight:Int = 30;
	public var rectScale:FlxPoint = new FlxPoint(1, 1);

	public function new(x:Int = 0, y:Int = 0, w:Int = 195) {
		super(x, y, 3);
		rectWidth = w;

		left = new FlxSprite(0, -topShadow, Paths.image('placeHud/bg_side'));
		left.flipX = true;
		left.antialiasing = ClientPrefs.globalAntialiasing;
		left.scrollFactor.set();
		add(left);

		mid = new FlxSprite(0, -topShadow, Paths.image('placeHud/bg_mid'));
		mid.antialiasing = ClientPrefs.globalAntialiasing;
		mid.scrollFactor.set();
		add(mid);

		right = new FlxSprite(0, -topShadow, Paths.image('placeHud/bg_side'));
		right.antialiasing = ClientPrefs.globalAntialiasing;
		right.scrollFactor.set();
		add(right);

		positionGraphic();
	}

	// @CoolingTool: What even is this lmao
	public function positionGraphic():Void {
		var _width = (rectWidth + (eachSideShadow * 2));

		mid.scale.set(_width - (left.frameWidth + right.frameWidth), 1);
		mid.updateHitbox();
		mid.scale.set(mid.scale.x * rectScale.x, rectScale.y);
		
		left.scale.set(rectScale.x, rectScale.y);
		left.updateHitbox();
		left.offset.y = mid.offset.y;

		right.scale.set(rectScale.x, rectScale.y);
		right.updateHitbox();
		right.offset.y = mid.offset.y;

		// adding one is required to make it actually centered ¯\_(ツ)_/¯
		mid.x = x + left.frameWidth - eachSideShadow + 1;
		left.x = (x + _width / 2) - (Math.abs(mid.scale.x) / 2) - left.width - eachSideShadow + 1;
		right.x = (x + _width / 2) + (Math.abs(mid.scale.x) / 2) - eachSideShadow + 1;
	}
}

class AttachedCheapPlaceTextBG extends CheapPlaceTextBG {
	public var sprTracker:FlxText;
	public var xAdd:Float = 0;
	public var yAdd:Float = 0;
	public var wAdd:Int = 56;

	public var centerOffset:Bool = true;
	public var copyScale:Bool = false;
	public var copyWidth:Bool = false;

	public function new(?w:Int) {
		super(0, 0, w);
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		var refresh:Bool = false;

		if (sprTracker == null)
			return;

		var spr = alignmentBounds(sprTracker);

		if (copyWidth) {
			var newRectWidth = Std.int(spr.width + wAdd);
			if (rectWidth != newRectWidth) {
				rectWidth = newRectWidth;
			}
			refresh = true;
		}
		
		if (copyScale) {
			rectScale.set(sprTracker.scale.x, sprTracker.scale.y);
			refresh = true;
		}

		var offx:Float = spr.x + xAdd;
		var offy:Float = spr.y + yAdd;
		if (centerOffset) {
			offx += spr.width / 2 - rectWidth / 2; 
			offy += spr.height / 2 - rectHeight / 2;
		}

		if (offx != x) {
			x = offx;
			refresh = true;
		}
		if (offy != y) {
			y = offy;
			refresh = true;
		}

		if (refresh) positionGraphic();
	}
}