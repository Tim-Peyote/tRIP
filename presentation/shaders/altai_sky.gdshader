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

// Longitude/latitude UVs collapse every texel into one point at the zenith.
// Blend three Cartesian projections instead, so clouds and stars remain
// continuous when the player looks straight up and across cubemap faces.
vec3 direction_weights(vec3 direction, float sharpness) {
	vec3 weights = pow(abs(normalize(direction)), vec3(sharpness));
	return weights / max(dot(weights, vec3(1.0)), 0.0001);
}

float directional_noise(vec3 direction, float scale, vec3 seed) {
	vec3 weights = direction_weights(direction, 5.0);
	float x_projection = cloud_noise(direction.yz * scale + seed.xy);
	float y_projection = cloud_noise(direction.xz * scale + seed.yz);
	float z_projection = cloud_noise(direction.xy * scale + seed.zx);
	return dot(vec3(x_projection, y_projection, z_projection), weights);
}

float star_projection(vec2 coordinates, vec2 seed) {
	vec2 grid = coordinates + seed;
	vec2 cell = floor(grid);
	vec2 local = fract(grid);
	float chosen = step(0.955, hash21(cell + seed * 0.37));
	vec2 offset = vec2(hash21(cell + 7.3), hash21(cell + 31.9)) * 0.56 + 0.22;
	return (1.0 - smoothstep(0.02, 0.075, length(local - offset))) * chosen;
}

float directional_stars(vec3 direction, float scale) {
	vec3 weights = direction_weights(direction, 9.0);
	float x_projection = star_projection(direction.yz * scale, vec2(17.3, 41.7));
	float y_projection = star_projection(direction.xz * scale, vec2(-23.9, 8.4));
	float z_projection = star_projection(direction.xy * scale, vec2(52.1, -14.6));
	return dot(vec3(x_projection, y_projection, z_projection), weights);
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
	vec3 sky_direction = normalize(EYEDIR);
	float cloud_field = directional_noise(sky_direction, 7.5, vec3(4.1, -2.7, 9.6));
	float cloud_detail = directional_noise(sky_direction, 19.0, vec3(-8.7, 5.1, 13.2));
	cloud_field = mix(cloud_field, cloud_detail, 0.28);
	float cloud_threshold = mix(0.72, 0.36, clamp(trip_cloud_coverage, 0.0, 1.0));
	float cloud_erosion = smoothstep(0.28, 0.72, cloud_detail);
	float clouds = smoothstep(cloud_threshold, cloud_threshold + 0.12, cloud_field) * mix(0.58, 1.0, cloud_erosion) * smoothstep(0.03, 0.26, elevation);
	float cloud_core = smoothstep(cloud_threshold + 0.09, cloud_threshold + 0.27, cloud_field);
	vec3 fair_cloud = mix(sky_horizon_color.rgb, vec3(0.62, 0.66, 0.64), 0.42);
	vec3 cloud_light = mix(fair_cloud, vec3(0.16, 0.19, 0.22), clamp(trip_cloud_storm, 0.0, 1.0));
	cloud_light = mix(cloud_light, vec3(0.56, 0.31, 0.2), dusk_amount * 0.48);
	cloud_light = mix(cloud_light, vec3(0.08, 0.11, 0.18), night_amount * 0.82);
	vec3 cloud_base = cloud_light * mix(0.72, 0.48, trip_cloud_storm);
	vec3 cloud_color = mix(cloud_light, cloud_base, cloud_core * 0.72);
	color = mix(color, cloud_color, clouds * mix(0.4, 0.78, trip_cloud_storm));

	// Stable procedural star field, visible only above the horizon at night.
	// The grid intentionally matches the low radiance cubemap budget. Sub-pixel
	// stars disappear after cubemap filtering, so each chosen cell owns one dot.
	float star = directional_stars(sky_direction, 92.0) * smoothstep(-0.01, 0.16, elevation) * night_amount;
	float star_temperature = directional_noise(sky_direction, 31.0, vec3(19.7, -3.8, 27.1));
	float star_glow = smoothstep(0.72, 1.0, star);
	color += mix(vec3(0.56, 0.72, 1.0), vec3(1.0, 0.86, 0.66), star_temperature) * (star * 3.8 + star_glow * 1.4);
	float galactic_band = exp(-pow(abs(dot(normalize(EYEDIR), normalize(vec3(0.18, 0.72, -0.67)))), 2.0) * 32.0);
	float galactic_texture = directional_noise(sky_direction, 4.2, vec3(2.4, 9.3, -6.7));
	color += vec3(0.11, 0.15, 0.28) * galactic_band * galactic_texture * night_amount * smoothstep(0.02, 0.32, elevation) * (1.0 - clouds);

	if (LIGHT0_ENABLED) {
		float sun_disc = pow(max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0), mix(1650.0, 720.0, dusk_amount));
		float sun_halo = pow(max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0), 72.0);
		vec3 celestial = LIGHT0_COLOR * LIGHT0_ENERGY;
		color += celestial * (sun_disc * 2.6 + sun_halo * 0.035) * (1.0 - clouds * 0.82);
	}

	COLOR = color * sky_energy;
}
