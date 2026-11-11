# Episode 1 battle art: what the game needs

This lists every piece of art the battle screen can use in Episode 1. Everything should be 2D in the same inked comic style as the Episode 1 panels, with no 3D. It was written from the code as of commit `74dc5d2`, and **nothing in the game was changed** to produce it. The section "What the battle code can't show yet" lists the art that has nowhere to go until the code changes.

## How the battle screen draws things today

- **Screen:** 1280x720 viewport (`project.godot`). Party on the left, the one enemy on the right, turn-order chips at the top, an intent card at top right, a caption box at top left, HP panels along the bottom, and the timing ring in the centre.
- **Characters ("actors")** are `BattleActor` nodes (`godot/scripts/battle_actor.gd`). For each actor id, the game checks these in order:
  1. `res://assets/battle/<id>/actor.tscn`: any scene. If it has a `play(move)` method, the game calls it with the move names below.
  2. `res://assets/battle/<id>/<move>.png` plus `res://assets/battle/<id>/<move>.json`: one horizontal sprite-sheet strip per move. The JSON looks like `{"frame_w": 220, "frame_h": 340, "frames": 6, "fps": 10, "loop": true}`. `loop` defaults to true only for `idle`.
  3. If neither exists, it draws a flat silhouette with a coloured rim light (`godot/scripts/silhouette.gd`). **That is what every fighter uses now.** The folder `godot/assets/battle/` does not exist yet.
- **Code motion runs on top of the art.** The game moves art with tweens (idle sway, lunge, knockback, white hit flash, red glow on wind-up, fall-over on defeat). So a pose only needs to look right while the code moves it; it doesn't need to travel across the screen itself.
- **Move names** the code asks for: `idle`, `windup`, `attack`, `hit`, `parry`, `down`, `rise`, `cast`. A missing move is skipped: the previous pose stays on screen while the tween plays.
- **Facing:** draw *every* fighter facing **right**. The party already faces right. Enemies are mirrored by the code (`facing = -1`) so they face left toward the party.
- **Anchor:** the code pivots each actor at the bottom centre, 10 px above the bottom of the frame. Feet go there.
- **Scale:** sheet frames are drawn **1:1 with no scaling**, at the top-left of the actor box, so draw them at the box size below. (Higher resolution needs a code change; see the last section.)
- **Battle background:** one image for every fight: `Art.panel("ep1_12_alley_delivery")` (`combat.gd:127`), covered to fill the screen and darkened to about 40%. That panel is still a placeholder.

### Actor boxes (the frame size to draw at)

| Who | Box (w x h) | When |
|---|---|---|
| Party member, fighting alone | 220 x 340 | Fights 1–4 |
| Party member, two in the party | 190 x 300 | Fight 5 (Teo + Kardo) |
| Enemy (all of them) | 300 x 280 | Every fight |

Teo appears at both sizes. Until the code scales sheets, he needs either one set at 220x340 and a second at 190x300, or the scaling fix.

### Which moves each side actually plays

| Move | Party | Enemy | Triggered by |
|---|---|---|---|
| `idle` (loop) | yes | yes | Always, between moves |
| `windup` | no | yes | Enemy telegraphs its next attack (shown with the red glow) |
| `attack` | yes | yes | Lunge: party Attack/Wire/Discharge/counter; enemy strike that lands |
| `hit` | yes | yes | Taking damage |
| `parry` | yes | no | Perfect parry, and also used for a DODGE |
| `down` | yes | **not called** | Party wipe (before the watch rewinds the round) |
| `rise` | yes | no | After the rewind |
| `cast` | yes | no | Watch Rewind skill (Teo), and every ally on the defeat rewind |

The enemy wind-up tween differs by intent key: `lunge` crouches and coils, `flurry` shakes fast, and anything else rears back with a raised arm (the "claw" read). A `windup` pose should fit all three, or be drawn per intent (see the last section).

### Formats

- **Sprite sheets:** PNG with transparency (RGBA), one horizontal strip per move, frames of equal size, no padding. Must be `.png`: the sheet loader does not read webp.
- **Suggested frame counts** (the code doesn't require any count): idle 4–6 at 8 fps looping; windup 3–4; attack 4–6 at 12 fps; hit 2–3; parry 3; down 4; rise 3–4; cast 4–6.
- **Backgrounds:** 1600x900 webp, no transparency, same as the comic panels. The game darkens them, so keep them readable at low brightness.

## Episode 1, fight by fight

Episode 1 has five fights (`godot/data/episode1_flow.json`, beats `"type": "fight"`). Each fight has exactly one enemy actor. A group, like the drowned or the unsent, has to be drawn as one figure or crowd inside the single 300x280 enemy box.

### Fight 1: The flood at the parlor (cold open, parry tutorial)

- **Party:** Lolo Pido alone, a guest (`party: ["pido"]`). **Enemy:** `lunod`, "THE DROWNED" (90 HP, ghost silhouette, rim `#4fa3b8`).
- **Enemy attacks:** Grasp, Surge, and Chorus (3 rings). None is dodge-only.
- **Setting from the story:** the flooded funeral parlor (panel `ep1_c01_flood_parlor`).

| # | Item | Type | File path the code expects | Size, format | Transparency | Poses | Placeholder now |
|---|---|---|---|---|---|---|---|
| 1 | Lolo Pido, with sundang | Party sprite | `godot/assets/battle/pido/<move>.png` + `.json` | 220x340 frames, PNG | Yes | idle, attack, hit, parry, down, rise, cast | Teo/Renzo silhouette with a white rim (`kind: "teo"`, rim `#e8e8e8`) |
| 2 | The Drowned (a mass of hands and faces rising from flood water) | Enemy sprite | `godot/assets/battle/lunod/<move>.png` + `.json` | 300x280 frames, PNG | Yes | idle, windup, attack, hit (down recommended for later) | Ghost silhouette, rim `#4fa3b8` |
| 3 | Flooded parlor | Background | **No slot**: uses the shared `ep1_12_alley_delivery` | 1600x900 webp | No | — | Placeholder panel, darkened |

### Fight 2: Mang Berto, ligaw (at the wake; teaches DODGE)

- **Party:** Teo alone. **Enemy:** `ligaw_berto`, "MANG BERTO, LIGAW" (80 HP, ghost silhouette, rim `#8a6a3a`).
- **Enemy attacks:** Reach, Flood (dodge-only), and Grief (2 rings).
- **Setting:** the wake house at night (`ep1_30_wake_night`, `ep1_31_berto_ghost`).

| # | Item | Type | File path the code expects | Size, format | Transparency | Poses | Placeholder now |
|---|---|---|---|---|---|---|---|
| 4 | Teo, with balisong (solo size) | Party sprite | `godot/assets/battle/teo/<move>.png` + `.json` | 220x340 frames, PNG | Yes | idle, attack, hit, parry, down, rise, cast | Renzo silhouette, gold rim `#c9a24a` that whitens with utang |
| 5 | Mang Berto, possessed (jaw unhinged, brown water pouring) | Enemy sprite | `godot/assets/battle/ligaw_berto/<move>.png` + `.json` | 300x280 frames, PNG | Yes | idle, windup, attack, hit | Ghost silhouette, rim `#8a6a3a` |
| 6 | Wake house | Background | **No slot** (shared panel) | 1600x900 webp | No | — | Placeholder panel |

### Fight 3: The creek's unsent

- **Party:** Teo alone (reuses item 4). **Enemy:** `unsent`, "THE CREEK'S UNSENT" (85 HP, ghost silhouette, rim `#3fb8a8`).
- **Enemy attacks:** Cling, Undertow (dodge-only), and Swarm (3 rings).
- **Setting:** the estero/creek at night (`ep1_34_estero_pump`).

| # | Item | Type | File path the code expects | Size, format | Transparency | Poses | Placeholder now |
|---|---|---|---|---|---|---|---|
| 7 | The Unsent (several drowned dead coming up out of the creek together, reaching) | Enemy sprite | `godot/assets/battle/unsent/<move>.png` + `.json` | 300x280 frames, PNG | Yes | idle, windup, attack, hit | Ghost silhouette, rim `#3fb8a8` |
| 8 | Creek at night | Background | **No slot** (shared panel) | 1600x900 webp | No | — | Placeholder panel |

### Fight 4: The tagged aswang (boss; the watch awakens)

- **Party:** Teo alone (reuses item 4). His `cast` pose matters most here: the awakening and the first Rewind happen in this fight.
- **Enemy:** `aswang`, "TAGGED ASWANG" (140 HP, aswang silhouette, rim `#c8452e`, boss music).
- **Enemy attacks:** Claw, Lunge, Flurry (3 rings), and Drag Under (dodge-only). It has all three wind-up reads: claw, lunge and flurry.
- **Setting:** the creek bank under a dead streetlight (`ep1_13_aswang_fire_escape` for the look).

| # | Item | Type | File path the code expects | Size, format | Transparency | Poses | Placeholder now |
|---|---|---|---|---|---|---|---|
| 9 | Tagged aswang (boss) | Enemy sprite | `godot/assets/battle/aswang/<move>.png` + `.json` | 300x280 frames, PNG (a boss may want a bigger box; see the code changes below) | Yes | idle, windup (ideally claw / lunge / flurry variants), attack, hit; a smoke break-up for defeat is recommended | Aswang silhouette, rim `#c8452e` |
| 10 | Creek bank, dead streetlight | Background | **No slot** (shared panel) | 1600x900 webp | No | — | Placeholder panel |

### Fight 5: Hiraya hound (boss, Teo + Kardo)

- **Party:** Teo and Kardo (`party: ["teo","kardo"]`), both at the smaller 190x300 size.
- **Enemy:** `hiraya_hound`, "HIRAYA HOUND" (110 HP, hound silhouette, rim `#00b8d9`, boss music).
- **Enemy attacks:** Jab, Net (dodge-only), and Burst (3 rings).
- **Setting:** the workshop with the steel table (`ep1_24_workshop_raid`).

| # | Item | Type | File path the code expects | Size, format | Transparency | Poses | Placeholder now |
|---|---|---|---|---|---|---|---|
| 11 | Teo (duo size) | Party sprite | Same `godot/assets/battle/teo/` folder, so it **can't** have a separate size today | 190x300 frames, PNG | Yes | Same as item 4 | Silhouette |
| 12 | Kardo, with wrench and wires | Party sprite | `godot/assets/battle/kardo/<move>.png` + `.json` | 190x300 frames, PNG | Yes | idle, attack (also used for Wire and Discharge), hit, parry, down, rise, cast | Dante silhouette, rim `#5aa9c9` |
| 13 | Hiraya hound (four piston legs, sunrise lens and logo) | Enemy sprite | `godot/assets/battle/hiraya_hound/<move>.png` + `.json` | 300x280 frames, PNG | Yes | idle, windup, attack, hit; a lens-crack defeat is recommended | Hound silhouette, rim `#00b8d9` |
| 14 | Workshop | Background | **No slot** (shared panel) | 1600x900 webp | No | — | Placeholder panel |

(`tiyanak` is defined in `enemies.json` but doesn't appear in Episode 1.)

## Shared UI and effects (all fights)

| Item | Type | What the code does now | Art slot? |
|---|---|---|---|
| Turn-order chips (top) | Small portrait or icon | A coloured box with the unit's first letter (`_refresh_order`) | **No** |
| Intent card "NEXT ACTION" | Attack/intent icon | Text only: attack name and guard hint | **No** |
| HP / stagger / watch-energy panels | UI | Drawn bars, circles and rectangles | **No** (not needed) |
| Timing ring (PARRY / DODGE / COUNTER) | UI | Drawn circles (`timing_ring.gd`) | **No** |
| Hit sparks, slash arc, parry ring, rewind clock | Effects | Procedural lines and arcs (`fx_burst.gd`: `spark`, `slash`, `ring`, `clock`) | **No** |
| Rewind afterimages | Effect | Teal copies of the *silhouette*, even when the character has real art (`rewind_pulse`) | **No**: shows the silhouette over the real art |
| Damage numbers, "PERFECT PARRY!", banners | Text | Fonts with an outline | Not art |

## What the battle code can't show yet

The art should either fit these limits or wait for the matching code change. No code was changed for this list.

1. **Sprite sheets probably won't load in the exported web or Linux build.**
   - `_build_sheet` uses `FileAccess.file_exists` and `Image.load_from_file` on `res://` PNGs. In an export, Godot ships the imported texture, not the source PNG.
   - The export filter is `include_filter="data/*.json"`, so `assets/battle/**/*.json` isn't packed either.
   - The fix: load the texture with `load()`, and add `assets/battle/*.json` to the export filter. Do this **before** delivering sheets, or they will appear in the editor and vanish on the website.
2. **No per-fight background.** All five fights use `ep1_12_alley_delivery`, which is still a placeholder. Needs a `background` field in `enemies.json` or the flow beat, read in `combat.gd:127`.
3. **No scaling of sprite frames.** Frames show at native pixel size from the top-left of the actor box, so art must be drawn at 220x340, 190x300 or 300x280. Teo can't have a different set for the duo fight. Drawing at 2x for sharpness, or a bigger boss box, needs the sprite scaled to the actor box.
4. **Enemies never play a defeat.** On victory the enemy just stays idle while the text says it breaks apart. `down` isn't called for enemies.
5. **One wind-up pose per enemy.** The code only asks for `windup`, not per-intent wind-ups (claw, lunge, flurry). Variants would need move names like `windup_lunge`.
6. **One enemy per fight.** Groups (the Drowned, the Unsent) are a single actor, so draw them as one crowd figure.
7. **No icon slots** for turn-order chips or the intent card. No texture slots for effects. Rewind afterimages always use the silhouette.
8. **Kardo's Wire and Discharge** reuse the `attack` move. There are no `wire` or `discharge` poses.
9. **`.webp` isn't read for sheets:** sheets must be PNG.
10. **`actor.tscn` route:** a hand-built Godot scene (e.g. a cut-out rig with `AnimationPlayer` and a `play(move)` method) avoids limits 1 and 3 today. It's the only route that works without code changes, but each character needs to be set up in Godot.

## Count by type

| Type | Count | Notes |
|---|---|---|
| Party battle sprites | 3 characters: Teo, Lolo Pido, Kardo | 7 moves each = 21 strips. Teo needs a second size, or the scaling fix |
| Enemy battle sprites | 5: the Drowned, Mang Berto ligaw, the Unsent, the tagged aswang (boss), the Hiraya hound (boss) | 4 moves each = 20 strips, plus a recommended defeat for each (code can't show it yet) |
| Backgrounds | 5 wanted (parlor flood, wake house, creek, creek bank, workshop) | **0 slots today**: one shared placeholder panel |
| Attack / intent icons | 16 attacks (12 parryable, 4 dodge-only) | **0 slots today** |
| Turn-order portraits | 8 (3 party + 5 enemies) | **0 slots today** |
| Effects | 4 (spark, slash, ring, clock) + rewind afterimage | **0 texture slots**: all procedural |
| **Usable with today's code** | **8 sprite sets (41 strips)**, best through `actor.tscn` or after code fix 1 | Everything else needs a code change first |
