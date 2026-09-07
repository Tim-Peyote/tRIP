# Ordinary taiga — asset replacement pass

Original Blender geometry, based on docs/BIOME_ART_BIBLE.md: cedar/fir, deadfall,
rounded granite, ferns, sedge and berry understory. Thirteen models, approximately
13,182 triangles across the complete source kit (not per chunk).

`build_taiga.py` runs through Blender MCP; `ordinary_taiga.blend` is editable source.
Delivery is `assets/models/taiga`. Major tree/rock/fern meshes are cached and used
by the existing chunk MultiMeshes. Accent objects use the same metre-scale kit.
The four tree shapes are individual models, not colour swaps; the runtime mesh
budget is reduced in Blender before export.

This pass replaces vegetation/geology assets, not the entire authored POI,
skyline, water or weather system. Those retain their existing content.

Laboratory sites: one active, seven-metre flat interior, smooth seven-metre
transition to natural relief. Both terrain mesh/collision and ecology exclusions
use the same site data. Only affected loaded chunks are rebuilt. A previous pad
is restored when the camp is relocated; the current pad stays after dismissal
to avoid dropping a player standing on it. Manifested-save load recreates it.
