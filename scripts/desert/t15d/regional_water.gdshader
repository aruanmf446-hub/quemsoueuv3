shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

void fragment() {
	float ripple = sin(UV.x * 6.0 + sin(UV.y * 4.0) * 0.8 - TIME * 0.6);
	float reflected = pow(max(0.0, sin(UV.y * 22.0 + ripple * 0.65 - TIME * 0.45)), 10.0);
	ALBEDO = mix(vec3(0.045, 0.14, 0.18), vec3(0.10, 0.25, 0.28), ripple * 0.5 + 0.5);
	ALBEDO += reflected * vec3(0.08, 0.11, 0.10);
}
