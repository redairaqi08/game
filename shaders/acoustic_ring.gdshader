shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform vec4 ring_color : source_color = vec4(0.17, 0.95, 0.86, 1.0);
uniform float radius = 1.0;
uniform float opacity = 1.0;
uniform float width = 0.08;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
    float d = length(local_position.xz);
    float edge = 1.0 - smoothstep(width * 0.35, width, abs(d - radius));
    float inner = 1.0 - smoothstep(width * 0.35, width, abs(d - radius * 0.72));
    float shards = 0.8 + 0.2 * sin(atan(local_position.z, local_position.x) * 28.0);
    ALBEDO = ring_color.rgb;
    EMISSION = ring_color.rgb * (edge + inner * 0.26) * 1.6;
    ALPHA = clamp((edge + inner * 0.22) * opacity * ring_color.a * shards, 0.0, 1.0);
}
