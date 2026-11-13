shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
uniform vec4 gate_color : source_color = vec4(0.55,0.82,0.78,1.0);
uniform float activation = 0.0;
void fragment(){
 vec2 p=UV*2.0-1.0; float r=length(p);
 float outer=(1.0-smoothstep(0.94,1.0,r))*smoothstep(0.81,0.88,r);
 float rings=pow(max(0.0,sin(r*46.0-TIME*(1.0+activation*3.0))),18.0);
 float core=(1.0-smoothstep(0.0,0.90,r))*0.13;
 float glyph=step(0.77,r)*step(r,0.90)*step(0.72,sin(atan(p.y,p.x)*18.0));
 float a=(outer*0.75+rings*(0.10+activation*0.45)+glyph*0.60+core)*(0.30+activation*0.70);
 ALBEDO=gate_color.rgb; EMISSION=gate_color.rgb*(1.2+activation*1.4); ALPHA=a*(1.0-smoothstep(0.96,1.0,r));
}
