# Hand presentation and equipment — 2026-09-07

Toolbelt owns the selected hand slot, but ownership comes from InventoryComponent.
New players start unequipped; starter tools are actual inventory items. Inventory
offers Take / Put away, and dropping the equipped tool clears the hand slot.
Older belt-only saves migrate once using equipment_version. Quick cycling uses
owned tools, not a hardcoded list of available items.

ToolDefinition.hand_scene is the extension point for authored hand presentations.
Existing knife/vial sockets remain compatible. An item without a presentation
does not inherit the knife or show a fake grip. Per-item animation/pose libraries,
left/two-hand grips and final finger contact are still production work, not done.

FPS export now rotates the real forearm joint instead of stretching weighted
vertices. No procedural finger twisting is applied. Run sway is reduced; this
is not yet a full authored first-person run animation. Current generic Holding
pose still needs an item-specific knife grip review. Do not call it final art.

Jump now starts on the controller impulse, skips the source's 24-frame grounded
anticipation and samples the airborne phase from vertical velocity. Physics
remains authoritative for landing; a long fall does not replay takeoff.

Checks: hand_equipment_test, inventory_interaction_test, player_controller_test;
GPU hand composition: fps_arms_visual_capture. These do not certify final art.
