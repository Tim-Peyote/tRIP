# Natural taiga material pass — 2026-09-07

Generated with the built-in image_gen tool (not CLI). Original generated PNGs
remain in the Codex generated_images directory; these copies are project assets.
The earlier stylized forest floor was discarded and is not referenced.

Installed: forest_floor_albedo.png, granite_albedo.png, cedar_bark_albedo.png.
These are generated base-color images, NOT scanned PBR sets. Normal/height and
measured roughness maps are not supplied yet. Seamless appearance was requested,
not mathematically guaranteed; inspect repetitions during final art QA.

Terrain uses 2m ground tiling, slope-based granite, mipmapped anisotropic sampling
and existing wet/snow/metamorphosis response. Natural texture contribution is
restricted to phase.ordinary. Rock and bark materials use triplanar projection
with distinct roughness/specular. Granite has three new 1280-triangle variants
exported through Blender MCP; editable source: art_sources/taiga/granite_detailed.blend.

Four conifers (cedar, fir, young_fir, wind_cedar) now use branching trunks and
geometric needle sprays exported from art_sources/taiga/conifers_detailed.blend.
Rebuild using build_conifers_detailed.py through Blender MCP. Each source mesh
has 63,842 triangles: this is NOT yet an approved forest-wide performance budget.
The runtime library preserves imported mesh LODs for single-mesh identity-transform
exports instead of reconstructing those surfaces. Other exports retain the fallback.
See https://docs.godotengine.org/en/stable/classes/class_importermesh.html.
Do not rerun the historical build_taiga.py over these production exports: it
replaces the new rocks and conifers with the old procedural versions.

Verified: conifer_material_capture renders the runtime library's three adult
variants with bark materials and shadows; lighting_material_pipeline_test passes.
The population capture does not frame trees and is not visual acceptance of the
new forest. Needle aliasing, regular crown tiers and frame time need further QA.

Still outstanding: replacement understory/remaining foliage, true height/normal material
detail, physically coordinated weather response on props, biome composition and
frame-time comparison. This is a first surface pass, not the completed reference
quality environment. Existing capture shutdown warnings: 7 texture RIDs; material
test shutdown reports one dummy shader RID. Both tests finish; leaks remain open.

## Final generation prompts

### Forest floor
Production game texture, seamless tileable square base-color albedo photograph,
orthographic overhead flat scan of Altai taiga forest soil: dense fine decaying
cedar needles, dark brown earth, sparse muted green moss, tiny fragments of bark
and grey grit. Physically believable photographic surface, NOT stylized or
painted, NOT low poly. Neutral diffuse flat lighting, no baked cast shadows,
no directional highlights, no perspective, no large objects, no text. Entire
image is continuous natural texture, seamless opposite edges, restrained
mid-dark earthy colors, readable multiscale fine detail.

### Granite
Seamless tileable photorealistic granite rock base color albedo texture for PBR
game material. Flat orthographic surface scan, neutral diffuse lighting with NO
baked directional shadows or highlights. Weathered Altai grey granite, warm grey
mineral grains, fine quartz flecks, natural irregular hairline fissures, very
sparse muted lichen. Full square texture, edge to edge, no standalone stones,
no horizon, no text, no frames. Natural restrained contrast, physically believable
photographic detail, not painted, not stylized, not low-poly. Opposite borders seamless.

### Cedar bark
Seamless tileable realistic Siberian cedar bark PBR albedo base-color texture.
Straight-on orthographic flattened bark surface, edge-to-edge vertical reddish
grey-brown fibrous bark ridges with irregular narrow deep grooves and fine
weathered flakes, occasional subtle lichen. Photographic scanned appearance,
neutral flat diffuse light, no directional highlights, no cast shadows, no
perspective, no trunk silhouette, no leaves, no border or text. Full square
texture. Fine convincing detail, natural restrained colors, not stylized or
handpainted. Left/right and top/bottom must tile.
