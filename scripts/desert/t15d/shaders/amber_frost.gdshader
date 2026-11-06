shader_type spatial;
render_mode unshaded, depth_draw_never;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
void vertex() { VERTEX += NORMAL * 0.001; }
void fragment() {
 // Resina tênue na silhueta. O rosto e as texturas continuam nítidos.
 float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.5);
 ALBEDO = vec3(1.0, 0.70, 0.24);
 EMISSION = vec3(0.0);
 ALPHA = rim * 0.075 * strength;
}
