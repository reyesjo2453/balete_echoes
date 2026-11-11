# Episode 1 battle art: what the game needs

Every piece of art the Episode 1 battle screen can use, and exactly where to put it. All of it is 2D, in the same inked comic style as the Episode 1 panels; no 3D.

**Status: all Episode 1 poses and backgrounds are in** (OpenArt, Starter plan, not cleared for commercial release; see `godot/assets/battle/CREDITS.md`). The silhouettes and the `ep1_12` stand-in remain as fallbacks for anything missing. Bonus poses that nothing calls yet: `lunod/defeat`, `aswang/defeat`, `aswang/windup_lunge`, `hiraya_hound/defeat` and `hiraya_hound/windup_burst`.

The battle code loads poses and strips in the exported web and Linux builds. One pose per move works, poses are scaled to fit, and each fight has its own background slot.

## Art spec at a glance

| What | Path | Canvas | Format | Transparent |
|---|---|---|---|---|
| Party pose | `godot/assets/battle/<id>/<move>.png` | **440 x 680** | PNG, RGBA | Yes |
| Enemy pose | `godot/assets/battle/<id>/<move>.png` | **600 x 560** | PNG, RGBA | Yes |
| Fight background | `godot/assets/battle/bg/<fight_id>.webp` | **1600 x 900** | webp (png/jpg also read) | No |

- **One strong pose per move.** No json is needed for a single pose. The pose is held for the whole move, and the code adds the motion: idle sway, the lunge, knockback and a white flash, a red glow and coil on wind-up, the fall on defeat, and a quick squash each time the pose changes (with a short shake on `hit`).
- **Draw every fighter facing right.** Enemies are mirrored by the code so they face the party.
- **Feet on the bottom centre of the canvas**, the figure filling the height. The pose is scaled down to fit the on-screen box, keeping its shape, and stood on the box's bottom centre.
- **Keep one canvas size for all of a character's poses.** Each pose is fitted on its own, so a pose on a different canvas would jump in size.
- **The canvases are 2x the on-screen boxes** (party 220x340, or 190x300 in the two-person fight; enemy 300x280), so the art stays sharp. Because the game scales, one set of Teo poses serves both his solo and duo fights.
- **File names are lower case**, exactly the ids and move names below. `.webp` is also read for poses, but use PNG for clean transparency.
- **Multi-frame strips are still allowed** for later polish: a horizontal strip of equal frames plus `<move>.json` such as `{"frames": 6, "fps": 10, "loop": true}` (`frame_w` defaults to the image width / frames, `frame_h` to the image height; `loop` defaults to true only for `idle`).
- **Backgrounds:** a drawn fight background is dimmed to about 62% (the placeholder panel is dimmed to 40%), so keep the middle readable but not busy: fighters stand at left and right, and the UI covers the top 70 px and the bottom 250 px.

### Character ids and moves

| Id (folder) | Who | Moves to draw |
|---|---|---|
| `teo` | Teo, with balisong | idle, attack, hit, parry, down, rise, cast |
| `pido` | Lolo Pido, with sundang | idle, attack, hit, parry, down, rise, cast |
| `kardo` | Kardo, with wrench and wires | idle, attack, hit, parry, down, rise, cast |
| `lunod` | The Drowned | idle, windup, attack, hit |
| `ligaw_berto` | Mang Berto, possessed | idle, windup, attack, hit |
| `unsent` | The creek's Unsent | idle, windup, attack, hit |
| `aswang` | The tagged aswang (boss) | idle, windup, attack, hit |
| `hiraya_hound` | The Hiraya hound (boss) | idle, windup, attack, hit |

Fallbacks when a pose is missing: `windup`, `parry` and `rise` show `idle`; `cast` shows `attack`; `down` shows `hit`; `hit` and `attack` show `idle`. Only `idle` is needed for a character to swap from its silhouette to art.

### What each move is for

| Move | Party | Enemy | When it shows |
|---|---|---|---|
| `idle` | yes | yes | Between moves (the code sways it) |
| `windup` | | yes | The enemy telegraphs its next attack (with a red glow). One pose covers all intents: the code crouches it for a lunge, shakes it for a flurry, and rears it back for a claw |
| `attack` | yes | yes | The lunge: party Attack, Wire, Discharge and counters; an enemy strike |
| `hit` | yes | yes | Taking damage; also an enemy reeling after a parry |
| `parry` | yes | | A perfect parry, and a dodge |
| `down` | yes | | The party falls (before the watch turns the round back) |
| `rise` | yes | | Standing up again after the rewind |
| `cast` | yes | | Teo's Rewind (most important in fight 4, where the watch awakens), and every ally on the defeat rewind. Held for about half a second, then back to `idle` |

### Fight ids (backgrounds)

The fight id is `ep<episode>_<enemy id>`. A flow beat can name its own with `"fight_id"`, but none do today.

| Fight | Fight id | Background file | Setting |
|---|---|---|---|
| 1 | `ep1_lunod` | `godot/assets/battle/bg/ep1_lunod.webp` | The flooded funeral parlor (look: `ep1_c01_flood_parlor`) |
| 2 | `ep1_ligaw_berto` | `godot/assets/battle/bg/ep1_ligaw_berto.webp` | The wake house at night (`ep1_30_wake_night`) |
| 3 | `ep1_unsent` | `godot/assets/battle/bg/ep1_unsent.webp` | The estero/creek at night (`ep1_34_estero_pump`) |
| 4 | `ep1_aswang` | `godot/assets/battle/bg/ep1_aswang.webp` | The creek bank under a dead streetlight (`ep1_13_aswang_fire_escape`) |
| 5 | `ep1_hiraya_hound` | `godot/assets/battle/bg/ep1_hiraya_hound.webp` | The workshop with the steel table (`ep1_24_workshop_raid`) |

With no file there, the fight uses the `ep1_12_alley_delivery` panel, as before.

## Episode 1, fight by fight

Episode 1 has five fights (`godot/data/episode1_flow.json`, beats `"type": "fight"`). Each fight has exactly one enemy actor. A group, like the Drowned or the Unsent, has to be drawn as one figure or crowd on the single enemy canvas.

### Fight 1: The flood at the parlor (cold open, parry tutorial)

- **Party:** Lolo Pido alone, a guest (`party: ["pido"]`). **Enemy:** `lunod`, "THE DROWNED" (90 HP, ghost silhouette, rim `#4fa3b8`).
- **Enemy attacks:** Grasp, Surge, and Chorus (3 rings). None is dodge-only.
- **Setting from the story:** the flooded funeral parlor (panel `ep1_c01_flood_parlor`).

| # | Item | Type | Files | Canvas, format | Transparency | Poses | Placeholder now |
|---|---|---|---|---|---|---|---|
| 1 | Lolo Pido, with sundang | Party sprite | `godot/assets/battle/pido/<move>.png` | 440x680, PNG | Yes | idle, attack, hit, parry, down, rise, cast | Teo/Renzo silhouette with a white rim (`kind: "teo"`, rim `#e8e8e8`) |
| 2 | The Drowned (a mass of hands and faces rising from flood water) | Enemy sprite | `godot/assets/battle/lunod/<move>.png` | 600x560, PNG | Yes | idle, windup, attack, hit | Ghost silhouette, rim `#4fa3b8` |
| 3 | Flooded parlor | Background | `godot/assets/battle/bg/ep1_lunod.webp` | 1600x900 webp | No | — | Placeholder panel, darkened |

### Fight 2: Mang Berto, ligaw (at the wake; teaches DODGE)

- **Party:** Teo alone. **Enemy:** `ligaw_berto`, "MANG BERTO, LIGAW" (80 HP, ghost silhouette, rim `#8a6a3a`).
- **Enemy attacks:** Reach, Flood (dodge-only), and Grief (2 rings).
- **Setting:** the wake house at night (`ep1_30_wake_night`, `ep1_31_berto_ghost`).

| # | Item | Type | Files | Canvas, format | Transparency | Poses | Placeholder now |
|---|---|---|---|---|---|---|---|
| 4 | Teo, with balisong | Party sprite | `godot/assets/battle/teo/<move>.png` | 440x680, PNG | Yes | idle, attack, hit, parry, down, rise, cast | Renzo silhouette, gold rim `#c9a24a` that whitens with utang |
| 5 | Mang Berto, possessed (jaw unhinged, brown water pouring) | Enemy sprite | `godot/assets/battle/ligaw_berto/<move>.png` | 600x560, PNG | Yes | idle, windup, attack, hit | Ghost silhouette, rim `#8a6a3a` |
| 6 | Wake house | Background | `godot/assets/battle/bg/ep1_ligaw_berto.webp` | 1600x900 webp | No | — | Placeholder panel |

### Fight 3: The creek's unsent

- **Party:** Teo alone (reuses item 4). **Enemy:** `unsent`, "THE CREEK'S UNSENT" (85 HP, ghost silhouette, rim `#3fb8a8`).
- **Enemy attacks:** Cling, Undertow (dodge-only), and Swarm (3 rings).
- **Setting:** the estero/creek at night (`ep1_34_estero_pump`).

| # | Item | Type | Files | Canvas, format | Transparency | Poses | Placeholder now |
|---|---|---|---|---|---|---|---|
| 7 | The Unsent (several drowned dead coming up out of the creek together, reaching) | Enemy sprite | `godot/assets/battle/unsent/<move>.png` | 600x560, PNG | Yes | idle, windup, attack, hit | Ghost silhouette, rim `#3fb8a8` |
| 8 | Creek at night | Background | `godot/assets/battle/bg/ep1_unsent.webp` | 1600x900 webp | No | — | Placeholder panel |

### Fight 4: The tagged aswang (boss; the watch awakens)

- **Party:** Teo alone (reuses item 4). His `cast` pose matters most here: the awakening and the first Rewind happen in this fight.
- **Enemy:** `aswang`, "TAGGED ASWANG" (140 HP, aswang silhouette, rim `#c8452e`, boss music).
- **Enemy attacks:** Claw, Lunge, Flurry (3 rings), and Drag Under (dodge-only). It has all three wind-up reads: claw, lunge and flurry.
- **Setting:** the creek bank under a dead streetlight (`ep1_13_aswang_fire_escape` for the look).

| # | Item | Type | Files | Canvas, format | Transparency | Poses | Placeholder now |
|---|---|---|---|---|---|---|---|
| 9 | Tagged aswang (boss) | Enemy sprite | `godot/assets/battle/aswang/<move>.png` | 600x560, PNG | Yes | idle, windup, attack, hit | Aswang silhouette, rim `#c8452e` |
| 10 | Creek bank, dead streetlight | Background | `godot/assets/battle/bg/ep1_aswang.webp` | 1600x900 webp | No | — | Placeholder panel |

### Fight 5: Hiraya hound (boss, Teo + Kardo)

- **Party:** Teo and Kardo (`party: ["teo","kardo"]`), both shown in the smaller 190x300 box (the same 440x680 poses, scaled).
- **Enemy:** `hiraya_hound`, "HIRAYA HOUND" (110 HP, hound silhouette, rim `#00b8d9`, boss music).
- **Enemy attacks:** Jab, Net (dodge-only), and Burst (3 rings).
- **Setting:** the workshop with the steel table (`ep1_24_workshop_raid`).

| # | Item | Type | Files | Canvas, format | Transparency | Poses | Placeholder now |
|---|---|---|---|---|---|---|---|
| 11 | Teo (duo) | Party sprite | Same as item 4: the game scales the same poses to the smaller box | — | — | — | Silhouette |
| 12 | Kardo, with wrench and wires | Party sprite | `godot/assets/battle/kardo/<move>.png` | 440x680, PNG | Yes | idle, attack (also used for Wire and Discharge), hit, parry, down, rise, cast | Dante silhouette, rim `#5aa9c9` |
| 13 | Hiraya hound (four piston legs, sunrise lens and logo) | Enemy sprite | `godot/assets/battle/hiraya_hound/<move>.png` | 600x560, PNG | Yes | idle, windup, attack, hit | Hound silhouette, rim `#00b8d9` |
| 14 | Workshop | Background | `godot/assets/battle/bg/ep1_hiraya_hound.webp` | 1600x900 webp | No | — | Placeholder panel |

(`tiyanak` is defined in `enemies.json` but doesn't appear in Episode 1.)

## Shared UI and effects (all fights)

| Item | Type | What the code does now | Art slot? |
|---|---|---|---|
| Turn-order chips (top) | Small portrait or icon | A coloured box with the unit's first letter (`_refresh_order`) | **No** |
| Intent card "NEXT ACTION" | Attack/intent icon | Text only: attack name and guard hint | **No** |
| HP / stagger / watch-energy panels | UI | Drawn bars, circles and rectangles | **No** (not needed) |
| Timing ring (PARRY / DODGE / COUNTER) | UI | Drawn circles (`timing_ring.gd`) | **No** |
| Hit sparks, slash arc, parry ring, rewind clock | Effects | Procedural lines and arcs (`fx_burst.gd`: `spark`, `slash`, `ring`, `clock`) | **No** |
| Rewind afterimages | Effect | Teal copies of the *silhouette*, even when the character has real art (`rewind_pulse`) | **No** |
| Damage numbers, "PERFECT PARRY!", banners | Text | Fonts with an outline | Not art |

## What the battle code can't show yet

Done in this prep: export loading, single poses, scaling to the box (one canvas per character), and per-fight backgrounds. Still not supported, so the art should fit these limits or wait for a later change:

1. **Enemies never play a defeat.** On victory the enemy just stays in its idle pose while the text says it breaks apart. No `down` pose is asked of enemies.
2. **One wind-up pose per enemy.** There are no per-intent wind-ups (claw, lunge, flurry); the code varies the motion instead.
3. **One enemy per fight.** Groups (the Drowned, the Unsent) are one actor, so draw them as one crowd figure.
4. **No icon, portrait or effect slots yet** (turn-order chips, the intent card, sparks, slash, parry ring, rewind clock). These come later. Rewind afterimages still use the silhouette shape, in teal.
5. **Kardo's Wire and Discharge** reuse his `attack` pose.
6. **All enemies share one box size** (300x280 on screen); a boss isn't drawn bigger.
7. **`actor.tscn` route:** a hand-built Godot scene with a `play(move)` method still takes priority over poses, for anything beyond one pose per move.

## Count by type

| Type | Count | Slot in the game |
|---|---|---|
| Party battle poses | 3 characters (Teo, Lolo Pido, Kardo) x 7 moves = **21 poses** | Yes |
| Enemy battle poses | 5 enemies (the Drowned, Mang Berto ligaw, the Unsent, the tagged aswang, the Hiraya hound) x 4 moves = **20 poses** | Yes |
| Backgrounds | **5** (one per fight id above) | Yes |
| Attack / intent icons | 16 attacks (12 parryable, 4 dodge-only) | Not yet |
| Turn-order portraits | 8 (3 party + 5 enemies) | Not yet |
| Effects | 4 (spark, slash, ring, clock) + rewind afterimage | Not yet |
| **Ready for art now** | **41 poses + 5 backgrounds** | |
