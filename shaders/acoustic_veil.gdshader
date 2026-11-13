shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
    float scan = smoothstep(0.68, 0.96, sin(world_position.y * 8.0 + TIME * 2.0));
    float noise = sin(world_position.x * 5.0 + world_position.z * 3.0 + TIME * 4.0) * 0.5 + 0.5;
    ALBEDO = vec3(0.2, 0.35, 0.52);
    EMISSION = vec3(0.15, 0.4, 0.6) * (0.4 + scan * 0.3);
    ALPHA = clamp(edge * 0.11 + scan * noise * 0.025, 0.0, 0.18);
}
