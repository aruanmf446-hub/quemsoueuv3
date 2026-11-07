shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform sampler2D water_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 world_position;

float hash_water(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float water_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_water(cell), hash_water(cell + vec2(1.0, 0.0)), f.x),
		mix(hash_water(cell + vec2(0.0, 1.0)), hash_water(cell + vec2(1.0)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	vec2 drift = vec2(TIME * 0.055, -TIME * 0.025);
	float broad = water_noise(p * vec2(0.48, 0.72) + drift);
	float detail = water_noise(p * 1.75 - drift * 1.3);
	float undulation = sin(p.x * 1.5 + p.y * 1.8 + broad * 3.5 - TIME * 0.45);
	float shore_distance = min(abs(p.y + 6.7), abs(p.y + 18.6));
	float shallow = 1.0 - smoothstep(0.15, 2.8, shore_distance + (broad - 0.5) * 0.55);
	vec3 deep_color = vec3(0.055, 0.180, 0.230);
	vec3 clear_color = vec3(0.105, 0.340, 0.370);
	vec3 water = mix(deep_color, clear_color, shallow * 0.55 + broad * 0.35);
	water += vec3(0.020, 0.045, 0.050) * undulation;
	// Dois fluxos suaves quebram a repetição do detalhe, sem refração de tela ou SSR.
	vec2 warp = vec2(broad, detail) * 0.012;
	vec3 layer_a = texture(water_detail, p * vec2(0.045, 0.015) + vec2(TIME * 0.008, TIME * 0.003) + warp).rgb;
	vec3 layer_b = texture(water_detail, p * vec2(-0.039, 0.018) + vec2(0.33, 0.71) + vec2(-TIME * 0.004, TIME * 0.002) - warp).rgb;
	vec3 surface_detail = mix(layer_a, layer_b, 0.32);
	water = mix(water, surface_detail * 0.90 + vec3(0.01, 0.035, 0.04), 0.72);
	float moon_path = pow(max(0.0, sin(p.x * 0.18 + p.y * 0.09 + broad * 0.6)), 6.0);
	float glint = clamp((surface_detail.g + surface_detail.b) * 1.1 - 0.10, 0.0, 1.0);
	water += vec3(0.035, 0.060, 0.075) * glint * (0.2 + moon_path * 0.35);
	float shore_ripple = exp(-shore_distance * 3.5) * smoothstep(0.48, 0.78, detail);
	water = mix(water, vec3(0.19, 0.36, 0.34), shore_ripple * 0.35);
	ALBEDO = water;
}
