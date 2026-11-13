shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled;
uniform vec4 stone_color : source_color = vec4(0.19,0.23,0.25,1.0);
uniform vec4 vein_color : source_color = vec4(0.29,0.36,0.35,1.0);
uniform float grain_scale = 1.6;
uniform float wetness = 0.0;
varying vec3 world_position;
float hash(vec3 p) { return fract(sin(dot(p,vec3(12.9898,78.233,43.883)))*43758.5453); }
float noise3(vec3 p) {
 vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){ world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 float n=noise3(world_position*grain_scale);
 float fine=noise3(world_position*19.0);
 float veins=smoothstep(0.70,0.91,noise3(world_position*0.37+vec3(n*0.7)));
 float seam=pow(abs(sin(world_position.y*1.8+noise3(world_position*0.42)*2.0)),24.0)*0.055;
 ALBEDO=mix(stone_color.rgb*(0.88+n*0.22+fine*0.08),vein_color.rgb,veins*0.40)-vec3(seam);
 ROUGHNESS=clamp(0.92-wetness*0.5-n*0.12,0.2,1.0);
 METALLIC=0.07;
}
