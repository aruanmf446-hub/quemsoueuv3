shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec4 base_color : source_color = vec4(1.0);
uniform bool has_texture = true;
uniform bool has_normal = false;
uniform bool vertex_color_enabled = false;
uniform float normal_strength = 1.0;
uniform float surface_roughness = 0.8;
uniform float surface_metallic = 0.0;
uniform float source_hue = 0.0;
uniform float hue_width = 0.05;
uniform float target_hue = 0.6;
uniform float clothing_height = 10000.0;
varying float model_height;
void vertex() { model_height=(MODEL_MATRIX*vec4(VERTEX,1.0)).y; }
vec3 rgb_hsv(vec3 c) {
 vec4 k=vec4(0.0,-1.0/3.0,2.0/3.0,-1.0);
 vec4 p=mix(vec4(c.bg,k.wz),vec4(c.gb,k.xy),step(c.b,c.g));
 vec4 q=mix(vec4(p.xyw,c.r),vec4(c.r,p.yzx),step(p.x,c.r));
 float d=q.x-min(q.w,q.y);
 return vec3(abs(q.z+(q.w-q.y)/(6.0*d+0.00001)),d/(q.x+0.00001),q.x);
}
vec3 hsv_rgb(vec3 c) {
 vec3 p=abs(fract(c.xxx+vec3(0.0,2.0/3.0,1.0/3.0))*6.0-3.0);
 return c.z*mix(vec3(1.0),clamp(p-1.0,0.0,1.0),c.y);
}
void fragment() {
 vec4 color=base_color;
 if(has_texture) color*=texture(base_texture,UV);
 if(vertex_color_enabled) color*=COLOR;
 vec3 hsv=rgb_hsv(color.rgb);
 float distance_hue=abs(hsv.x-source_hue);
 distance_hue=min(distance_hue,1.0-distance_hue);
 float mask=(1.0-smoothstep(hue_width*0.6,hue_width,distance_hue))*smoothstep(0.24,0.48,hsv.y);
 mask*=1.0-smoothstep(clothing_height-0.04,clothing_height,model_height);
 ALBEDO=mix(color.rgb,hsv_rgb(vec3(target_hue,hsv.y,hsv.z)),mask);
 ALPHA=color.a;
 ALPHA_SCISSOR_THRESHOLD=0.1;
 ROUGHNESS=surface_roughness;
 METALLIC=surface_metallic;
 if(has_normal) { NORMAL_MAP=texture(normal_texture,UV).rgb; NORMAL_MAP_DEPTH=normal_strength; }
}
