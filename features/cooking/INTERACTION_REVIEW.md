# Laboratory interaction review — 2026-09-07

Implemented and regression-tested:
- Inventory specimen selection is explicit. Selecting reserves nothing; physical
  processing removes that exact instance. Missing selection is rejected, not
  silently substituted. Further operations retain source quality.
- Full bag creates a persistent waiting result. Collection retry does not append
  heat events, reroll the recipe, grant mastery twice or destroy the output.
  Save/load preserves the waiting item; collection restores normal station use.
- Obtained brew is a normal inventory consumable and can be consumed there.
- Independent tool tween channels; bellows animate the model, not the static
  collision body. Stirring no longer interrupts bellows recovery.
- Empty vessel clears liquid/steam. Rejected actions do not extinguish steam.
- Hourglass completes its flip without snapping back in 0.01 seconds.

Verification: physical_cooking_test (including full bag, retry, save/load,
collection, use), road_laboratory_test, laboratory_motion_test (production scene).
physical_cooking_visual_capture exercises the summoned lab in a game session.
GPU capture exits with an existing 7-texture RID leak warning; not resolved here.

Remaining production work — not equivalent to Kingdom Come yet:
1. Item-specific hand targets and authored reach/place/pour/collect animations.
   Drive operation commit from the animation contact point, with cancellation
   before commit, instead of animating only after interaction completion.
2. Visible prepared specimen and bottled output tray with inspection/collection;
   reusable container accounting and explicit return of unused preparations.
3. Recipe-defined secondary processing of finished products. Current finished
   brews are usable/storable items, NOT generic inputs for any next operation.
4. Replace placeholder steam motes, add liquid pouring and restrained fire/ember
   response; synchronize spatial cues to the actual tool contact frames.
5. Hand-driven bellows/pestle/stirring input, timing and resistance. Current
   physical actions are discrete interactions, not continuous manipulation.

Design contract: inventory chooses WHAT, world tool chooses HOW; never consume
on selection. Show the exact sample, operation and quantity before commit.
Wrong procedure can produce a bad batch, but UI mistakes must not silently
substitute ingredients or lose an already finished result.
