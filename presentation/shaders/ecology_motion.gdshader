shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.2, 0.45, 0.16, 1.0);
uniform float motion_strength : hint_range(0.0, 0.5) = 0.08;
uniform float motion_speed : hint_range(0.1, 3.0) = 1.0;
uniform float height_response : hint_range(0.1, 4.0) = 1.0;
uniform float emission_strength : hint_range(0.0, 1.0) = 0.0;
global uniform vec3 trip_wind_vector;
global uniform float trip_wind_strength;
global uniform float trip_cloud_coverage;
global uniform float trip_cloud_storm;
global uniform float trip_night;

varying float motion_light;
varying vec3 ecology_world_position;

void vertex() {
	vec3 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float height_mask = clamp(max(VERTEX.y, 0.0) * height_response, 0.0, 1.0);
	float broad_wave = sin(TIME * motion_speed + world_origin.x * 0.071 + world_origin.z * 0.053);
	float detail_wave = sin(TIME * motion_speed * 1.73 + world_origin.z * 0.13 + VERTEX.y * 1.9);
	float gust = mix(0.72, 1.28, sin(TIME * 0.43 + world_origin.x * 0.018) * 0.5 + 0.5);
	float weather_response = 1.0 + trip_wind_strength * 2.4 * gust;
	float displacement = (broad_wave * 0.72 + detail_wave * 0.28) * motion_strength * height_mask * weather_response;
	vec2 authored_direction = vec2(1.0, 0.38);
	vec2 weather_direction = normalize(trip_wind_vector.xz + vec2(0.001));
	vec2 bend_direction = normalize(mix(authored_direction, weather_direction, clamp(trip_wind_strength, 0.0, 1.0)));
	VERTEX.xz += bend_direction * displacement;
	motion_light = broad_wave * 0.5 + 0.5;
	ecology_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// MultiMesh COLOR already carries the authored per-instance palette. Multiplying
	// two dark forest colors crushed the crowns almost to black and erased every
	// lit plane. A weighted tint keeps biome identity while preserving value range.
	vec3 tint = mix(base_color.rgb, COLOR.rgb, 0.68);
	vec2 wind_direction = normalize(trip_wind_vector.xz + vec2(0.001));
	float cloud_wave = sin(dot(ecology_world_position.xz, vec2(0.037, 0.029)) + TIME * mix(0.08, 0.34, trip_wind_strength) + dot(wind_direction, vec2(2.7, 1.9)));
	float cloud_mask = smoothstep(mix(0.72, -0.18, trip_cloud_coverage), 0.84, cloud_wave);
	float underside = mix(0.82, 1.08, clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0));
	float weather_light = mix(1.0, mix(0.86, 0.74, trip_cloud_storm), cloud_mask);
	ALBEDO = tint * mix(0.94, 1.06, motion_light) * underside * weather_light;
	ROUGHNESS = mix(0.82, 0.9, trip_cloud_storm);
	AO = mix(0.82, 0.94, clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0));
	BACKLIGHT = tint * 0.12 * (1.0 - trip_cloud_storm * 0.65);
	EMISSION = tint * (emission_strength + trip_night * 0.045);
}
