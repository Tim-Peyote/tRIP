# Menu natural-material pass, 2026-09-07

Production clearing now contains 21 instances of the detailed taiga conifers.
Editable Blender source: `natural_clearing.blend`. `upgrade_clearing.py` replaces
only grove meshes in the existing GLB, preserving camp placement and shared meshes.
The historical `build_menu.py` regenerates the OLD trees; do not use it to publish
over this pass without running the upgrade afterwards.

MenuCampBackdrop shares bark/granite/soil materials with the taiga material pass.
The menu SubViewport uses 4x MSAA; reduced ambient fill and fog preserve directional
shading, while the fire now casts shadows. Progression equipment remains untouched.

Verified: menu camp progression/material test; rendered main menu and settings.
Not finished: realistic fire/smoke, rock geometry in the clearing, understory,
composition beyond the clearing, full performance profiling. This is not visual
acceptance against Mortal Shell references. New tree geometry is substantially
heavier: benchmark menu GPU time before treating this as the final quality preset.
