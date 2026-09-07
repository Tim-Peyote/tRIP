# Actors — original TRIP meshes and rigs

The current player has since been replaced with the user's GEO body. See
`GEO_RESEARCHER.md`; the original-mesh statement below applies only to the older
`researcher.glb` and the six fauna assets, not `geo_researcher.glb`.

Built in live Blender using official Blender Lab MCP. No third-party mesh or
animation data in these GLBs. `build_actors.py` reuses our mesh helper functions;
`taiga_actors.blend` retains editable armatures, vertex groups and NLA actions.

Researcher: 1.84m overall, Godot +Z facing, jacket, gaiters, gloves, backpack,
bedroll, facial geometry. Replaces the third-person avatar. The separate existing
first-person arm rig is unchanged. Mesh parts have rigid bone weights; these are
basic authored animation clips, not motion capture or final animation polish.

Fauna: maral, musk deer, wolf, bear, sable, eagle. Creature resources reference
the GLBs with metre-scale transforms and explicit clip names. Species behavior
and spawn rules remain in the existing creature system.

Checks: player_avatar_import_test, player_controller_test, biome_population_test.
Art captures: player_avatar_visual_capture and authored_taiga_capture.
