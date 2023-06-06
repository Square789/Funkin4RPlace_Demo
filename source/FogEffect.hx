package;

import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.system.FlxAssets.FlxShader;

class FogEffect
{
	public var shader(default, null):FogShader = new FogShader();

	public var color(default, set):FlxColor;
	public var initialAmplitude(default, set):Float;
	public var lacunarity(default, set):Float;
	public var gain(default, set):Float;
	public var zoom(default, set):Float;
	public var offset(default, set):FlxPoint;
	public var scrollFactor(default, set):FlxPoint;
	public var rotation(default, set):Array<Float>;
	public var speed(default, set):Float;

	public function new(color = FlxColor.GRAY, initialAmplitude = 0.5, lacunarity = 2.0, gain = 0.5):Void
	{
		this.color = color;
		this.offset = new FlxPoint();
		this.scrollFactor = new FlxPoint(1, 1);
		this.initialAmplitude = initialAmplitude;
		this.lacunarity = lacunarity;
		this.gain = gain;
		this.rotation = [Math.cos(0.5), Math.sin(0.5), -Math.sin(0.5), Math.cos(0.50)];
		this.zoom = 3;
		this.speed = 0.15;

		shader.time.value = [0];
	}

	public function update(elapsed:Float):Void
	{
		shader.time.value[0] += elapsed;
		shader.offset.value = [offset.x, offset.y];
		shader.scrollFactor.value = [scrollFactor.x, scrollFactor.y];
	}

	public function setValue(value:Float):Void
	{
		shader.time.value[0] = value;
	}

	function set_color(v:FlxColor):FlxColor
	{
		color = v;
		shader.color.value = [color.red / 255, color.green / 255, color.blue / 255];
		return v;
	}

	function set_initialAmplitude(v:Float):Float
	{
		initialAmplitude = v;
		shader.initial_amplitude.value = [initialAmplitude];
		return v;
	}

	function set_lacunarity(v:Float):Float
	{
		lacunarity = v;
		shader.lacunarity.value = [lacunarity];
		return v;
	}

	function set_gain(v:Float):Float
	{
		gain = v;
		shader.gain.value = [gain];
		return v;
	}

	function set_zoom(v:Float):Float
	{
		zoom = v;
		shader.zoom.value = [zoom];
		return v;
	}

	function set_offset(v:FlxPoint):FlxPoint
	{
		offset = v;
		shader.offset.value = [offset.x, offset.y];
		return v;
	}

	function set_scrollFactor(v:FlxPoint):FlxPoint
	{
		scrollFactor = v;
		shader.scrollFactor.value = [scrollFactor.x, scrollFactor.y];
		return v;
	}

	function set_rotation(v:Array<Float>):Array<Float>
	{
		rotation = v;
		shader.rotation.value = rotation;
		return v;
	}

	function set_speed(v:Float):Float
	{
		speed = v;
		shader.speed.value = [speed];
		return v;
	}
}

class FogShader extends FlxShader
{
	@:glFragmentSource('
		#pragma header

		// HEAVILLY ADAPTED FROM:
		// https://thebookofshaders.com/13/
		// GO READ IT IT\'S GOOD

		// time
		uniform float time;
		
		// fog color (the more black the more transparent)
		uniform vec3 color;

		// the initial amplitude (gets modifed by gain each octave)
		uniform float initial_amplitude;

		// rotation to reduce axial bias
		uniform mat2 rotation;

		// lacunarity
		uniform float lacunarity;

		// gain
		uniform float gain;
		
		// multiplies time
		uniform float speed;

		// how zoomed out
		uniform float zoom;

		// offset
		uniform vec2 offset;

		// paralax
		uniform vec2 scrollFactor;

		// Yoinked from:
		// http://byteblacksmith.com/improvements-to-the-canonical-one-liner-glsl-rand-for-opengl-es-2-0
		// Had to be modified to not make whatever version of OpenGL this is complain.
		// This thing isn\'t really random at all or its randomness depends on some weird behavior of
		// the GPU, but whatever.

		// Will return a random value between 0.0 and 1.0, end-exclusive.
		float random2D(in vec2 _st) {
			return fract(sin(dot(_st.xy,vec2(12.9898,78.233)))*43758.5453123);
		}

		float noise(vec2 coord){
			vec2 i = floor(coord);
			vec2 f = fract(coord);

			// 4 corners of a rectangle surrounding our point
			float a = random2D(i);
			float b = random2D(i + vec2(1.0, 0.0));
			float c = random2D(i + vec2(0.0, 1.0));
			float d = random2D(i + vec2(1.0, 1.0));

			vec2 cubic = f * f * (3.0 - 2.0 * f);

			return mix(a, b, cubic.x) + (c - a) * cubic.y * (1.0 - cubic.x) + (d - b) * cubic.x * cubic.y;
		}

		#define OCTAVES 4
		float fbm(vec2 coord){
			float value = 0.0;
			float amplitude = initial_amplitude;
			vec2 shift = vec2(100.0);
			for(int i = 0; i < OCTAVES; i++){
				value += amplitude * noise(coord);
				coord = rotation * coord * lacunarity + shift;
				amplitude *= gain;
			}
			return value;
		}

		void main() {
			vec2 uv = (openfl_TextureCoordv/openfl_TextureSize * zoom) + (offset/openfl_TextureSize*scrollFactor);
			uv.x *= openfl_TextureSize.x/openfl_TextureSize.y; // to unstretch the fog

			float q = fbm(uv);
			float r = fbm(uv + q + vec2(1.7,9.2)+ speed*time);
			float f = fbm(uv+r);

			vec3 outColor = mix(color * clamp(q,0.0,1.0), color, clamp(r,0.0,1.0));

			gl_FragColor = flixel_texture2D(bitmap, openfl_TextureCoordv) + vec4((f*f*f+.6*f*f+.5*f)*outColor, 0.0);
		}')
	public function new()
	{
		super();
	}
}