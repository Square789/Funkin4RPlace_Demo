package;

import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxColor;


class RoundedCornerShader extends FlxShader {
	@:glFragmentSource('
		#pragma header

		uniform float radius;
		uniform float inner_border_width;
		uniform vec3 inner_border_color;

		// Wouldn\'t be here without the following:
		// https://www.shadertoy.com/view/7tsXRN

		void main() {
			vec2 position = openfl_TextureCoordv * openfl_TextureSize;
			vec2 center = openfl_TextureSize / 2.0;

			// Don\'t ask me what "dist" means, i don\'t really know what kind of
			// distance i have to imagine there. Well, i kinda do know it\'s the distance
			// of a virtual circle that somehow comes to be by these abs and center
			// subtractions which is only considered in one direction by the max, but
			// i actually am too smoothbrained to wrap my head around it. Oh well.
			float dist = length(max(
				abs(position - center) - center + vec2(radius),
				vec2(0.0, 0.0)
			)) - radius;

			float alpha;
			vec3 color;
			if (dist > 0.0) {
				// Outside of rounded border.
				alpha = 1.0 - smoothstep(0.0, 1.0, dist + 0.5);
				color = flixel_texture2D(bitmap, openfl_TextureCoordv).rgb;
			} else { // if (dist > -inner_border_width)
				// Inside. We may be on the border, so mix the border color with the texture\'s color.
				float true_color_weight = 1.0 - smoothstep(0.0, 1.0, dist + inner_border_width + 0.5);
				vec3 res = mix(
					inner_border_color,
					flixel_texture2D(bitmap, openfl_TextureCoordv).rgb,
					true_color_weight
				);

				alpha = flixel_texture2D(bitmap, openfl_TextureCoordv).a;
				color = res.rgb;
			}

			gl_FragColor = vec4(color * alpha, alpha);
		}
	')

	public function new(radius:Float, innerBorderWidth:Float = 0.0, innerBorderColor:FlxColor = 0xFF000000) {
		super();
		this.radius.value = [radius];
		this.inner_border_width.value = [innerBorderWidth];
		this.inner_border_color.value = [
			innerBorderColor.redFloat, innerBorderColor.greenFloat, innerBorderColor.blueFloat
		];
	}
}

// I can't help but think this is a really disgusting way of doing it
class ManualTexSizeRoundedCornerShader extends FlxShader {
	@:glFragmentSource('
		#pragma header

		uniform float radius;
		uniform vec2 texture_size;
		uniform float inner_border_width;
		uniform vec3 inner_border_color;

		// Wouldn\'t be here without the following:
		// https://www.shadertoy.com/view/7tsXRN

		void main() {
			vec2 position = openfl_TextureCoordv * texture_size;
			vec2 center = texture_size / 2.0;

			// Don\'t ask me what "dist" means, i don\'t really know what kind of
			// distance i have to imagine there. Well, i kinda do know it\'s the distance
			// of a virtual circle that somehow comes to be by these abs and center
			// subtractions which is only considered in one direction by the max, but
			// i actually am too smoothbrained to wrap my head around it. Oh well.
			float dist = length(max(
				abs(position - center) - center + vec2(radius),
				vec2(0.0, 0.0)
			)) - radius;

			float alpha;
			vec3 color;
			if (dist > 0.0) {
				// Outside of rounded border.
				alpha = 1.0 - smoothstep(0.0, 1.0, dist + 0.5);
				color = flixel_texture2D(bitmap, openfl_TextureCoordv).rgb;
			} else { // if (dist > -inner_border_width)
				// Inside. We may be on the border, so mix the border color with the texture\'s color.
				float true_color_weight = 1.0 - smoothstep(0.0, 1.0, dist + inner_border_width + 0.5);
				vec3 res = mix(
					inner_border_color,
					flixel_texture2D(bitmap, openfl_TextureCoordv).rgb,
					true_color_weight
				);

				alpha = flixel_texture2D(bitmap, openfl_TextureCoordv).a;
				color = res.rgb;
			}

			gl_FragColor = vec4(color * alpha, alpha);
		}
	')

	public function new(
		radius:Float,
		texSizeW:Float = 1.0,
		texSizeH:Float = 1.0,
		innerBorderWidth:Float = 0.0,
		innerBorderColor:FlxColor = 0xFF000000
	) {
		super();
		this.radius.value = [radius];
		this.texture_size.value = [texSizeW, texSizeH];
		this.inner_border_width.value = [innerBorderWidth];
		this.inner_border_color.value = [
			innerBorderColor.redFloat, innerBorderColor.greenFloat, innerBorderColor.blueFloat
		];
	}
}
