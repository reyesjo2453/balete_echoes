# Explore-map art (the 2.5D wake and estero)

Sprites made with OpenArt (GPT Image 2.5 Sunburst) on the Starter plan: **not cleared for commercial release.**
Source images: `https://cdn.openart.ai/openart-ai/production/2026-11/create-image/VmKWQUD0VaN1RAcbdWVV/gpt-image-2.5-sunburst-<code>.png`
Each sheet was drawn large on flat magenta and turned into true low-resolution pixel sprites with
`tools/pixel_sprites.py` (magenta keyed, box-downsampled, hard alpha, reduced palette).

| Files | Sheet | How | Source code |
|---|---|---|---|
| `teo_walk` (12 frames: toward, right, away x 4) | 4x3 walk sheet, reference `battle/teo/idle` + the old side-view walk | `pixel_sprites.py walk SHEET teo_walk.png --height 64` | `edit-1_1794443985692_cdf71a26` |
| `nena`, `domeng`, `berto` (+ `_b` breathing frames) | 4x2 cast sheet, references from the earlier wake art | `cells SHEET 4 2 ... --height 70` | `edit-1_1794443991172_746bdaa0` |
| `casket`, `candles`, `wreath`, `chair`, `cardtable`, `urn`, `portrait`, `crucifix`, `fan`, `palm`, `abuloy`, `chairs` | 4x3 wake prop sheet | `cells SHEET 4 3 ... --height 60` | `1_1794443991052_bce15c39` |
| `tess`, `celso`, `guard`, `cards_a`, `cards_b` (+ `_b`) | 5x2 cast sheet, styled after the Teo sheet | `cells SHEET 5 2 ... --height 70` | `edit-1_1794444152491_e4679e50` |
| `house_a`, `house_b`, `steps`, `fence`, `hiraya_sign`, `pumphouse`, `lamp`, `drum`, `tires`, `ladder`, `wirepole` | 4x3 estero sheet, styled after the wake props (the sari-sari store cell was left out: real brand logos on its sign) | `cells SHEET 4 3 ... --height 150` | `edit-1_1794444161814_2a90998b` |

`tex_*.png` (floors, walls, wood, concrete, water) are drawn by `tools/pixel_textures.py`: no outside source.

### Hidalgo Street and the retro battle (November 2026)

Uploaded references: the earlier Teo walk sheet, the estero cast sheet and the estero prop sheet.

| Files | Sheet | How | Source code |
|---|---|---|---|
| `obet`, `ising`, `balut`, `trike`, `kid` (+ `_b`) | 5x2 Hidalgo cast sheet | `cells SHEET 5 2 ... --height 70` | `edit-1_1794530539418_bfc84c0a` |
| `parlor_front`, `tricycle`, `sarisari`, `balete`, `wreath_stand`, `chairstack`, `trash`, `dog`, `drain`, `candle_table`, `bench`, `shutter` | 4x3 Hidalgo prop sheet (`wreath_stand` trimmed of a stray strip of the cell above; `drain` unused) | `cells SHEET 4 3 ... --height 160` | `edit-1_1794530547871_bd4ecb7f` |
| `teob_ready`, `teob_slash`, `teob_pray`, `teob_burst`, `teob_guard`, `teob_hurt`, `teob_down`, `teob_win` | 4x2 Teo battle-pose sheet (side view, facing left) | `cells SHEET 4 2 ... --height 64` | `edit-1_1794530552749_fe87237b` |
| `mag_idle`, `mag_idle_b`, `mag_tell`, `mag_wail`, `mag_claw`, `mag_hurt`, `mag_calm`, `mag_fade` | 4x2 Mang Andoy (ligaw) battle sheet (facing right) | `cells SHEET 4 2 ... --height 92` | `edit-1_1794530549762_73488a21` |
| `pidob_*`, `kardob_*` (ready, slash, pray, burst, guard, hurt, down, win) | 4x4 Lolo Pido + Kardo battle sheet (facing left; Kardo's pray = wire throw, burst = discharge) | `cells SHEET 4 4 ... --height 64 / 63` | `edit-1_1794536680797_dd258202` |
| `lunod_*`, `lberto_*` (idle, idle_b, tell, wail, claw, hurt, calm, fade) | 4x4 the drowned + Mang Berto ligaw battle sheet (facing right) | `--height 100 / 90` | `edit-1_1794536683887_d8f87fbe` |
| `unsent_*`, `aswang_*` | 4x4 the creek's unsent + tagged aswang battle sheet | `--height 84 / 112` | `edit-1_1794536685120_f9c4652f` |
| `hound_*` | 4x2 Hiraya hound battle sheet | `--height 96` | `edit-1_1794536676141_f502a02f` |
