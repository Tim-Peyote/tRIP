# Altai: geographic grammar, not scattered props

## Primary references
- https://www.altzapovednik.ru/info/obshee.aspx — alpine relief, plateaux,
  broad valleys, deeply cut gorges. Not one uniform forest surface.
- https://katunskiy.ru/o-zapovednike/prirodnye-usloviya/com_content-article-57
  — glacial troughs, lateral and terminal moraines, valley landforms.
- https://katunskiy.ru/o-zapovednike/prirodnye-usloviya/com_content-article-46
  — drainage from mountain/glacial headwaters; varying gradients.
- https://www.altzapovednik.ru/info.aspx — Teletskoye and Dzhulukul lakes,
  Chulyshman catchment. References for scale and spatial relationships,
  not a claim that these exact landmarks are reconstructed in the game.

## Implemented first structural pass
`world/terrain/altai_landform.gd`: unequal opposing mountain chains, side-spur
modulation, broad low valley, coherent meandering shallow channel. Seed changes
the chain rhythm and channel. Continuous mathematical samples across chunks.
River water follows a monotonic southward grade; channel reserved from props.
Environment context uses real channel distance and adjusted altitude bands.
Distant taiga mountain curtain replaced by lit volumetric belt (~6144 triangles).
Only ordinary taiga changes; other consciousness worlds retain their rules.
Existing routes, POI blending, collision generation and laboratory pads retained.

## NOT finished / acceptance requirements
- Current smooth slopes need geological detail: exposed beds, scree fans,
  erosion gullies and cliff formations, without blocking story routes.
- No connected tributary network, lake basin, waterfalls or authored landmark
  reconstruction yet. Channel is a shallow visual/terrain feature, not a full
  fluid simulation. Water interaction/audio needs integration.
- Water is currently detail-tier decor: extend water HLOD before claiming
  uninterrupted distant views. Measure timings before increasing draw distance.
- Test every seeded story route and POI for access; no blanket claim of
  navigability based on a screenshot or a height function test.
- Hero vistas: forest opening → river bend → side gorge → high pass. Preserve
  distant landmarks through canopy gaps; not every chunk gets a spectacle.
- Ecological belts: moist valley forest, mixed slopes, sparse upper woodland,
  rock/scree and localized high snow. No uniform snow or moss everywhere.
- Belukha-scale massif, Chulyshman-like gorge and Teletskoye-like long basin
  are distinct composition references, not props to scatter in every biome.
