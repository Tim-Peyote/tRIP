# Shared field laboratory

Original authored TRIP meshes, created in live Blender using official Blender
Lab MCP. No third-party textures. Metres, Blender Z-up → Godot Y-up.

Source: `field_laboratory.blend` (asset-sheet layout).
Generator: `build_laboratory.py`; execute through Blender MCP, not system Python.
It reuses the mesh-building helpers in `../menu_camp/build_menu.py` and creates a
new scene without deleting existing scenes. Each asset exports at local origin
before being arranged on the source sheet.

Delivery: `assets/models/laboratory/*.glb`.
Gameplay: `features/road_laboratory/portable_laboratory.tscn`.
Menu: `features/frontend/menu_camp_backdrop.tscn` shares the same models.
The hearth/tripod originate in the menu clearing Blender source.

The gameplay scene retains its interaction bodies, cooking components, unique
node names, animation pivots and progression gates. Do not replace interactive
roots with GLBs: replace their visual child. Table collision now spans the actual
4.9m bench. Preparation is on the front edge, stocks/advanced tools behind;
fire equipment remains separate at (2.05, 0, 0.56).

Checks: road_laboratory_test (manifest/dismiss, bindings, actual model geometry),
menu_camp_test (six progression stages), physical_cooking_test.
Art inspection: laboratory_asset_capture.tscn and menu_camp_visual_capture.tscn.
Legacy procedural dressing is retained only for regression fixtures, not the
production authored scene. Tent, minor props and researcher remain existing art.
