# GEO researcher

## Current production rig — Mixamo, 2026-09-07

Supersedes the custom 20-bone rig described below. The production GLBs now use
the downloaded 65-bone Mixamo autorig on the same GEO body, including fingers.
Downloaded via the user's authenticated Mixamo session after marker placement.

- Male Locomotion Pack: Idle, Walking, Standard Run, Jump, left/right strafing.
- Talking (male seated): menu Seated loop.
- Farming Pack: Pick Fruit (generic Working action), Holding Idle (FPS rest pose).
- Crouching Idle and Crouched Walking: separate in-place crouch loops. The body
  animator follows controller stance in both camera modes; capsule clearance
  remains authoritative. Rejected crouched jumps do not carry into standing.
- `import_mixamo_researcher.py`: bake FBX A-pose bind and T-pose action together
  before applying animation-only FBXs; preserve vertical hip motion, remove X/Z
  hip translation for controller-driven in-place movement.
- `build_mixamo_fps.py`: derive camera forearms/hands from the same mesh and rig,
  keep the downloaded holding pose, adjust the cropped forearm continuation.
- Editable source: `mixamo_downloads/geo_mixamo.blend`; raw FBXs and this blend
  are excluded from Git. Review source-asset distribution rights before publishing
  a repository containing extractable animation/model assets.
- Source/service: https://www.mixamo.com/
- Terms guidance: https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html

Import and controller tests check the 65-bone rig and required animations; menu
test checks the shared model and seated loop. Visual checks cover walk, menu,
and FPS knife. These are functional motion imports, not a claim of finished
clothing, contact IK, or a polished item-specific finger grip.

## Previous implementation (historical)

Current third-person avatar: `assets/models/actors/geo_researcher.glb`.
Source: the user's existing Blender object `GEO-body_male_realistic`, duplicated
without changing the original. Source attribution/licensing must be retained
from its original asset package before distribution; this is not an original
TRIP body mesh. No newly downloaded model is used.

Editable delivery: `geo_researcher.blend`. Rebuild through live Blender MCP using
`build_geo_researcher.py` with the source object loaded. 10,582 body vertices,
20 bones, automatic smooth skinning, separate simple garment shells, 1.8m tall.
The multires modifier is omitted from the game copy. Six authored in-place clips:
Idle, Walk, Run, Jump, Working, Death. These are basic keyed cycles, not mocap.

Godot player scene references this GLB. Idle/walk/run loop in the avatar animator;
work is protected from immediate idle override; landing releases the jump pose.
The main menu instances the same GLB with the additional Seated loop and a stump
seat. `build_geo_views.py` (run after the body build) exports that clip and
`geo_first_person.glb`: cropped GEO arms with the same materials, a camera-specific
rest pose and shoulder continuation. The old wrad mesh is no longer referenced
by the production player. Knife and vial attach to RHand. V switches presentation
without replacing the character or resetting locomotion. Finger articulation and
precise item grip remain unfinished; garments are technical shells, not a final outfit.

Verified: import (all six nonempty clips), player controller regression including
multi-cycle walking, direction, sprint, jumping, V camera switching and work
completion. Visual capture: `core/tests/player_avatar_visual_capture.tscn`.
