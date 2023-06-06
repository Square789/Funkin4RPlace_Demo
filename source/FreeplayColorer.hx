package;

import flixel.util.FlxColor;
import flixel.system.FlxAssets.FlxShader;

class FreeplayColorer {
	public var shader(default, null):FreeplayColorerShader = new FreeplayColorerShader();
	public var color(default, set):FlxColor = FlxColor.WHITE;

	private var _color_set_before = false;

	private function set_color(value:FlxColor) {
		color = value;
		var data = [value.red / 255, value.green / 255, value.blue / 255];
		
		if (!_color_set_before) {
			shader.lastColor.value = data;
			_color_set_before = true;
		} else {
			// lerp the color incase the shader didnt finish tweening
			// so theres no sharp cuts to colors
			var tim = Math.min(shader.time.value[0], 1);
			shader.lastColor.value = [
				mix(shader.lastColor.value[0], shader.targetedColor.value[0], tim),
				mix(shader.lastColor.value[1], shader.targetedColor.value[1], tim),
				mix(shader.lastColor.value[2], shader.targetedColor.value[2], tim)
			];
			shader.time.value[0] = 0;
		}

		shader.targetedColor.value = data;
		return color;
	}

	// i know FlxMath.lerp exists i just want this to be as accurate as possible
	inline function mix(x:Float, y:Float, a:Float)
	{
		return x * (1 - a) + y * a;
	}

	public function update(elapsed:Float):Void
	{
		shader.time.value[0] += elapsed * 2;
	}

	public function new()
	{
		shader.time.value = [0];
		shader.targetedColor.value = [1, 1, 1];
		shader.lastColor.value = [1, 1, 1];
	}
}

class FreeplayColorerShader extends FlxShader {
	@:glFragmentSource('
		#pragma header

		uniform float time;
		uniform vec3 targetedColor;
		uniform vec3 lastColor;

		vec4 choose(vec4 base, vec3 color) {
			if (((color.r + color.b + color.g) / 3.0) <= 0.11764705882) {
				//vec4 inverted = vec4(1.0 - base.r, 1.0 - base.g, 1.0 - base.b, base[3]);
				return vec4(
					1.0 - ((base.r) * (1.0 - color.r)),
					1.0 - ((base.g) * (1.0 - color.g)),
					1.0 - ((base.b) * (1.0 - color.b)),
				1);
			} else {
				return vec4(
					base.r * color.r,
					base.g * color.g,
					base.b * color.b,
				1);
			}
		}

		void main()
		{
			vec4 base = flixel_texture2D(bitmap, openfl_TextureCoordv);

			gl_FragColor = choose(base, mix(
				lastColor,
				targetedColor,
				min(time, 1.0)
			));
		}')
	public function new()
	{
		super();
	}
}