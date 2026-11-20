# Art requests (for Antigravity / Gemini)

**Antigravity: start at HANDOFF.md §7** (the playbook). Work one `OPEN` entry at a time; mark it `DONE` when it is in.

Every asset the game is waiting for. Until a file exists at its path, the game shows a **placeholder**: a striped
magenta card, or for 3D a blockout built from simple shapes, with a pink `PLACEHOLDER` tag in the corner of the screen.
Drop the finished file in at the path below (same name) and it replaces the placeholder with no code change. Then
run `godot --headless --import` (or open the project once) and tick the entry off here.

House rules for every 2D request (HANDOFF.md §7): no text, no logos, no real brands. Sprite sheets on a flat pure
magenta background (#FF00FF), in a strict grid with no grid lines. Battle poses face left, enemies face right. Cut
sheets with `tools/pixel_sprites.py`.

---

## 1. `summon_pido`: Lolo Pido's ghost on Magwayen's boat (3D model)

- **Status:** DONE
- **Path:** `godot/assets/models/summon_pido.glb`
- **Used by:** Lola's TAWAG cinematic (`stage_battle.gd` `_tawag_shot`, played by `scripts/pixel_cg.gd`).
- **Today:** a blockout in `scripts/blockouts.gd` `_pido()`. Match its layout so the camera moves still frame him.
- **Spec:** glTF binary (.glb). Metres, Y up, origin at the boat's centre on the waterline, facing +Z. The figure is
  about 2.0 m tall standing on the boat's prow (prow at z ≈ +0.85); the boat is about 3.4 m long. Under ~5,000
  triangles in all. One texture atlas, 512 px or less, flat colours (the toon shader adds the light bands and
  outline; don't paint shading in). Keep these node names so the shot animates them: `Body` (the figure: it bobs,
  and nods in the last cut), `SwordArm` (a pivot at the right shoulder holding the arm, hilt and sundang: the TAWAG
  rotates it about Z from raised, 0°, down through −125° for the cut), `Lantern` with an `OmniLight3D` child called
  `LanternLight` (it flickers, then dims as he leaves). Material base colours are kept: a dark
  blue-grey coat, pale spirit-blue skin, a black panyo on the LEFT wrist, a steel sundang raised in the right hand, a
  lantern low in the left hand.
- **Prompt (3D):**
  > Low-poly stylised 3D model for a retro HD-2D game, game-ready, about 4,000 triangles, flat colours, no baked
  > lighting. A Filipino *sundô* (soul-guide) in his sixties, a ghost: lean, upright, grey hair combed back, a long
  > dark blue-grey coat like an old barong worn over trousers, a black cloth band (panyo) tied around his LEFT wrist.
  > His right hand raises an old single-edged Filipino sundang blade; his left hand holds a small square paper
  > lantern low. He stands on the pointed prow of a long, narrow wooden ferry boat (about 3.4 m), a ferry pole
  > lying along the stern. Pale spirit-blue skin and coat edges. T-pose not needed: model him in this pose. Y up,
  > facing +Z, origin at the boat's centre on the waterline. Export .glb.

## 2. `palette_hatid`: the cinematic palette (optional, 2D)

- **Status:** DONE
- **Path:** `godot/assets/vfx/palette_hatid.png`
- **Used by:** `PixelCG.post_material`: every pixel of a cinematic snaps to the nearest colour in this strip. Without
  it the cinematic posterizes to 10 levels per channel (the current look).
- **Spec:** PNG, N x 1 pixels, N from 16 to 64, one colour per pixel. Night river blues, spirit cyan, lantern amber,
  ember orange, a near-black ink, a white.
- **Prompt (2D):**
  > A single-row colour palette strip, 32 pixels wide and 1 pixel tall, for a moody 16-bit night scene in Manila:
  > deep navy to midnight blue, river teal, pale spirit cyan, moonlight white, lantern amber and orange, two warm
  > browns, near-black ink. Flat, one colour per pixel, no gradients, no text.

## 3. TAWAG particle sprites (optional, 2D)

- **Status:** DONE
- **Paths:** `godot/assets/vfx/ember.png`, `godot/assets/vfx/wisp.png`
- **Used by:** the embers and spirit wisps in `PixelCG._particles` (today: plain squares, which already read as pixel
  sparks at 320x180).
- **Spec:** PNG with transparency, 8x8 px each, hand-placed pixels, centred.
- **Prompt (2D):**
  > Two tiny pixel-art particle sprites, each 8x8 pixels on a flat magenta background (#FF00FF), side by side in a
  > strict 2 x 1 grid, no grid lines: (1) a glowing orange-yellow ember, brightest pixel in the centre; (2) a pale
  > cyan spirit wisp, soft and round. No text.

## 4. The aswang in flight (2D)

- **Status:** DONE
- **Paths:** `godot/assets/explore/aswangf_fly.png` (the Unchained Aswang, Act 3, Phase II on) and
  `godot/assets/explore/aswang_fly.png` (the tagged aswang, Act 2: its escape over the roofs)
- **Used by:** `stage_battle.gd` `_build_wings` / `_tick_wings`: while it hovers, this strip plays in place of the idle
  pose, frame by frame on the wingbeat; frame 4 shows while it dives. **Today:** the idle sprites already have folded
  wings, so the flight is in the motion only (an asymmetric wingbeat bob, dust off the floor each downstroke, a
  crouch-and-gust take-off). The wings don't visibly beat until this lands.
- **Spec:** PNG with transparency, a strict 4 x 1 strip; each cell the same size as the creature's idle sprite
  (`aswangf_idle.png` is 240x243, `aswang_idle.png` 270x243), the body in the same place and scale in every cell,
  feet at the bottom edge as in the idle. Frames: (1) wings raised high, (2) spread level, (3) the downstroke, wings
  swept low, (4) wings folded tight for a dive. Facing right, like the idle.
- **Prompt (2D):**
  > Pixel-art sprite strip, 4 frames side by side in a strict 4 x 1 grid, no grid lines, flat magenta background
  > (#FF00FF): the same creature as the reference (a gaunt Filipino aswang with long black hair, a long tongue, a
  > glowing tag in its ear, torn dark-red bat wings), now flying, facing right, legs drawn up. Frame 1 wings raised
  > high, frame 2 spread level, frame 3 swept down on the downstroke, frame 4 folded tight for a dive. Same size,
  > palette and pixel density as the reference in every frame. No text.

## 5. Bystander reaction poses (2D)

- **Status:** DONE
- **Paths:** `godot/assets/explore/<npc>_pray.png`, `<npc>_cower.png`, `<npc>_phone.png` for the bystanders at each
  fight (`nena`, `domeng`, `cards_a`, `balut`, `trike`, `kid`, `tess`, `celso`, `guard`)
- **Used by:** the grounded crowd (`stage_battle._bystander_reaction`): the devout pray, the scared cower, the
  filmers hold a phone up, the brave shout; wired in `explore_map._trigger_anim` and `explore_map._update_cast` to
  swap to the matching pose for the duration and revert to idle afterward.
- **Spec:** the same size, framing and feet position as the NPC's existing sprite, so they swap in place.
- **Prompt (2D, per NPC):**
  > The same character as the reference, same size and framing, three poses side by side on flat magenta
  > (#FF00FF), strict 3 x 1 grid, no grid lines: (1) praying, hands clasped at the chest, head bowed, rosary;
  > (2) cowering, crouched low with arms up; (3) holding a smartphone up at arm's length to film, its screen
  > glowing. 16-bit pixel art, no text.

---

## How a new request gets added

When a feature needs art that doesn't exist yet, the code loads it through `Placeholder.load_or(path, size)` (2D)
or `Blockouts.model(id)` (3D), and the request goes here with its path, size, how it's used, and a prompt. Never
generate it from the code session: art comes from John's Antigravity / Gemini pipeline.
