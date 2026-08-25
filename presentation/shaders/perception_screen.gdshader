shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
global uniform float trip_visual_intensity;
global uniform float trip_perception;
global uniform float trip_toxicity;
global uniform float trip_danger;
global uniform float trip_world_transition;
global uniform float trip_world_family;
global uniform vec4 trip_world_color;
global uniform float trip_hazard;
global uniform vec4 trip_hazard_color;

void fragment() {
	float strength = clamp(trip_perception * trip_visual_intensity, 0.0, 1.0);
	float quiet = clamp(trip_toxicity * trip_visual_intensity, 0.0, 1.0);
	float danger = clamp(trip_danger * trip_visual_intensity, 0.0, 1.0);
	float metamorph = clamp(trip_world_transition * trip_visual_intensity, 0.0, 1.0);
	float hazard = clamp(trip_hazard * trip_visual_intensity, 0.0, 1.0);
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - vec2(0.5);
	float radius = length(centered);
	// Metamorphosis bends the visual field as a single optical pulse. Repeating
	// sine bands looked like a debug overlay and hid the world at the exact moment
	// its transformation should be visible.
	float lens = (1.0 - smoothstep(0.08, 0.72, radius)) * pow(metamorph, 2.0);
	uv += centered * lens * 0.038;
	vec2 chroma = vec2(0.0022 * strength + 0.0035 * metamorph, 0.0);
	vec3 color;
	color.r = texture(screen_texture, uv + chroma).r;
	color.g = texture(screen_texture, uv).g;
	color.b = texture(screen_texture, uv - chroma).b;
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 spore_grade = vec3(luminance * 0.52, luminance * 1.05, luminance * 0.38);
	color = mix(color, color + spore_grade * 0.22, strength);
	color = mix(color, color + vec3(0.02, 0.07, 0.025), strength * 0.16);
	color *= 1.0 - smoothstep(0.48, 0.86, radius) * 0.14 * strength;
	vec3 quiet_grade = vec3(luminance * 0.72, luminance * 0.3, luminance * 0.22);
	color = mix(color, quiet_grade, quiet * 0.42);
	color *= 1.0 - smoothstep(0.18, 0.72, radius) * 0.52 * quiet;
	color += vec3(0.07, 0.008, 0.002) * 0.025 * quiet;
	float heartbeat = pow(max(sin(TIME * 5.4), 0.0), 8.0) * danger;
	color += vec3(0.28, -0.035, -0.045) * (0.08 + heartbeat * 0.13) * danger;
	color *= 1.0 - smoothstep(0.2, 0.74, radius) * danger * (0.22 + heartbeat * 0.18);
	float transition_ring = smoothstep(0.055, 0.0, abs(radius - (0.7 - metamorph * 0.58)));
	color = mix(color, color * 0.78 + trip_world_color.rgb * (0.16 + transition_ring * 0.24), metamorph * 0.24);
	color += vec3(1.0) * pow(metamorph, 10.0) * 0.12;
	color *= 1.0 - smoothstep(0.2, 0.78, radius) * metamorph * 0.18;
	color = mix(color, color * 0.82 + trip_hazard_color.rgb * 0.08, hazard * smoothstep(0.42, 0.9, radius) * 0.3);
	COLOR = vec4(color, max(max(max(max(strength * 0.38, quiet * 0.48), danger * 0.28), metamorph * 0.72), hazard * 0.24));
}
