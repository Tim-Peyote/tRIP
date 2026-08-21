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

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float strength = clamp(trip_perception * trip_visual_intensity, 0.0, 1.0);
	float quiet = clamp(trip_toxicity * trip_visual_intensity, 0.0, 1.0);
	float danger = clamp(trip_danger * trip_visual_intensity, 0.0, 1.0);
	float metamorph = clamp(trip_world_transition * trip_visual_intensity, 0.0, 1.0);
	float hazard = clamp(trip_hazard * trip_visual_intensity, 0.0, 1.0);
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - vec2(0.5);
	float radius = length(centered);
	float angle = atan(centered.y, centered.x);
	float family = 2.0 + mod(trip_world_family, 4.0);
	float spiral = sin(angle * family + radius * 34.0 - TIME * 5.5);
	uv += normalize(centered + vec2(0.0001)) * spiral * metamorph * 0.034;
	uv.x += sin(uv.y * 46.0 + TIME * 7.0) * metamorph * 0.012;
	uv += vec2(sin(uv.y * 61.0 + TIME * 11.0), cos(uv.x * 47.0 - TIME * 8.0)) * hazard * 0.0017;
	float breath = sin(TIME * 1.35 - radius * 24.0) * 0.0035 * strength;
	uv += normalize(centered + vec2(0.0001)) * breath;
	float wave = sin(uv.y * 31.0 + TIME * 2.1) * 0.0018 * strength;
	float tracking = step(0.965, sin(uv.y * 9.0 - TIME * 0.72) * 0.5 + 0.5) * 0.012 * strength;
	uv.x += wave + tracking;
	vec2 chroma = vec2(0.0035 * strength, 0.0);
	vec3 color;
	color.r = texture(screen_texture, uv + chroma).r;
	color.g = texture(screen_texture, uv).g;
	color.b = texture(screen_texture, uv - chroma).b;
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 spore_grade = vec3(luminance * 0.52, luminance * 1.05, luminance * 0.38);
	color = mix(color, color + spore_grade * 0.22, strength);
	float mycelial_ring = smoothstep(0.035, 0.0, abs(fract(radius * 7.0 - TIME * 0.13) - 0.5)) * 0.06 * strength;
	color += vec3(0.18, 0.7, 0.24) * mycelial_ring;
	float scanline = sin(FRAGCOORD.y * 2.4) * 0.035 * strength;
	float noise = (hash(FRAGCOORD.xy + vec2(TIME * 73.0)) - 0.5) * 0.06 * strength;
	color += vec3(scanline + noise, scanline * 0.7, noise * 0.8);
	color = mix(color, floor(color * 28.0) / 28.0, 0.22 * strength);
	color *= 1.0 - smoothstep(0.34, 0.78, radius) * 0.32 * strength;
	vec3 quiet_grade = vec3(luminance * 0.72, luminance * 0.3, luminance * 0.22);
	color = mix(color, quiet_grade, quiet * 0.42);
	color *= 1.0 - smoothstep(0.18, 0.72, radius) * 0.52 * quiet;
	color += vec3(0.16, 0.015, 0.005) * sin(TIME * 2.4) * 0.035 * quiet;
	float heartbeat = pow(max(sin(TIME * 5.4), 0.0), 8.0) * danger;
	color += vec3(0.28, -0.035, -0.045) * (0.08 + heartbeat * 0.13) * danger;
	color *= 1.0 - smoothstep(0.2, 0.74, radius) * danger * (0.22 + heartbeat * 0.18);
	float transition_ring = smoothstep(0.08, 0.0, abs(radius - (0.68 - metamorph * 0.56)));
	float cellular = step(0.68, sin((uv.x + uv.y) * 72.0 + spiral * 3.0)) * metamorph;
	color = mix(color, color * 0.36 + trip_world_color.rgb * (0.42 + transition_ring * 0.72), metamorph * 0.62);
	color += trip_world_color.rgb * cellular * 0.11;
	color += vec3(1.0) * pow(metamorph, 8.0) * 0.2;
	color *= 1.0 - smoothstep(0.18, 0.76, radius) * metamorph * 0.58;
	float hazard_streak = pow(max(sin((uv.x + uv.y) * 84.0 - TIME * 13.0), 0.0), 12.0) * hazard;
	color += trip_hazard_color.rgb * hazard_streak * 0.14;
	color = mix(color, color * 0.72 + trip_hazard_color.rgb * 0.12, hazard * smoothstep(0.22, 0.82, radius) * 0.44);
	COLOR = vec4(color, max(max(max(max(strength * 0.92, quiet * 0.72), danger * 0.32), metamorph), hazard * 0.46));
}
