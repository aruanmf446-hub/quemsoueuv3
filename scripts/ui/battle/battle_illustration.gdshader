shader_type canvas_item;
// One texture sample; preserve the original art, add only restrained grading.
uniform float saturation : hint_range(0.0, 1.3) = 1.04;
uniform float contrast : hint_range(0.8, 1.3) = 1.04;
varying vec4 vertex_tint;
void vertex() {
	vertex_tint = COLOR;
}
void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float luminance = dot(art.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 graded = mix(vec3(luminance), art.rgb, saturation);
	graded = clamp((graded - 0.5) * contrast + 0.5, 0.0, 1.0);
	COLOR = vec4(graded, art.a) * vertex_tint;
}
