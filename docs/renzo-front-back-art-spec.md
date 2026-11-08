# Renzo front/back sprite art spec (Gemini)

Needed for issue #3. `Player` already selects these clips and falls back to the side clips until they exist in `renzo_sheet.json`.

## Sheet change
- Same cell size: **320 x 305 px**, 7 columns, transparent background, same scale and feet baseline as existing cells (feet at `groundFraction` 0.949 of cell height, figure about 0.847 of cell height) so Renzo does not change size.
- Grow the sheet from 9 to **13 rows** (2240 x 3965 px). Existing cells 0-62 stay untouched. New cells are row-major from index 63 (row 9, col 0), with no gaps. 28 new frames fill rows 9-12 exactly.
- Armed Renzo (balisong, same outfit and palette as the side `idle`/`walk`). Not mirrored in code: draw the real figure.
- Front = facing the camera (south, +Z). Back = facing away (north, -Z).

| clip     | start | count | fps | loop | pingpong | cells |
|----------|-------|-------|-----|------|----------|-------|
| `idle_f` | 63    | 6     | 5   | yes  | yes      | 63-68 |
| `walk_f` | 69    | 8     | 8.2 | yes  | no       | 69-76 |
| `idle_b` | 77    | 6     | 5   | yes  | yes      | 77-82 |
| `walk_b` | 83    | 8     | 8.2 | yes  | no       | 83-90 |

Walk cycles: 8 frames, stride pace matching the side walk (WALK_REF_SPEED 2.4 m/s).

## Manifest entries to add (and set `"rows": 13`)
```json
"idle_f": { "start": 63, "count": 6, "fps": 5,   "loop": true, "pingpong": true  },
"walk_f": { "start": 69, "count": 8, "fps": 8.2, "loop": true, "pingpong": false },
"idle_b": { "start": 77, "count": 6, "fps": 5,   "loop": true, "pingpong": true  },
"walk_b": { "start": 83, "count": 8, "fps": 8.2, "loop": true, "pingpong": false }
```
Also regenerate `renzo_sheet_n.webp` / `renzo_sheet_r.webp` (scripts/generate-sprite-normals.ts) at the 13-row size.

Not covered (stay side view): slash, hurt, dodge, down, and the unarmed `_u` clips.
