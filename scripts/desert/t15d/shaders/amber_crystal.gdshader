shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float formation : hint_range(0.0, 1.0) = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float stress : hint_range(0.0, 1.0) = 0.0;
uniform float age = 0.0;
varying float height;
void vertex() {
 height = VERTEX.y / 1.90;
}
void fragment() {
 float built = 1.0 - smoothstep(formation, formation + 0.06, height);
 float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.5);
 float edge = COLOR.a;
 float sweep = pow(max(0.0, 1.0 - abs(height - fract(age * 0.32)) * 12.0), 3.0);
 float fissure = (1.0 - smoothstep(0.0, 0.012, abs(UV.x - 0.55 - sin(UV.y * 27.0) * 0.035))) * stress;
 vec3 resin = mix(vec3(0.89, 0.43, 0.055), vec3(1.0, 0.68, 0.22), rim);
 ALBEDO = mix(resin * COLOR.rgb, vec3(0.96, 0.65, 0.27), edge);
 EMISSION = ALBEDO * (0.10 + edge * 0.30 + sweep * 0.20 + fissure * 0.3);
 ALPHA = clamp((0.21 + rim * 0.26 + sweep * 0.06 + fissure * 0.22) * (1.0 - edge) + edge * 0.50, 0.0, 0.85) * opacity * built;
}
