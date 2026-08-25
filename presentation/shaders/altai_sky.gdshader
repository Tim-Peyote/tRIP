shader_type sky;

uniform vec4 sky_top_color : source_color = vec4(0.025, 0.11, 0.23, 1.0);
uniform vec4 sky_horizon_color : source_color = vec4(0.62, 0.72, 0.63, 1.0);
uniform vec4 ground_bottom_color : source_color = vec4(0.018, 0.035, 0.028, 1.0);
uniform vec4 ground_horizon_color : source_color = vec4(0.27, 0.39, 0.34, 1.0);
uniform float sky_energy : hint_range(0.0, 4.0) = 1.0;
uniform float dusk_amount : hint_range(0.0, 1.0) = 0.0;
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
global uniform float trip_cloud_coverage;
global uniform float trip_cloud_storm;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

float cloud_noise(vec2 p) {
	float result = value_noise(p) * 0.56;
	result += value_noise(p * 2.07 + 11.4) * 0.28;
	result += value_noise(p * 4.13 - 7.8) * 0.16;
	return result;
}

void sky() {
	float elevation = clamp(EYEDIR.y, -1.0, 1.0);
	float upper_gradient = pow(clamp(elevation, 0.0, 1.0), 0.42);
	float lower_gradient = pow(clamp(-elevation, 0.0, 1.0), 0.32);
	vec3 upper_sky = mix(sky_horizon_color.rgb, sky_top_color.rgb, upper_gradient);
	vec3 lower_sky = mix(ground_horizon_color.rgb, ground_bottom_color.rgb, lower_gradient);
	vec3 color = mix(upper_sky, lower_sky, step(elevation, 0.0));

	// A stationary layered cloud field: weather changes coverage, but avoiding
	// TIME keeps the radiance cubemap from being regenerated every frame.
	vec2 spherical = vec2(atan(EYEDIR.z, EYEDIR.x) / 6.2831853 + 0.5, asin(clamp(EYEDIR.y, -1.0, 1.0)) / 3.1415926 + 0.5);
	float cloud_field = cloud_noise(spherical * vec2(9.0, 5.4) + vec2(4.1, -2.7));
	float cloud_threshold = mix(0.72, 0.36, clamp(trip_cloud_coverage, 0.0, 1.0));
	float clouds = smoothstep(cloud_threshold, cloud_threshold + 0.15, cloud_field) * smoothstep(0.03, 0.26, elevation);
	vec3 cloud_light = mix(vec3(0.72, 0.78, 0.76), vec3(0.16, 0.19, 0.22), clamp(trip_cloud_storm, 0.0, 1.0));
	cloud_light = mix(cloud_light, vec3(0.56, 0.31, 0.2), dusk_amount * 0.48);
	cloud_light = mix(cloud_light, vec3(0.08, 0.11, 0.18), night_amount * 0.82);
	color = mix(color, cloud_light, clouds * mix(0.7, 0.93, trip_cloud_storm));

	// Stable procedural star field, visible only above the horizon at night.
	// The grid intentionally matches the low radiance cubemap budget. Sub-pixel
	// stars disappear after cubemap filtering, so each chosen cell owns one dot.
	vec2 star_grid = spherical * vec2(360.0, 180.0);
	vec2 star_cell = floor(star_grid);
	vec2 star_local = fract(star_grid);
	float star_seed = hash21(star_cell);
	vec2 star_offset = vec2(hash21(star_cell + 7.3), hash21(star_cell + 31.9)) * 0.56 + 0.22;
	float star_dot = 1.0 - smoothstep(0.02, 0.075, length(star_local - star_offset));
	float star = star_dot * step(0.955, star_seed) * smoothstep(-0.01, 0.16, elevation) * night_amount;
	float star_temperature = hash21(star_cell + 19.7);
	float star_glow = smoothstep(0.72, 1.0, star);
	color += mix(vec3(0.56, 0.72, 1.0), vec3(1.0, 0.86, 0.66), star_temperature) * (star * 3.8 + star_glow * 1.4);

	if (LIGHT0_ENABLED) {
		float sun_disc = pow(max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0), mix(1150.0, 520.0, dusk_amount));
		float sun_halo = pow(max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0), 24.0);
		vec3 celestial = LIGHT0_COLOR * LIGHT0_ENERGY;
		color += celestial * (sun_disc * 4.2 + sun_halo * 0.14) * (1.0 - clouds * 0.82);
	}

	COLOR = color * sky_energy;
}
