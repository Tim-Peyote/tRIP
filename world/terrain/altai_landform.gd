extends RefCounted
## Shared, deterministic watershed geometry. Distances are compressed game metres,
## not a geographic reconstruction. No per-sample allocations or random calls.

static func river_x(z: float, seed_value: int) -> float:
	var phase := float(posmod(seed_value, 997)) * 0.006
	return 76.0 + sin(z * 0.009 + phase) * 24.0 + sin(z * 0.023 + phase) * 7.0

static func water_height(z: float) -> float:
	return -5.0 + z * 0.007

static func river_half_width(z: float, seed_value: int) -> float:
	return 5.0 + 2.0 * (0.5 + 0.5 * sin(z * 0.017 + float(seed_value % 31)))

static func relief(point: Vector2, seed_value: int) -> float:
	var phase := float(posmod(seed_value, 997)) * 0.006
	var axis := river_x(point.y, seed_value)
	var across := point.x - axis
	# Unequal opposing chains, with broad shoulders and subordinate spurs.
	var east := exp(-pow((across - 175.0 - 22.0 * sin(point.y * 0.008)) / 92.0, 2.0))
	var west := exp(-pow((across + 220.0 + 28.0 * sin(point.y * 0.006 + phase)) / 115.0, 2.0))
	var east_peaks := 68.0 + 64.0 * pow(0.5 + 0.5 * sin(point.y * 0.014 + phase), 2.0)
	var west_peaks := 48.0 + 45.0 * pow(0.5 + 0.5 * sin(point.y * 0.019 - phase), 2.0)
	var spurs := 9.0 * sin(point.y * 0.035 + across * 0.019) * smoothstep(35.0, 115.0, absf(across))
	return (east * east_peaks + west * west_peaks + spurs) * smoothstep(-40.0, 100.0, point.y)

static func carve_river(height: float, point: Vector2, seed_value: int) -> float:
	var distance := absf(point.x - river_x(point.y, seed_value))
	var width := river_half_width(point.y, seed_value)
	# Gravel floodplain, rounded banks, shallow bed. Always downhill to the south.
	var influence := 1.0 - smoothstep(width, width + 18.0, distance)
	var bed := water_height(point.y) - 1.2 + smoothstep(width * 0.65, width + 18.0, distance) * 4.0
	return lerpf(height, bed, influence)
