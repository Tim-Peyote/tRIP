# Menu clearing — original TRIP meshes

`cedar_clearing.blend` is the editable Blender source; `build_menu.py` regenerates
the authored composition via the official Blender Lab MCP `execute_blender_code`.
Run the generator in Blender, not system Python. It creates a separate scene and
does not delete pre-existing scenes. The .gdignore prevents Godot importing source
.blend files in addition to the delivery GLB.

Delivery: `assets/models/menu_camp/cedar_clearing.glb`.
Godot composition: `features/frontend/menu_camp_backdrop.tscn`, `CedarClearing` node.
GLB contains individually named tree instances, terrain, granite, ferns, deadfall,
hearth, tripod, cauldron and field bench. Three tree mesh variants share geometry
across the grove. Materials are authored PBR; no downloaded asset licenses.

Blender Z-up export converts to Godot Y-up. Camp centre is (0,0,0); the tree line
lies primarily along Godot -Z. Fire animation/light belong to the Godot scene,
not to the GLB. Existing researcher and six progression-upgrade groups remain
separate and were not remodeled in this pass.

Verification: `core/tests/menu_camp_test.tscn` (all six progression levels and GLB
presence), `core/tests/menu_camp_visual_capture.tscn` (actual rendered menu).
