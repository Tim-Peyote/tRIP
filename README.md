# TRip

First-person knowledge-driven expedition game built with Godot 4.7.2 stable.

## Open in Godot

Open `/Users/shaman/Desktop/Projects/Godot/TRIP/project.godot` from the Project Manager, or run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --editor --path /Users/shaman/Desktop/Projects/Godot/TRIP
```

## Smoke test

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/shaman/Desktop/Projects/Godot/TRIP \
  res://core/tests/smoke_test.tscn
```

Gameplay interaction test:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/shaman/Desktop/Projects/Godot/TRIP \
  res://core/tests/gameplay_test.tscn
```

Cooking and effect integration test:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/shaman/Desktop/Projects/Godot/TRIP \
  res://core/tests/cooking_effect_test.tscn
```

Harvest quality test:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/shaman/Desktop/Projects/Godot/TRIP \
  res://core/tests/harvest_quality_test.tscn
```

Expedition systems test:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/shaman/Desktop/Projects/Godot/TRIP \
  res://core/tests/expedition_systems_test.tscn
```

Stealth and distraction test:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/shaman/Desktop/Projects/Godot/TRIP \
  res://core/tests/stealth_test.tscn
```

Physical cooking test:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/shaman/Desktop/Projects/Godot/TRIP \
  res://core/tests/physical_cooking_test.tscn
```

Interactive inspection test:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/shaman/Desktop/Projects/Godot/TRIP \
  res://core/tests/inspection_test.tscn
```

Full cycle and persistence test:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/shaman/Desktop/Projects/Godot/TRIP \
  res://core/tests/full_cycle_persistence_test.tscn
```

## Current controls

- `WASD` — movement
- `Mouse` — look
- `Shift` — sprint
- `C` — crouch
- `E` / left mouse — interact or hold interaction
- `F` — enter/leave inspection of the focused object
- `Right Mouse` — select another harvest part
- `B` — open/close the bag
- `1` — use the first prepared consumable
- `Q` — switch between the field knife and spore vial
- `J` — open/close the field herbarium
- `G` — throw a stone to distract creatures
- `L` — dismiss or manifest the unlocked road laboratory near the player
- `Esc` — pause
- `F10` — developer world-phase panel (`PageUp/PageDown`, `R`, `Backspace`)

During inspection: hold left mouse and drag to rotate, use the wheel to zoom, or use `A/D` for stepped rotation. Finding every morphological clue confirms the species hypothesis.

Gamepad defaults are installed through InputMap at boot: left/right sticks, A interact, X inspect, stick buttons for sprint/crouch, Start pause.

Physical cooking order: grind a clean cap, add water, transfer the mash, light a low fire, stir at least twice while warm, watch for silver steam, then bottle the result. High heat can ruin the mixture.

Current playable loop: inspect and harvest the correct forest cap, return to the shelter, prepare a clean spore-sight brew, review the expedition report, then enter the newly unlocked deep-grove route. Slot `0` autosaves and is available through Continue.

## Design documents

- `docs/GAME_DESIGN.md`
- `docs/UX_INTERACTION.md`
- `docs/ARCHITECTURE.md`
- `docs/ROADMAP.md`
- `docs/IMPLEMENTATION_STATUS.md`
