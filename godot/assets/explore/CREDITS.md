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
