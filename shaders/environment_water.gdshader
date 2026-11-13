shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform vec4 water_color : source_color = vec4(0.045,0.16,0.17,0.86);
varying vec3 world_position;
void vertex(){ world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 float ripples=sin(world_position.x*2.3+world_position.z*0.8+TIME*1.2)*sin(world_position.z*2.8-TIME*0.7);
 ALBEDO=water_color.rgb+vec3(ripples*0.017);
 METALLIC=0.65; ROUGHNESS=0.22;
 EMISSION=vec3(0.015,0.055,0.06)*(0.5+ripples*0.2);
 ALPHA=water_color.a;
 NORMAL_MAP=vec3(0.5+ripples*0.045,0.5+sin(world_position.z*4.0+TIME)*0.035,1.0);
}
