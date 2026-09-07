# Surface pass — 2026-09-07

Built-in image_gen (not CLI). Project assets: moss_albedo.png and cedar_wood_albedo.png in this directory. Albedo only; no claim of scanned normal/height maps or verified seamless borders.

## Moss prompt
Use case: photorealistic-natural. Asset type: seamless tileable game base-color texture, square. Orthographic flat scan of dense short Altai forest moss, fine olive green and muted golden brown moss fronds, scattered tiny exposed dark humus flecks. Realistic botanical microstructure, uniform scale edge to edge. Neutral diffuse lighting, no directional highlights or baked cast shadows. No stones, no large leaves, no composition or border, no text. Not stylized. Opposite edges seamlessly tile. This is albedo only, no perspective.

## Wood prompt
Use case: photorealistic-natural. Asset type: seamless tileable square albedo game texture of aged cedar wood. Straight-on orthographic flattened surface of natural sawn wood, fine vertical fibers, subtle small knots, weathered grey brown with subdued warm heartwood streaks. No separate boards or gaps, no objects, no border, no text. Neutral flat diffuse lighting with no baked highlights or directional shadows. Photorealistic fine grain, not painted or stylized. Both pairs opposite edges must tile seamlessly.

## Implementation and remaining work

Terrain: dual rotated litter samples, macro moss mask, vertex-alpha route mask, existing wet/snow response retained. Rock: triplanar granite and upward-facing moss patches. Rock moss currently uses an artistic spatial mask, NOT biome humidity sampling. Laboratory: shared wood/leather/iron/copper/ceramic shader materials; leather pores and patina procedural, not new texture scans. Same mapper in menu and station. Foliage: cached backlight materials, see https://docs.godotengine.org/en/4.7/classes/class_basematerial3d.html . UI: theme regenerated plus inventory scene accent replacements.

Additional work in this pass: dedicated gravel texture blended into routes and scree; separate fir bark texture; procedural end grain for exported heartwood surfaces; static soot near iron mesh bases. Soot is an art mask, not a cooking-history simulation.

Outstanding acceptance: soil contact blending at trunks, normal maps, environmental humidity/weather response on props, improved leaf geometry, VFX fire/smoke, populated forest performance capture. Existing biome population capture frames a barren slope and is not forest art acceptance. Do not call this the complete material set.

Checks: menu/material test, lighting pipeline, laboratory motion and physical cooking pass. Menu, inventory, gameplay and road laboratory captures render. Shutdown diagnostics: 7 Texture RIDs; verbose headless run identifies retained wind_soft.ogg audio playback and a dummy shader RID, not evidence of a resolved leak. No forest frame-time claim.
