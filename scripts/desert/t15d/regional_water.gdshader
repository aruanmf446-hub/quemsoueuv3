shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform sampler2D water_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool falling = false;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Coordenadas mundiais mantêm o fluxo contínuo entre as peças do canal.
	vec2 p = world_position.xz;
	vec2 flow_a = p * vec2(0.045, 0.024) + vec2(-TIME * 0.009, TIME * 0.002);
	vec2 flow_b = p * vec2(-0.033, 0.031) + vec2(0.31, 0.67) + vec2(TIME * 0.004, -TIME * 0.003);
	if (falling) {
		// As quedas compartilham a textura; o movimento segue a gravidade.
		p = world_position.xy;
		flow_a = p * vec2(0.12, 0.06) + vec2(0.0, TIME * 0.12);
		flow_b = p * vec2(-0.09, 0.05) + vec2(0.31, 0.67) + vec2(0.0, TIME * 0.08);
	}
	vec3 detail = mix(texture(water_detail, flow_a).rgb, texture(water_detail, flow_b).rgb, 0.38);
	float ripple = sin(p.x * 1.2 + p.y * 1.7 + detail.g * 4.0 - TIME * 0.55);
	float bank_distance = min(abs(world_position.z + 6.7), abs(world_position.z + 16.0));
	float edge = 1.0 - smoothstep(0.0, 1.4, bank_distance);
	vec3 water = mix(vec3(0.035, 0.12, 0.17), vec3(0.065, 0.23, 0.27), edge * 0.55 + ripple * 0.09 + 0.18);
	water = mix(water, detail * vec3(0.72, 0.88, 1.0), 0.65);
	// Reflexo contido: o canal não vira uma faixa luminosa junto ao piso.
	water += vec3(0.012, 0.022, 0.028) * smoothstep(0.16, 0.34, detail.b) * (ripple * 0.5 + 0.5);
	if (falling) water = mix(water, vec3(0.17, 0.34, 0.39), smoothstep(0.10, 0.32, detail.g) * 0.42);
	ALBEDO = water;
}
