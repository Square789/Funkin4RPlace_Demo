package;

import SkinData;
import FunkinLua.ModchartSprite;
import CoolUtil.wrapModuloFloat;
import flixel.FlxCamera;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import openfl.display.BitmapData;
import openfl.geom.ColorTransform;

using StringTools;
using FarpSprite.FlxPointSnap;
using flixel.util.FlxColorTransformUtil;

class FlxPointSnap
{
	public static function align(point:FlxPoint, size:Float):FlxPoint
	{
		point.x = Math.floor(point.x / size) * size;
		point.y = Math.floor(point.y / size) * size;
		return point;
	}

	public static function wrapSubstractPoint(point:FlxPoint, point2:FlxPoint, size:Float):FlxPoint
	{
		// square was right pythons modulo is superior
		point.x -= wrapModuloFloat(point2.x, size);
		point.y -= wrapModuloFloat(point2.y, size);
		return point;
	}

	public static function mod(point:FlxPoint, v:Float):FlxPoint {
		point.x = wrapModuloFloat(point.x, v);
		point.y = wrapModuloFloat(point.y, v);
		return point;
	}

	public static function modNew(point:FlxPoint, v:Float):FlxPoint {
		return point.clone().mod(v);
	}
}

class FarpSprite extends ModchartSprite
{
	public var skin:SkinFileData;

	public var pixelSize:Float = 1;
	public var snapToPixelGrid:Bool = false;
	// @Square789: Currently unused
	public var offsetFix:Bool = true; // this can be very broken so disable if its messing up

	// override public function getScreenPosition(?point:FlxPoint, ?Camera:FlxCamera):FlxPoint
	// {
	// 	if (point == null)
	// 		point = FlxPoint.get();

	// 	if (Camera == null)
	// 		Camera = FlxG.camera;

	// 	point.set(x, y);
	// 	if (snapToPixelGrid) {
	// 		point.align(pixelSize);
	// 	}

	// 	point.subtract(Camera.scroll.x * scrollFactor.x, Camera.scroll.y * scrollFactor.y);

	// 	if (snapToPixelGrid) {
	// 		point.align(pixelSize);
	// 		point.wrapSubstractPoint(Camera.scroll, pixelSize);
	// 		if (offsetFix) {
	// 			// this stuff is weird i dont really get it, but it took so long to get to this point
	// 			// @Square789: from what i can tell, this fixes animation offsets to not screw up the grid
	// 			// alignment again
	// 			// offset.align(pixelSize);
	// 			// point.wrapSubstractPoint(origin, pixelSize);
	// 		}
	// 	}

	// 	return point;
	// }

	// @Square789: NOTE: Override and partially copypaste the drawComplex method to muck with the transform
	// values to get true pixel grid alignment!
	@:noCompletion
	override public function drawComplex(camera:FlxCamera) {
		if (!snapToPixelGrid) {
			return super.drawComplex(camera);
		}

		_frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, checkFlipX(), checkFlipY());
		_matrix.translate(-origin.x, -origin.y);
		_matrix.scale(scale.x, scale.y);

		if (bakedRotationAngle <= 0) {
			updateTrig();
			if (angle != 0) {
				_matrix.rotateWithTrig(_cosAngle, _sinAngle);
			}
		}

		_matrix.translate(origin.x, origin.y);
		// sf of 2  => sfd -camera.scroll
		// sf of 1  => sfd 0
		// sf of .8 => sfd 0.2 * camera.scroll
		// sf of 0  => sfd camera.scroll
		var scrollFactorDisruption = scrollFactor.subtractNew(new FlxPoint(1.0, 1.0)).scale(-1.0).scalePoint(camera.scroll);
		_matrix.translate(x, y);
		_matrix.translate(scrollFactorDisruption.x, scrollFactorDisruption.y);
		_matrix.translate(-offset.x, -offset.y);

		_matrix.tx = Math.floor(_matrix.tx / pixelSize) * pixelSize;
		_matrix.ty = Math.floor(_matrix.ty / pixelSize) * pixelSize;

		_matrix.translate(-camera.scroll.x, -camera.scroll.y);

		camera.drawPixels(_frame, framePixels, _matrix, colorTransform, blend, antialiasing, shader);
	}

	public function loadUISkin(image:String, nscale:Float = 1, ?pscale:Float, type:SkinDataType = UISkin) {
		if (pscale == null)
			pscale = nscale;
		pscale *= PlayState.daPixelZoom;

		skin = SkinData.getSkinFile(type, image);
		loadGraphic(Paths.image(skin.image));

		if (skin.pixel)
			scale.set(pscale, pscale);
		else
			scale.set(nscale, nscale);

		antialiasing = ClientPrefs.globalAntialiasing && !skin.pixel;
		updateHitbox();
		return this;
	}

	public function pixelPerfect() {
		if (skin != null && skin.pixel) {
			snapToPixelGrid = true;
			pixelSize = Std.int((scale.x + scale.y) / 2);
		}
	}

	public var dissolver:PixelErasureShader;

	override function set_alpha(Alpha:Float):Float {
		super.set_alpha(Alpha);
		if (dissolver != null) dissolver.pixel_health.value[0] = alpha;
		return alpha;
	}

	override function updateColorTransform() {
		if (colorTransform == null)
			colorTransform = new ColorTransform();

		useColorTransform = (dissolver == null && alpha != 1) || color != 0xffffff;
		if (useColorTransform)
			colorTransform.setMultipliers(color.redFloat, color.greenFloat, color.blueFloat, dissolver == null ? alpha : 1);
		else
			colorTransform.setMultipliers(1, 1, 1, 1);

		dirty = true;
	}

	public function dissolveAlpha() {
		if (skin != null && skin.pixel && skin.folder.endsWith('place')) {
			dissolver = new PixelErasureShader();
			dissolver.pixel_dimensions.value = [1, 1];
			dissolver.palette.input = new BitmapData(1, 1, true, 0);
			dissolver.pixel_health.value[0] = alpha;
			shader = dissolver;
		}
	}
}