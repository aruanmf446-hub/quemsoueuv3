shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D source_art : source_color, filter_linear_mipmap, repeat_disable;
uniform bool gantry = false;

vec4 over(vec4 front, vec4 back) {
	float alpha = front.a + back.a * (1.0 - front.a);
	return vec4((front.rgb * front.a + back.rgb * back.a * (1.0 - front.a)) / max(alpha, 0.00001), alpha);
}

vec4 brace(vec2 uv, float center, float direction) {
	float distance = (uv.y - 0.657) - (uv.x - center) * 1.60 * direction;
	float across = clamp(distance / 0.075 + 0.5, 0.0, 1.0);
	float along = clamp((uv.x - center + 0.108) / 0.216, 0.0, 1.0);
	vec4 wood = texture(source_art, vec2(0.105 + along * 0.175, 0.848 + across * 0.040));
	wood.a *= 1.0 - smoothstep(0.030, 0.038, abs(distance));
	return wood;
}

// Coordenadas na imagem original: o Sprite3D já resolve os UVs dos AtlasTexture.
// Os vãos vazados continuam transparentes; não se cobre a estrutura com placas.
vec4 bridge_finish(vec2 uv) {
	vec4 art = texture(source_art, uv);
	for (int i = 0; i < 3; i++) {
		float center = 0.204 + float(i) * 0.280;
		if (abs(uv.x - center) < 0.052 && uv.y > 0.435 && uv.y < 0.491) {
			float edge = (1.0 - smoothstep(0.048, 0.052, abs(uv.x - center))) * smoothstep(0.435, 0.442, uv.y);
			art = mix(art, texture(source_art, vec2(0.305, uv.y)), edge);
		}
		if (abs(uv.x - center) < 0.108 && uv.y > 0.478 && uv.y < 0.838) {
			// Travessas contínuas: evita emendas em retângulo onde estava o pano.
			vec4 replacement = over(brace(uv, center, 1.0), brace(uv, center, -1.0));
			float edge = (1.0 - smoothstep(0.099, 0.108, abs(uv.x - center))) * smoothstep(0.478, 0.491, uv.y) * (1.0 - smoothstep(0.831, 0.838, uv.y));
			art = mix(art, replacement, edge);
		}
	}
	return art;
}

vec4 gantry_finish(vec2 uv) {
	vec4 art = texture(source_art, uv);
	// Estandarte e varão do pilar esquerdo: revela a continuação da madeira.
	if (uv.x > 0.076 && uv.x < 0.233 && uv.y > 0.240 && uv.y < 0.590) {
		float grain = abs(fract((uv.y - 0.248) / 0.12) * 2.0 - 1.0);
		vec4 replacement = texture(source_art, vec2(uv.x, 0.590 + grain * 0.06));
		float edge = smoothstep(0.076, 0.082, uv.x) * (1.0 - smoothstep(0.229, 0.233, uv.x)) * smoothstep(0.240, 0.248, uv.y) * (1.0 - smoothstep(0.583, 0.590, uv.y));
		if (uv.y > 0.290) {
			edge *= smoothstep(0.100, 0.105, uv.x) * (1.0 - smoothstep(0.213, 0.218, uv.x));
		}
		art = mix(art, replacement, edge);
	}
	// Pano do carrinho: conserva a frente de tábuas e a forma do veículo.
	if (uv.x > 0.446 && uv.x < 0.564 && uv.y > 0.732 && uv.y < 0.860) {
		vec4 replacement = texture(source_art, vec2(0.571 + (uv.x - 0.505) * 0.14, uv.y));
		float edge = smoothstep(0.446, 0.450, uv.x) * (1.0 - smoothstep(0.560, 0.564, uv.x)) * smoothstep(0.732, 0.736, uv.y) * (1.0 - smoothstep(0.853, 0.860, uv.y));
		art = mix(art, replacement, edge);
	}
	return art;
}

void fragment() {
	vec4 art = gantry ? gantry_finish(UV) : bridge_finish(UV);
	ALBEDO = art.rgb * COLOR.rgb;
	ALPHA = art.a * COLOR.a;
}
