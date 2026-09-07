# Inventory interaction / art direction

Direction: restrained dark fantasy (Mortal Shell II reference), charcoal, bone,
aged bronze. Not a recolor of rounded dashboard panels. The item grid is the
primary visual surface; a thin divider separates contextual details and actions.

## Contracts
- Hover highlights only. Click or keyboard focus selects the stack.
- Refresh/reselect preserves the chosen instance while it exists.
- Dragging the selected stack carries that same instance, not the best specimen.
- Use/equip/laboratory selection and world-drop remain outside detail scrolling.
- At narrow widths the grid loses columns; actions never disappear.
- Filters wrap; sort remains available. Close has a visible mouse target.
- Mixed stacks prioritize specimen selection over a duplicate illustration.
- Tool icons are still a temporary, visually inconsistent set: art replacement
  is not completed by this UX pass.

## Verification
Run core/tests/inventory_ux_test.tscn (real renderer for captures):
selection persistence, payload identity, hover neutrality, close, panel/action
bounds at 1280x720, 800x600, 640x600. Captures go to /tmp/trip_inventory_ux_*.png.
Also inventory_interaction_test.tscn and hand_equipment_test.tscn.
These programmatic tests are not a complete manual mouse/gamepad pass.
Shutdown still reports the pre-existing 7 Texture RID warning.
