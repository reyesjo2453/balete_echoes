# HD-2D in Godot: how this game does it

The look: pixel-art characters standing in lit 3D scenes, with depth of field, bloom and haze, plus **cinematic pixel
art made from 3D CG** for the big moments (summons), so the camera can crane and orbit while it still reads as pixel
art. This is usually built in Unreal (Octopath Traveler, Triangle Strategy). Godot 4.3 can do all of it. This file
says where each piece lives.

## 1. Two render tiers (`scripts/render_tier.gd`)

| | WEB (Compatibility) | HIGH (Forward+) |
|---|---|---|
| Where | the GitHub Pages link (phones, browsers) | the Linux / Steam Deck build |
| Depth of field | screen-space tilt-shift blur (`explore_map._post_material`) | real camera DOF (`CameraAttributesPractical`), focus follows the camera's target, plus a lighter tilt-shift |
| Light shafts / haze | a soft additive halo sprite on every lamp and candle | volumetric fog: every lamp lights the fog |
| Ambient occlusion | none | SSAO |
| Bloom | glow | stronger glow, soft-light blend |

`project.godot` picks Forward+, overridden to Compatibility on the web (`rendering_method.web`) and on mobile.
`RenderTier.high()` is true when a RenderingDevice exists, so a desktop that falls back to OpenGL, the web build
and the headless tests all get the WEB look. `RenderTier.dress()` is called from `explore_map._build_world`;
`RenderTier.focus()` runs every frame; `RenderTier.lamp()` dresses each map light.

To see the HIGH tier without a GPU: install `mesa-vulkan-drivers` and run with
`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json ... --rendering-method forward_plus`. It's slow (software
Vulkan) but correct with `--write-movie --fixed-fps`.

## 2. Pixelized-3D cinematics (`scripts/pixel_cg.gd`, `PixelCG`)

1. A small 3D world (its own `World3D`) renders into a **320x180** `SubViewport`, with no MSAA.
2. Models use a **toon shader** (three light bands, rim light, emission) with an **inverted-hull ink outline** as a
   second pass. Both work on both tiers.
3. The image is scaled to the screen with **nearest** filtering, then **posterized** (or snapped to a palette
   strip, `assets/vfx/palette_hatid.png`, when it exists) so the colours stay in a limited set.
4. **Pixel-stable camera:** every frame the camera snaps to one texel at its focus distance, and the leftover
   fraction slides the whole upscaled image. Motion stays smooth and the pixel grid never swims over the model.
5. Particles (`CPUParticles3D`, which works on web) at 320x180 become one- and two-pixel sparks.
6. The cinematic cuts to its own space (night sky, a dark river) with an **opaque** background: on Forward+, glow and
   depth of field drop a transparent viewport's alpha, so an opaque world is the robust choice. On HIGH it adds
   depth of field (bokeh) and glow.

A cinematic is a **sequence of cuts** (see the comment at the top of `pixel_cg.gd`): `{"id", "cuts": [...]}`. Each
cut has a duration, a transition in (cut, flash, fade, wipe) and its own camera keys. It can also hold:
- actors: models with keyed moves and keyed named nodes (e.g. `SwordArm`), and pixel-art sprite billboards (the
  real enemy sprite, with pose swaps and a hit flash);
- set dressing: props (Lola's candle), fog banks, prow wake spray, the light pillar, particles;
- impact effects: slash crescents, ground shock rings, hitstop, a camera shake in whole texels, slow motion;
- title cards and sound cues.

Letterbox bars frame every cinematic. `await PixelCG.play(seq)`. The first viewing always plays in full; after
that, tap, Space, Enter or Esc skips it (`Progress.seen_cg`). With `fast = true` (tests) it returns at once.

**Lola's TAWAG** (`stage_battle._tawag_shot`) is the model to copy: six cuts, 15 s:
1. the candle gutters;
2. the river in fog;
3. the boat passes and the camera cranes up to Lolo Pido in the light pillar;
4. the leap at the enemy;
5. the slow-motion cut with hitstop and white flash;
6. he goes home into the fog, nods once, and the lantern dies.

The hit then lands back in the battle.

**Adding a cinematic:** write a shot dictionary (copy `stage_battle._tawag_shot`), add the model to
`Blockouts.model()` as a blockout, and add an entry to `docs/ART_REQUESTS.md` for the real model.

## 3. Models and placeholders

- `Blockouts.model(id)` loads `assets/models/<id>.glb` if it exists (its colours kept, toon look applied) or builds a
  blockout from shapes. While a blockout is in use, the cinematic shows a pink `PLACEHOLDER` tag in the corner.
- `Placeholder.texture(id, size)` / `Placeholder.load_or(path, size)` give striped stand-ins for 2D art.
- Art comes from John's Antigravity / Gemini pipeline. Requests, with specs and prompts: `docs/ART_REQUESTS.md`.

## 4. Special moves: wind-up, travel, payoff (`stage_battle.gd`)

Every special plays in three beats.
- **Wind-up:** `_gather_up`. The camera pushes in, the user crouches and light is pulled in to them.
- **Travel:** a dash (`_lunge`) or a light ribbon (`_ribbon`: straight for a thread of prayer, jagged for a wire's
  current, vertical for a shaft of light).
- **Payoff:** `_impact`. Hitstop, a zoom punch, knockback, shake.

HATID, KONTRA, ORASYON, HATID SA KURYENTE and DASAL NG DALAWA all use them. Numbers are unchanged.

## 5. The flying aswang and the crowd

- **The aswang's wings:** `_build_wings` puts pixel-art bat wings behind the body; `_tick_wings` beats them with
  the hover and folds them for dives; `_take_off` plays at Phase II and when it flees. The frames are drawn in code
  until `<art>_wings.png` exists.
- **Bystanders have a temper** (devout, scared, filmer, brave; `_bystander_reaction`). They pray, cower and back
  away, film with a phone light, and the brave one shouts only once the foe is below 40%. Nobody cheers.

## 6. What's next

- More shots: the hatid boat on a send-home, Kardo's KONTRA as a wire-lit cut, the aswang finale's phase changes, the
  1998 rewind (the flood running backward around a pixelized parlor).
- Sprites are still billboards in the 3D maps (the HD-2D core). Normal-mapped sprites (lit from the side by candles)
  are the next lighting step: they need a normal map per sprite sheet (an art request).
