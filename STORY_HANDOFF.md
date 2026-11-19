# STORY_HANDOFF.md

Snapshot of the narrative after the Nov 11, 2026 reboot (branch `ccr-d444c2c4-76rlh3`), refreshed Nov 17 and Nov 19. Factual only.
**For the engineering handoff (how the game is built now, workflow, open items) read `HANDOFF.md` first.**
The previous version of this file described the old draft (Renzo, Dante, Aevum, the courier day); that draft is retired.

## 1. Premise and tone
- **Game:** *Balete: Echoes of the Sunken Veil*. Episodic narrative-action: comic-book story, Expedition 33–style
  turn-based combat with real-time parry and dodge, case hubs between. Season 1: *The Sunken Veil*, 8 episodes.
- **Premise:** the Dimaculangans run a funeral parlor in Quiapo and are hereditary **sundô** who walk the dead home.
  Lolo Pido's watch, cut from Sidapa's balete, borrows time and writes it against the family. Teo, 20, inherits it
  the night his grandmother is taken by Hiraya Energy, a green-power company that bottles unsent souls.
- **Theme:** everything is borrowed, and every debt gets collected.
- **Tone rules:** *utang na loob* is real pressure; specific Quiapo detail; explain the setting, never overstate the
  story; no chosen one, no amnesia, no dead-parents revenge, no pure-evil corporation, no love triangle, no mentor death.
- **Canon:** `docs/STORY.md`. **Shape and systems:** `docs/EPISODIC_DIRECTION.md`.

## 2. Episode 1, "Ang Lumang Orasan" (order of `episode1_flow.json`)
**Prologue (cold open), 3 June 1998:** `co_flood` → fight (Lolo Pido vs the drowned, guided parry) → `co_wave` → fight (the
tide: hold the stairs three turns) → `co_rewind` (4:17, Pido ages ten years; the knocking coffin is gone; choice) →
`co_downriver` (the water comes down on Santa Ana, how is left a mystery; the Villacorta boy holds his father's hand
until the parlor's coffin, riding the flood, breaks the grip; a knock at dawn) → title card.

**Act 1, "Lamay" (Chapter 1):** `hidalgo_arrive` → **the walk in** (Hidalgo Street, nothing required: Mang Isko, and
Mang Andoy under the balete as an optional visible fight) → `lamay_open` (the wake; ignore or nod at the ghost) → `debt_notice` (Kapitan Obet) → **hub: the
wake** (`hub_nena`, `hub_coffin`, `hub_domeng`, `hub_cards`; two needed) → `berto_ghost` (promise or refuse) →
`lola_watch` (catch QTE; Teo becomes the bearer) → `berto_turns` (oil QTE; Lola comes down to fight beside him) → fight
(Mang Berto, ligaw; Teo and Lola: ORASYON, and she calls Lolo Pido's ghost)
→ `hatid` → `lola_answers` (**big choice 1**: the watch / leaving / Lolo) → `act1_hook` (Lola's time: 2:40).

**Act 2, "Ang Sundô" (Chapter 2, ~22 min):** `two_forty` (Teo offers to stay; Lola wants him out) (salt or open door) → `estero` (route choice) → **hub: the estero**
(`hub2_tess`, `hub2_celso`, `hub2_guard`; one needed) → `creek_rises` → fight (the creek's unsent) → **Chapter 3 card (~31 min)** → `dead_sundo`
(Mang Ambo Salonga, who came to send the creek's dead and borrowed to nothing against the pump; send him or take the ledger) → `aswang_drop` → fight (the tagged aswang; the watch awakens, then the aswang turns: ANG GUTOM; first
white streak) → `after_aswang` (the tag) → `gate_ram` (brace QTE; **big choice 2**: Lola or the van) → `truck_talk`
→ `parlor_taken` (Lola gone; her time blank).

**Act 3, "Utang" (Chapter 4, ~41 min):** `morgue` → `kardo_1998` (Santa Ana; the coffin's brass plate; Pido at the same grave every 3 June) → `tape` (Lola's plan; reply) → `the_offer` (**big choice
3**: refuse / proof / yes) → `hound_in` → fight (Hiraya hound, with Kardo) → `after_hound` (the vial: free or keep)
→ `dawn` (5:40; Kapitan Obet's betrayal) → `photo` (upstairs; Liwayway) → `cliffhanger` (6:17 AM; Teo's date: the eclipse,
47 days; a replay of last night's press conference: Celeste with his white streak) → end card ("Abangan...", what was remembered, next time).

**Choice memory:** 64 story flags; every one is read by a later scene, a recap line or the code (plus `seen_<scene>`,
set as each scene ends, for the recap) (e.g. the hub clues, the salt line, `has_tag`, the
promise to Berto, Teo's question to Lola, the chased van, the offer). Effects: `flags`, `loob`, `bond`, `utang`,
`injury`, `remember`, `banner`. QTEs set `<id>_ok` / `<id>_miss`.

**Saves:** every beat (card, scene, hub, fight) and every return to a hub menu is a checkpoint (`Story.checkpoint`,
`user://balete_run.json`), written again when the app goes to the background. The title offers "CONTINUE: CHAPTER N"
above "START OVER"; continuing plays a skippable "Previously on Balete" (the flow's `recap` lines whose flags are set,
latest six) and resumes at the start of that beat. Quitting mid-fight restarts the fight with the same injuries.

**Music:** by cue (`data/music.json`: title, wake, tension, battle, boss, sting), crossfaded; beats and steps name a cue
(`music=`), `"silence"` for big beats. Credits and how to swap tracks: `godot/assets/bgm/CREDITS.md`.

**The watch's rule (Nov 19):** pointed at a person it shows when their time stops being their own: death, or a
collector taking them. Lola's 2:40 is the minute Hiraya takes her; her blank dial means her time is held in someone
else's ledger; Teo's date is Laho, collection day. Lola says it plainly in `lola_answers`.

## 3. Cast
| Character | Want now | Episode 1 |
|---|---|---|
| **Teo Dimaculangan** (20) | Keep the parlor, keep his head down; after 2:40, get Lola back | Everywhere |
| **Lola Ising** (75) | Cut the family loose from the ledger; decoy Hiraya to Vigan | Act 1; the tape; a photo |
| **Kardo Bagwis** (53) | Protect the family as Pido asked; free power for the poor, not from Hiraya | Cold open (young), Acts 2–3; guest in the hound fight |
| **Lolo Pido** (1998) | Hold the flood | Cold open (playable) |
| **Kapitan Obet** | Collect; sold the paper and signed the pump permit | Acts 1, 3 |
| **Mang Berto, Aling Nena, Jun-jun** | The case of the week | Act 1 (+ a text in Act 3) |
| **Aling Tess, Tanod Celso, the Hiraya guard** | The estero | Act 2 hub |
| **Mang Ambo Salonga** | (dead) the Tondo sundô | Act 2 |
| **Atty. Benitez** | Buy the watch, carry the debt | Act 3 |
| **Gregorio Villacorta, Celeste Villacorta (Liwayway)** | LIWANAG free power; the season's rival and Teo's sister | Cold open (boy), cliffhanger |
| **Enemies** | The drowned (`lunod`, `lunod_tide`), Mang Berto ligaw (`ligaw_berto`), the creek's unsent (`unsent`), tagged aswang, Hiraya hound; optional: Mang Andoy (`magbabalot`) on Hidalgo Street | `godot/data/stage_enemies.json` |

## 4. File map
- **Script (edit this):** `tools/build_episode1.py` → generates `godot/data/episode1.json` (scenes) and
  `godot/data/episode1_flow.json` (beats: card, act_card, scene, hub, fight with optional `party`).
- **Data:** `structure.json` (titles, hooks, next time), `enemies.json` (attacks; `dodge: true` = cannot be parried),
  `party.json` (Teo, Kardo, guest Lolo Pido; commands and labels), `skills.json`, `amulets.json`.
- **Logic:** `story.gd` (state, effects, aging), `main.gd` (flow, cards, hubs, end card), `dialogue.gd` (bars,
  choices, QTEs, grey portrait), `stage_battle.gd` + `special_gauge.gd` (fights; `combat.gd`/`battle_model.gd` are
  the retired full-screen system), `explore_map.gd` (maps, staging), `levels.gd` + `case_closed.gd` + `progress.gd` (save, levels).
- **Tools:** `tools/estimate_playtime.py` (CI prints it: ~65 min, range 55–78).
- **Docs:** `docs/STORY.md`, `docs/EPISODIC_DIRECTION.md`, `docs/ASSET_MANIFEST.md`, `docs/ROADMAP.md`.
- **Legacy:** `web-legacy/` holds the retired draft; reference only.

## 5. Known open items
See `HANDOFF.md` section 8 (current). The old list here (silhouette battle actors, ~54 min, undrawn panel slots) is
out of date: the battles use pixel sprites, Episode 1 is ~65 min, and the panels were cut to 13.
