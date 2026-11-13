shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 echo_color : source_color = vec4(0.15, 0.88, 1.0, 1.0);
uniform float confidence : hint_range(0.0, 1.0) = 1.0;
uniform float pulse = 0.0;
uniform float silhouette_contrast : hint_range(0.7, 1.5) = 1.0;
varying vec3 local_position;
varying vec3 world_position;
void vertex() {
    local_position = VERTEX;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.6);
    float strata = pow(0.5 + 0.5 * sin(world_position.y * 73.0 + TIME * 0.8), 14.0);
    float band = smoothstep(0.88, 1.0, sin(world_position.y * 8.0 - TIME * 11.0));
    float fragment_noise = fract(sin(dot(floor(world_position * 28.0), vec3(12.9898, 78.233, 31.71))) * 43758.5453);
    float reconstruction = smoothstep(fragment_noise - 0.16, fragment_noise + 0.10, confidence);
    float surface = mix(0.15, 0.52, confidence) + fresnel * 0.55;
    ALBEDO = echo_color.rgb * (0.24 + confidence * 0.18) * silhouette_contrast;
    METALLIC = 0.25;
    ROUGHNESS = 0.35;
    EMISSION = echo_color.rgb * (fresnel * 1.4 + strata * 0.65 + band * 0.4 + pulse * 0.4) * silhouette_contrast;
    ALPHA = clamp(surface + strata * 0.15 + band * 0.1, 0.0, 0.96) * reconstruction * smoothstep(0.02, 0.22, confidence);
}
