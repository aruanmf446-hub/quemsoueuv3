shader_type spatial;
render_mode cull_back;
uniform sampler2D rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world;
vec2 mirrored(vec2 uv) { return abs(fract(uv * 0.5) * 2.0 - 1.0); }
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 // World-space square texels: the wide wall never stretches the source sandstone.
 vec2 uv = world.xy * 0.24;
 vec3 fine = texture(rock, mirrored(uv)).rgb;
 vec3 broad = texture(rock, mirrored(vec2(-uv.y, uv.x) * 0.37 + vec2(0.31, 0.67))).rgb;
 float mineral = smoothstep(0.25, 0.7, broad.r);
 vec3 tint = mix(vec3(0.24, 0.27, 0.30), vec3(0.45, 0.39, 0.32), mineral);
 vec3 stone = mix(fine, vec3(dot(fine, vec3(0.3, 0.59, 0.11))), 0.55);
 ALBEDO = stone * tint * 1.1;
 ROUGHNESS = 0.96;
}
