# TRip UI Style Guide

## Intent

The interface must protect the landscape. Permanent HUD occupies the outer safe zones; the centre belongs to navigation, interaction and metamorphosis. The visual language is restrained field instrumentation with Altai expedition materials, not a generic neon dashboard.

Reference synthesis:

- `Breath of the Wild`: small separated information islands, strong negative space, contextual stamina and environment information.
- `Valheim`: survival resources and food read as one preparation model rather than unrelated debug statistics.
- `Gothic 1 Remake`: low-noise exploration view, contextual prompts and warnings that become prominent only when relevant.

These are composition references, not a request to reproduce their assets, typography or ornamental motifs.

## Runtime HUD

- Safe horizontal margin: `clamp(viewport_width * 1.9%, 16 px, 34 px)`.
- Objective lives top-left; time and weather top-right; current danger may occupy the top-centre lane.
- Health and stamina form one compact bottom-left cluster. Normal temperature, zero wetness, zero spores and zero toxicity are hidden. Food slots are hidden while empty.
- Tool and distraction counts use typography and shadow, not independent framed cards.
- Interaction stays centred near the lower third and appears only for a valid target.
- Important changes use a short one-shot notice. Persistent prose must not remain over the reticle.

## Modal screens

- Inventory uses 4/3/2 columns at wide/medium/narrow logical widths. Below 760 px the secondary detail card yields to the item grid; below 920 px sorting is hidden before filters are compressed.
- Outer modal margin is proportional and clamped. Content padding is larger than control-to-control spacing.
- Selected state is expressed by one bright contour and tonal lift. Unselected cards use low-opacity surfaces without heavy drop shadows.
- Text hierarchy: screen title, navigation, capacity summary, content, contextual hint. Avoid repeated section labels when position already conveys meaning.
- Journal is clamped to viewport dimensions rather than relying on a fixed 1080×620 rectangle.

## Motion and accessibility

- Transitions stay short (`0.16–0.24 s`) and never delay control.
- Critical state cannot be communicated by colour alone: every hazard has text and a meter/state label.
- Minimum interactive height is 34 px in dense modal navigation and 42 px for isolated interaction chips.
- All screens retain keyboard/gamepad focus states and must fit the 1280×720 reference viewport.
