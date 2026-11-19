# Art shot list — Episode 1, "Ang Lumang Orasan"

Hand-maintained for the Godot build (the old generated list came from `web-legacy` and described the previous story).
Files go in `godot/assets/comics/<id>.webp` (panels) and `godot/assets/portraits/<file>.webp` (portraits). A missing
panel shows a labelled `[ art slot: <id> ]` in game, so art can drop in at any time. Style rules:
`docs/ASSET_PIPELINE.md` (ink outlines, flat cel colour, halftone; teal `#00ffcc` only as an accent).

**Panels: 26 drawn for Episode 1 (OpenArt, GPT Image 2.5; credits and licence caveat in `godot/assets/comics/CREDITS.md`). `ep1_01`, `ep1_12`, `ep1_16`, `ep1_17` are still old placeholders.**

## Portraits (512×512): reused, briefs updated

The files keep their old names; `scripts/art.gd` maps the cast to them (`PORTRAIT_ALIAS`). Redraw to the new briefs
when there is time.

| File | Character | Brief |
|---|---|---|
| `renzo.webp` | **Teo Dimaculangan**, 20 | Lean, tired eyes, rain-damp hair, plain black jacket over a funeral-parlor polo (embroidered "DIMACULANGAN"). Guarded half-smile. Later: a white streak at the left temple (stage 1), greying (2–3), white (4). The game greys the portrait in code meanwhile. |
| `lola.webp` | **Lola Ising**, 75 | Small, silver hair in a bun, cardigan over a housedress, reading glasses pushed up on her forehead, rosary. Warm face that gives nothing away. |
| `dante.webp` | **Kardo Bagwis**, 53 | Heavyset, short grey beard, embalmer's coveralls, a coil of copper jumper wire over one shoulder, old electric-company ID on a lanyard. |
| `mang_domeng.webp` | **Mang Domeng** | Unchanged: elderly candle vendor, faded cap, wax-spotted apron. |
| *(new)* `pido.webp` | **Lolo Pido**, 1998, ~51 | Lean, black panyo around the left wrist, sundang in hand, soaked to the chest. |
| *(new)* `obet.webp`, `benitez.webp`, `celeste.webp` | Kapitan Obet, Atty. Benitez, Celeste | Pressed barong and a smile; a soft-spoken lawyer in grey; a woman of 28 in a white suit with a white streak at her left temple. Add to `PORTRAIT_ALIAS` / the generator's `PORT` when drawn. |

## Panels (1600×900, 16:9; bottom 28% is under the dialogue bar)

### Episode 1 panels (in `godot/assets/comics/`; redrawn except where noted)
| Id | Used for |
|---|---|
| `ep1_02b_stopped_clocks` | The parlor's nine clocks stopped at 4:17 (cold open, the watch catch) |
| `ep1_03_lola_packing` | Lola at the aparador, boxes for Vigan |
| `ep1_07_mang_domeng` | Mang Domeng at the wake |
| `ep1_10_lola_tea` | Lola on the stairs (answers, the 2:40 hook) |
| `ep1_13_aswang_fire_escape`, `ep1_14_renzo_shock`, `ep1_15_renzo_cornered` | The aswang drops at the estero |
| `ep1_19_gate_brace`, `ep1_18_dante_krash` | Kardo's truck rams the gate (redraw the van as a bucket truck later) |
| `ep1_23_aevum_chatter` | Benitez's call, the hound (redraw with Hiraya's rising-sun logo later) |
| `ep1_24_workshop_raid` | The parlor after the raid |
| `ep1_25_watch_future` | The watch showing a time (Lola's 2:40, her blank dial, Teo's date) |

### Drawn (new ids; briefs kept for redraws)
| Id | Scene | Brief |
|---|---|---|
| `ep1_c01_flood_parlor` | Cold open, 1998 | A funeral parlor's viewing room waist-deep in brown floodwater at 4 AM; two coffins floating; drowned faces rising; Lolo Pido stepping down into the water with a sundang and a black panyo on his wrist; young Ising with a baby on the stairs; young Kardo in a lineman's harness. |
| `ep1_c02_pido_rewind` | Cold open | The water pouring backward down the stairs and out the door; Pido at the centre holding the open watch, his hair turning white; a single teal glow. |
| `ep1_c03_downriver` | Cold open | Santa Ana at night: a wall of water hitting riverside houses; a boy of 17 in a school uniform on a roof, screaming. |
| `ep1_30_wake_night` | The wake (hub) | A Quiapo funeral parlor at night: white coffin, flower stands with ribbons, monobloc chairs, coffee urn, a tong-its table; the neon sign outside with two dead letters. Warm gold light. |
| `ep1_31_berto_ghost` | The wake | A jeepney driver's ghost in his cap sitting beside his own coffin, water running from his sleeves, edges darkening; the mourners asleep. |
| `ep1_32_obet` | The wake | Kapitan Obet in a pressed barong at the door, sympathy envelope in one hand and a folder in the other. |
| `ep1_33_hatid_boat` | The send-off | A narrow boat with a lantern on its prow in the parlor doorway, a cloaked ferrywoman who does not step off; the driver walking toward it. |
| `ep1_34_estero_pump` | The estero (hub) | A concrete creek under squatter houses at 2 AM, water too high; a new pumping station with a rising-sun logo (HIRAYA ENERGY) behind chain-link; faint blue glow in the water. |
| `ep1_35_dead_sundo` | The pump house | An old man in a folding chair, black panyo on the wrist, a cracked string of balete beads, a ledger on his lap; one bulb. |
| `ep1_36_white_streak` | After the aswang | Teo's reflection in black water: a fresh white streak at his left temple. |
| `ep1_37_kardo_truck` | Kardo's truck | Inside an old electric-company bucket truck at night: Kardo driving, Teo in the passenger seat, rain, dashboard glow. |
| `ep1_38_morgue` | Act 3 | The parlor's basement embalming room: steel table, formaldehyde shelves, a radio, a jeepney seat bolted to the wall, a small TV in the corner. Cold fluorescent light. |
| `ep1_39_photo_liwayway` | The photograph | An old photo in a plastic sleeve: young Ising on flood-stained stairs holding a baby girl; handwriting on the back. |
| `ep1_40_celeste_tv` | Cliffhanger | A TV in the morgue showing a press conference: Gregorio Villacorta at a podium; beside him Celeste in a white suit, tucking her hair behind her ear to show a white streak. |

## Battle art
Battle actors are code-drawn silhouettes until art lands (`godot/assets/actors/<id>/`, see `scripts/battle_actor.gd`):
`teo`, `kardo`, `pido` (party); `lunod`, `ligaw_berto`, `unsent` (ghost shape), `aswang`, `hiraya_hound` (enemies).
