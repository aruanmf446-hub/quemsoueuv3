shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float formation : hint_range(0.0, 1.0) = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float stress : hint_range(0.0, 1.0) = 0.0;
uniform float age = 0.0;
varying float height;
void vertex() { height = VERTEX.y / 1.90; }
void fragment() {
 float built = 1.0 - smoothstep(formation, formation + 0.06, height);
 float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
 float edge = COLOR.a;
 // Linhas angulares pontuais; sem faixas giratórias sobre o corpo.
 float crack_line = abs(UV.x - (0.38 + abs(UV.y - 0.55) * 0.36));
 float crack = (1.0 - smoothstep(0.006, 0.015, crack_line)) * stress;
 vec3 honey = mix(vec3(0.78, 0.30, 0.035), vec3(1.0, 0.72, 0.25), rim);
 ALBEDO = mix(honey * COLOR.rgb, vec3(1.0, 0.80, 0.42), max(edge, crack * 0.65));
 EMISSION = ALBEDO * (0.025 + edge * 0.08 + crack * 0.14);
 ALPHA = clamp((0.15 + rim * 0.30 + crack * 0.28) * (1.0 - edge) + edge * 0.48, 0.0, 0.8) * opacity * built;
}
