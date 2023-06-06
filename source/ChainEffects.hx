//
// Contains all sort of effects and utilities to chain them into runtime-generated shaders.
// Pretty cheap and could be improved in a myriad of ways
//

import haxe.ValueException;
import flixel.util.FlxColor;
import openfl.display.BitmapData;
import openfl.display.ShaderInput;

using ChainEffects._ChainEffectUniformTypeInformer;


// Blatantly stolen from
// https://stackoverflow.com/questions/47376499/creating-a-gradient-color-in-fragment-shader
private function flxColorArrayToRampTextureConverter(colors:Array<FlxColor>):BitmapData {
	if (colors.length == 0) {
		throw new ValueException("Need at least one color for this.");
	}
	var data = new BitmapData(colors.length, 1, true);
	for (i => color in colors) {
		data.setPixel(i, 0, color);
	}
	return data;
}

// Wow big fan of the enum-and-static-extension-hiding-switch-cases-or-maps-for-the-enum pattern
enum _ChainEffectUniformType { FLOAT; BOOL; SAMPLER2D; VEC2; VEC3; VEC4; }
private class _ChainEffectUniformTypeInformer {
	public static function getGlslTypeName(x:_ChainEffectUniformType):String {
		return switch (x) {
			case FLOAT:     "float";
			case BOOL:      "bool";
			case SAMPLER2D: "sampler2D";
			case VEC2:      "vec2";
			case VEC3:      "vec3";
			case VEC4:      "vec4";
		}
	}

	public static function getComponentCount(x:_ChainEffectUniformType):Int {
		return switch (x) {
		case FLOAT | BOOL : 1;
		case VEC2:          2;
		case VEC3:          3;
		case VEC4:          4;
		case _:            -1;
		}
	}

	private static function castDynamicFloatToString(v:Dynamic):String {
		var str = Std.string(cast(v, Float));
		if (str.indexOf('.') == -1) {
			str += ".0";
		}
		return str;
	}

	public static function canBeHardcoded(x:_ChainEffectUniformType):Bool {
		return switch (x) { case SAMPLER2D: false; case _: true; }
	}

	public static function asConstant(x:_ChainEffectUniformType, v:Dynamic):String {
		switch (x) {
		case FLOAT:
			return castDynamicFloatToString(v);
		case BOOL:
			return cast(v, Bool) ? "true" : "false";
		case SAMPLER2D:
			throw new ValueException("Can not create a constant sampler!");
		case VEC2 | VEC3 | VEC4:
			var dyn:Array<Dynamic> = cast(v, Array<Dynamic>);
			if (dyn.length != x.getComponentCount()) {
				throw new ValueException('Bad array length ${dyn.length} for $x!');
			}
			return x.getGlslTypeName() + "(" + dyn.map(castDynamicFloatToString).join(", ") + ")";
		}
		return "";
	}
}

typedef UniformBlob = {
	var type:_ChainEffectUniformType;
	var name:String;
	var global:Bool;
	var ?optionsFieldName:Null<String>;
	var ?optionToShaderInputConverter:Null<Dynamic->Dynamic>;
};

class EffectMeta {
	public static final ABERRATION_GLITCH = new EffectMeta(
		"
			vec4 <<<name>>>(vec2 uv) {
				// Stole this from shadertoy. Effectively, multiply sin together a bunch and you end up with something
				// thats unpredictable enough.
				float sidestep;
				if (<<<go_negative>>>) { // Between -1 and 1.
					sidestep = (
						sin(time *  4.20) *
						sin(time * 13.37) *
						sin(time *  6.9 ) *
						sin(time * 21.0 )
					);
				} else { // Between 0 and 1.
					sidestep = (
						(.5 * (1.0 + sin(time *  4.20))) *
						(.5 * (1.0 + sin(time * 13.37))) *
						(.5 * (1.0 + sin(time *  6.9 ))) *
						(.5 * (1.0 + sin(time * 21.0 )))
					);
				}
				sidestep = (
					(<<<base_intensity>>> + (sidestep * <<<intensity_variance>>>)) /
					openfl_TextureSize.x
				);

				vec4 res;
				res.r =   <<<prev_pass|||vec2(uv.x + sidestep, uv.y)>>>.r;
				res.gba = <<<prev_pass|||vec2(uv.x, uv.y)>>>.gba;
				return res;
			}
		",
		"aberration",
		[
			{type: _ChainEffectUniformType.FLOAT, name: "time", global: true},
			{type: _ChainEffectUniformType.FLOAT, name: "base_intensity", optionsFieldName: "baseIntensity", global: false},
			{type: _ChainEffectUniformType.FLOAT, name: "intensity_variance", optionsFieldName: "intensityVariance", global: false},
			{type: _ChainEffectUniformType.BOOL, name: "go_negative", optionsFieldName: "goNegative", global: false},
		],
		0
	);
	public static final HUE_SHIFT = new EffectMeta(
		"
			#define TWO_PI 6.283185307179586

			// Stolen from comments of:
			// https://gist.github.com/mairod/a75e7b44f68110e1576d77419d608786
			vec3 imp_hue_shift(vec3 color, float hue) {
				const vec3 k = vec3(0.57735, 0.57735, 0.57735);
				float cos_angle = cos(hue);
				return vec3(
					color             * cos_angle +
					cross(k, color)   * sin(hue) +
					k * dot(k, color) * (1.0 - cos_angle)
				);
			}

			vec4 <<<name>>>(vec2 uv) {
				vec4 full_color = <<<prev_pass|||uv>>>;
				return vec4(imp_hue_shift(full_color.rgb, time * <<<cycle_speed>>> * TWO_PI), full_color.a);
			}
		",
		"hue_shift",
		[
			{type: _ChainEffectUniformType.FLOAT, name: "time", global: true},
			{type: _ChainEffectUniformType.FLOAT, name: "cycle_speed", optionsFieldName: "cycleSpeed", global: false},
		],
		1
	);
	public static final SCROLL = new EffectMeta(
		"
			vec4 <<<name>>>(vec2 uv) {
				vec2 shift = (time * (vec2(1,1)/openfl_TextureSize) * <<<speed>>>);
				vec2 shifted_uv = vec2(1.0, 1.0);

				// If the uv coord is 1.0 and we add a non-fractional i.e. exactly-whole-texture
				// value (seriously unlikely), the fract would cause it to become 0.0, which seems undesirable.
				// They may also be added together to become 1.0 though, idk what to do then, like, what's the
				// big difference to 0.0? It is kinda irritating that apparently 0.0 and 1.0 are both valid.
				if (uv.x != 1.0 || fract(shift.x) != 0.0) {
					shifted_uv.x = fract(uv.x + fract(shift.x));
				}
				if (uv.y != 1.0 || fract(shift.y) != 0.0) {
					shifted_uv.y = fract(uv.y + fract(shift.y));
				}

				return <<<prev_pass|||shifted_uv>>>;
			}
		",
		"infinite_scroll",
		[
			{type: _ChainEffectUniformType.FLOAT, name: "time", global: true},
			{type: _ChainEffectUniformType.VEC2, name: "speed", global: false},
		],
		2
	);
	public static final H_GRADIENT:EffectMeta = new EffectMeta(
		// EpicGamer from the Haxe discord is the sole reason this thing is functional!
		// Thank you.
		"
			vec4 <<<name>>>(vec2 uv) {
				float a = <<<prev_pass|||uv>>>.a;
				vec3 col = texture2D(
					<<<ramp_texture>>>,
					vec2((uv.x * (<<<ramp_texture_width>>> - 1.0) + 0.5) / <<<ramp_texture_width>>>, 0.5)
				).rgb;
				return vec4(col * a, a);
			}
		",
		"h_gradient",
		[
			{
				type: _ChainEffectUniformType.SAMPLER2D,
				name: "ramp_texture",
				optionsFieldName: "colors",
				optionToShaderInputConverter: flxColorArrayToRampTextureConverter,
				global: false, // never specify those as global probably
			},
			{
				type: _ChainEffectUniformType.FLOAT,
				name: "ramp_texture_width",
				optionsFieldName: "colors",
				optionToShaderInputConverter: (colors:Array<FlxColor>) -> (colors.length * 1.0),
				global: false,
			},
		],
		3
	);

	public var fragSource(default, null):String;
	public var name(default, null):String;
	public var uniforms(default, null):Array<UniformBlob>;
	public var effectId(default, null):Int;

	private function new(fragSource:String, name:String, uniforms:Array<UniformBlob>, effectId:Int) {
		this.fragSource = fragSource;
		this.name = name;
		for (uniform in uniforms) {
			if (uniform.optionsFieldName == null) {
				uniform.optionsFieldName = uniform.name;
			}
		}
		this.uniforms = uniforms;
		this.effectId = effectId;
	}
}

abstract class ChainEffect {
	public abstract function getOptionsStruct():Dynamic;
	public var meta(get, never):EffectMeta;
	public abstract function get_meta():EffectMeta;
}

typedef ScrollEffectOptions = {
	var speed:Array<Float>;
}
final class ScrollEffect extends ChainEffect {
	private var options:ScrollEffectOptions;

	public function new(?options:Null<ScrollEffectOptions>) {
		if (options == null) {
			this.options = {speed: [64.0, 64.0]};
		} else {
			if (options.speed.length != 2) {
				throw new ValueException(
					"Two floats. No more. No less. Two shalt be the number of passed floats. Four is right out."
				);
			}
			this.options = options;
		}
	}
	public function getOptionsStruct():Dynamic { return options; }
	public function get_meta():EffectMeta { return EffectMeta.SCROLL; }
}

typedef HueShiftEffectOptions = {
	var cycleSpeed:Float;
}
final class HueShiftEffect extends ChainEffect {
	private var options:HueShiftEffectOptions;

	public function new(?options:Null<HueShiftEffectOptions>) {
		this.options = options ?? {cycleSpeed: 4.0};
	}
	public function getOptionsStruct():Dynamic { return options; }
	public function get_meta():EffectMeta { return EffectMeta.HUE_SHIFT; }
}

typedef AberrationGlitchEffectOptions = {
	var baseIntensity:Float;
	var intensityVariance:Float;
	var goNegative:Bool;
}
final class AberrationGlitchEffect extends ChainEffect {
	private var options:AberrationGlitchEffectOptions;

	public function new(?options:Null<AberrationGlitchEffectOptions>) {
		this.options = options ?? {baseIntensity: 4.0, intensityVariance: 4.0, goNegative: false};
	}
	public function getOptionsStruct():Dynamic { return options; }
	public function get_meta():EffectMeta { return EffectMeta.ABERRATION_GLITCH; }
}

typedef HGradientEffectOptions = {
	colors:Array<FlxColor>
}
final class HGradientEffect extends ChainEffect {
	private var options:HGradientEffectOptions;

	public function new(options:HGradientEffectOptions) {
		this.options = options;
	}
	public function getOptionsStruct():Dynamic { return options; }
	public function get_meta():EffectMeta { return EffectMeta.H_GRADIENT; }
}


class ChainEffectShaderGenerator {
	static private function substitute(what:String, with:String, in_:String):String {
		// Extremely cheap regex substitution mechanism, can't be bothered to escape stuff again
		var subEx = new EReg('<<<${EReg.escape(what)}(|\\|\\|\\|.*?)>>>', "g");
		return subEx.map(
			in_,
			(reg) -> {
				var parts:Array<String> = reg.matched(1).split("|||");
				if (parts.length == 1 && parts[0] == "") {
					parts = [];
				}
				var groupEx = ~/<<<(\d*)>>>/g;
				return groupEx.map(
					with,
					(greg) -> {
						var idx = Std.parseInt(greg.matched(1));
						return parts[idx] == null ? "" : parts[idx];
					}
				);
			}
		);
	}

	private function buildCacheKey(effects:Array<ChainEffect>):Int {
		// This limits us to no more than 16 text effects in general and no more than
		// 8 distinct ones on a single call, which realistically will not happen.
		var cacheKey:haxe.Int32 = 0;
		for (i => e in effects) {
			if (i >= 8) {
				break;
			}
			cacheKey |= (e.meta.effectId & 0xF) << (i * 4);
		}
		return cacheKey;
	}

	/**
	 * Creates a shader whose effect options are hardcoded in.
	 */
	public static function getHardcoded(effects:Array<ChainEffect>):RuntimeShader {
		var rts = new RuntimeShader(buildFragmentSource(effects, true));
		setNonHardcodableUniforms(rts, effects);
		return rts;
	}

	/**
	 * Sets uniforms that can not be hardcoded (just samplers, realistically,) to their appropiate values.
	 * Function only necessary for when you create shaders by building the source seperately instead of
	 * using `getHardcoded`. `getHardcoded` calls into this on its own already.
	 */
	public static function setNonHardcodableUniforms(shader:RuntimeShader, effects:Array<ChainEffect>) {
		for (effect in effects) {
			var options:Dynamic = effect.getOptionsStruct();
			for (uniform in effect.meta.uniforms) {
				if (uniform.type.canBeHardcoded() || uniform.global) {
					continue;
				}
				var uniformValue:Dynamic = Reflect.field(options, uniform.optionsFieldName);
				if (uniform.optionToShaderInputConverter != null) {
					uniformValue = uniform.optionToShaderInputConverter(uniformValue);
				}
				if (uniform.type == SAMPLER2D) {
					setSampler(shader, scrambleUniformName(effect, uniform), uniformValue);
				}
			}
		}
	}

	/**
	 * Returns a shader for the given effects.
	 * The effects are preprocessed. Duplicate effects types are discarded.
	 * If `applyOptions` is given, the options from the effects will be written right into the shader uniforms.
	 */
	public static function get(effects:Array<ChainEffect>, applyOptions:Bool = true) {
		var rts = new RuntimeShader(buildFragmentSource(effects, false), null);
		if (!applyOptions) {
			return rts;
		}

		for (effect in effects) {
			var options:Dynamic = effect.getOptionsStruct();

			for (uniform in effect.meta.uniforms) {
				if (uniform.global) {
					continue;
				}

				var uniformName = scrambleUniformName(effect, uniform);
				var uniformValue:Dynamic = Reflect.field(options, uniform.optionsFieldName);
				if (uniform.optionToShaderInputConverter != null) {
					uniformValue = uniform.optionToShaderInputConverter(uniformValue);
				}

				switch (uniform.type) {
				case FLOAT:
					rts.setFloat(uniformName, cast(uniformValue, Float));
				case BOOL:
					rts.setBool(uniformName, cast(uniformValue, Bool));
				case VEC2 | VEC3 | VEC4:
					var arr = cast(uniformValue, Array<Dynamic>);
					if (arr.length != uniform.type.getComponentCount()) {
						throw new ValueException('invalid float array length for ${uniform.type}');
					}
					rts.setFloatArray(uniformName, [for (x in arr) cast(x, Float)]);
				case SAMPLER2D:
					setSampler(rts, uniformName, cast(uniformValue, BitmapData));
				}
			}
		}

		return rts;
	}

	/**
	 * Creates the source string for a fragment shader from the given effects.
	 * Effects must be unique, duplicates will produce a broken source.
	 * Set hardcodeUniforms to hardcode in each effect's uniform values. Good for when they won't
	 * ever change to get like 0.02% improved memory usage and runtime.
	 */
	public static function buildFragmentSource(uniqueEffects:Array<ChainEffect>, hardcodeUniforms:Bool):String {
		var fragSource:Array<String> = [];
		var uniforms:Array<{s:ChainEffect, b:UniformBlob}> = [];
		var knownUniformNames:Array<String> = [];
		var previousFunction:Null<String> = null;

		for (effect in uniqueEffects) {
			var effUniforms = effect.meta.uniforms;
			if (effUniforms == null) {
				continue;
			}

			var processedFragSource = substitute("name", effect.meta.name, effect.meta.fragSource);
			for (u in effUniforms) {
				if (u.global && knownUniformNames.contains(u.name)) {
					continue;
				}
				if (hardcodeUniforms && shouldHardcode(u)) {
					var uniformVal:Dynamic = Reflect.field(effect.getOptionsStruct(), u.optionsFieldName);
					if (u.optionToShaderInputConverter != null) {
						uniformVal = u.optionToShaderInputConverter(uniformVal);
					}
					processedFragSource = substitute(u.name, u.type.asConstant(uniformVal), processedFragSource);
				} else {
					processedFragSource = substitute(u.name, scrambleUniformName(effect, u), processedFragSource);
				}
				uniforms.push({s: effect, b: u});
				knownUniformNames.push(u.name);
			}

			processedFragSource = substitute(
				"prev_pass",
				(previousFunction == null) ? "flixel_texture2D(bitmap, <<<1>>>)" : '$previousFunction(<<<1>>>)',
				processedFragSource
			);
			
			previousFunction = effect.meta.name;
			fragSource.push(processedFragSource);
		}

		if (previousFunction != null) {
			fragSource.push('void main() { gl_FragColor = ${previousFunction}(openfl_TextureCoordv); }\n');
		} else {
			fragSource.push("void main() { gl_FragColor = flixel_texture2D(bitmap, openfl_TextureCoordv); }\n");
		}

		fragSource.unshift(
			"#pragma header\n\n" +
			// Excludes all uniforms that have been successfully hardcoded in:
			uniforms.filter((s) -> !(hardcodeUniforms && shouldHardcode(s.b))).map(
				(s) -> 'uniform ${s.b.type.getGlslTypeName()} ${scrambleUniformName(s.s, s.b)};'
			).join("\n") +
			"\n\n"
		);
		return fragSource.join("");
	}

	private static function scrambleUniformName(effect:ChainEffect, uniform:UniformBlob):String {
		return (uniform.global ? '' : '${effect.meta.name}_') + uniform.name;
	}

	private static function shouldHardcode(uniform:UniformBlob):Bool {
		return !uniform.global && uniform.type.canBeHardcoded();
	}

	private static function setSampler(shader:RuntimeShader, name:String, value:BitmapData) {
		var x:ShaderInput<BitmapData> = Reflect.field(shader.data, name);
		x.input = value;
		// @Square789: Yeah, we hardcode this filter mode here. Problem?
		x.filter = LINEAR;
	}
}
