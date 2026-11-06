shader_type spatial;
render_mode unshaded, depth_draw_never;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
varying vec3 local_point;
void vertex() {
 local_point = VERTEX;
 VERTEX += NORMAL * 0.001;
}
void fragment() {
 float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.6);
 // Veios finos sobre a própria silhueta; preserva as texturas originais.
 float vein = pow(max(0.0, sin(local_point.y * 37.0 + sin(local_point.x * 29.0) * 2.5)), 28.0);
 ALBEDO = mix(vec3(0.97, 0.65, 0.20), vec3(1.0, 0.90, 0.62), rim);
 EMISSION = ALBEDO * 0.16;
 ALPHA = (rim * 0.22 + vein * 0.045 + 0.015) * strength;
}
