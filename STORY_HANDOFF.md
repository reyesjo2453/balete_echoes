# STORY_HANDOFF.md

Snapshot of the narrative as it stands in the Godot port (branch `ccr-d444c2c4-76rlh3`, last green CI on `807efab`). Factual only. Nothing has been rewritten for this file.

## 1. Core Premise & Tone

- **Game:** *Balete: Echoes of the Sunken Veil*. A narrative-action, episodic (teleserye-shaped) game set in rain-soaked Quiapo, Manila. Folklore horror meets debt-ridden street realism. Season title in `structure.json`: *The Sunken Veil*. Season villain: Bakunawa, the Moon-Eater, and the man who feeds it (Aurelio Velez / Aevum Filipinas).
- **Premise:** Renzo Reyes, a courier and watch-repair kid, is trying to clear family debt (Honda loan, shop rent, 5-6 lenders). His grandmother Lola Rosa hands him a pocket watch that is secretly the lock on a "door" in the city. Aevum Filipinas wants it.
- **Tone rules (from `docs/STORY.md` and `docs/EPISODIC_DIRECTION.md`):**
  - *Utang na loob* is real pressure, not a footnote.
  - Specific Quiapo detail. Slow burn. "Explain the setting, never overstate the story."
  - Anti-tropes: no chosen one, no amnesia, no revenge-for-dead-parents, no pure-evil corporation, no love triangle, no mentor death.
- **Canon revisions (STORY.md, approved Nov 8–9):**
  - The pact's cost is two-sided.
  - Velez is sympathetic.
  - The watch is a debt ledger: every use adds to the family's debt.
  - Mayari's trial tests a moral choice, not strength.
  - Lola Rosa is alive in Quiapo through Episode 1 and is taken by Aevum at the end.
- **Three line types, three bars:** `say` (spoken), `think` (inner), `narr` (narration). Rule from the Nov 10 playtest.
- **Episode shape:** 3 acts, each ending on a hook, with "Previously on" and "Next time on" cards. Target length is 60–90 min per the latest request. Current estimate is about 50 min (range 42–60).

## 2. Current Plot Beats (Episode 1, "Ang Lumang Orasan")

Order follows `episode1_flow.json`. Scene IDs are in backticks. *(if …)* marks conditional beats.

**Previously on:**
- 1898: the last watchmakers of Santa Cruz seal something in a pocket watch.
- Every clock in the Reyes shop has stood at 4:17 since.
- Tonight the seal begins to fail.

### Act 1 — "4:17" (about 20 min)
1. `stakes`: 6:02 AM. Valdez (Asian Housing & Credit Corp.) texts: Honda Beat ₱3,450, tow truck on Carriedo at noon. Lola has started packing the shop into crates.
2. `shop_morning`: the watch falls and Renzo catches it (first timing-ring lesson). Lola's hands burn on it. The catch is the first rewind: nine clocks tick once.
3. `bench`: investigate what Lola is hiding (choice).
4. `lola_tea`: Lola opens up or keeps her silence (choice).
5. `board_intro`, then the **job board**: pick the day's work, with a time budget. The church parcel is required.
6. `step_out`: start the Honda (Honda-kick QTE).
7. **Morning courier run.**
8. `job_avenida` *(if picked)*: Aling Cora, forty bolts of katsa, haggling choice.
9. `job_pandacan` *(if picked)*: Kuya Efren, compressor part, walk-in choice.
10. **Church run**, then `church_arrival`, `domeng_stall` (Mang Domeng).
11. `envelope`: deliver the parcel in the undercroft. Candles QTE. The sacristan may hear the watch; slip him ₱200 or hold his stare (timed choice).
12. **Settle (noon):** church pays ₱2,000 and costs 60 min. Pay Honda ₱3,450, or lose the bike or take +3 utang.
13. `tow_confrontation` *(if the bike is towed)*: fight Valdez's cousins *(if fight_goons)*, then `tow_after`.
14. **Noon ride home.**
15. `lola_silence`: press her or let go (choice), then `lola_pressed` or `lola_let_go`.
16. `dante_call`: a stranger warns "stay on lit streets".
17. `dusk_choice` **(big choice):** the shortcut alley or the lit road. The lit road hits an Aevum checkpoint and the watch ticks. Both roads lead to the alley.
18. `act1_hook`: Renzo takes the shortcut.

### Act 2 — "The Alley" (about 13 min, shortest act)
1. `alley_intro`: reach Bodega 9, read the invoice.
2. `alley_search`: the baker's apprentice, find the door (choice).
3. `alley_ambush`, then **Corrupted Aswang fight**. Parry tutorial. The watch awakens at about 55% enemy HP.
4. `after_fight_alley`: decide what to do with the Aevum telemetry tag.
5. `baker_return`: the apprentice's thanks.
6. `bodega_nine`: dead man Dizon (a watchmaker) at a bench. A brass key stamped 4-17. A ledger back to 1898 ending "Reyes, R. Tonight." The streetlight goes out.
7. `gate_ram`: brace QTE, then choose the van or the Honda.
8. `van_chase_intro`, **van run**, `van_talk` **(big choice):** three questions to Dante, show the watch or not, then Tondo or back to Lola.
9. `dante_tips`: Dante coaches the ring.
10. `after_fight`: Dante sees the rewind.

### Act 3 — "The Envelope" (about 16.5 min)
1. `safehouse_arrival` (Tondo).
2. `dante_story`: the flood of June 3, 1998. Lolo reversed it with the watch. It took 4:17, a length of time, and aged him ten years.
3. `envelope_open`: open the sealed envelope, or hand it over.
4. `aevum_raid`: scanner chatter, the telemetry tag, "show me the watch". Lola is taken. Her workshop is ransacked.
5. `lola_message`: Lola's taped message (choice). A place on the Pasig where the river tastes of rust.
6. `hound_intro`, **Aevum hound fight**, `hound_after`.
7. `agent_offer`: Tolentino of Aevum Custodianship offers to return Lola, forgive the lease and settle Valdez's debt for the watch (choice).
8. `tiyanak_intro`, **tiyanak fight**, `tiyanak_after`: it spoke in Lola's voice.
9. `act3_big` **(big choice):** Quiapo now, or plan with Dante for an hour. Dante gives a taser. Aevum's transport to Taguig leaves at midnight.
10. `cliffhanger`: the watch stops on a time that hasn't happened yet. "AGUSAN, 1898" is etched in the backing plate.
11. **End card:** stats and "Next time on". Calls `Progress.complete_episode`.

**Next time on (as written):** a sacristan who heard too much, a lender's envelope saying the shop is next, a watch that runs backward in a dead man's pocket. Tagged "Episode 1, Act 3: The Envelope."

**Choice effects** are data-driven (`effects` in scene JSON): loob, trust, money, injury, spend, utang, minutes, flags, remember, banner.

## 3. Character Roster

| Character | Motivation now | Appears in |
|---|---|---|
| **Renzo Reyes** (protagonist) | Clear the debt, keep the shop, find out what Lola hid. After Bodega 9 and the raid he wants Lola back. Loob (inner resolve) is tracked. | Every scene |
| **Lola Rosa** | Keep Renzo out of the pact and away from Aevum. She is packing to leave. She refused Aevum 11 times, was taken, and left a tape. | `shop_morning`, `lola_tea`, `lola_silence`, `lola_pressed`, `lola_let_go`, `agent_offer` (mentioned), `lola_message` (voice) |
| **Dante** (mechanic, Tondo) | Honor Lola's "when the boy needs you." Keeps the river off her door. Distrusts the old arrangement. Taser/wrench ally. | `dante_call`, `gate_ram`, `van_chase_intro`, `van_talk`, `dante_tips`, `after_fight`, all Act 3 scenes |
| **R. Valdez** (lender, Asian Housing & Credit) | Collect ₱3,450 or tow the Honda. Never threatens, "he schedules." His cousins fight. | `stakes` (text), `tow_confrontation`, `tow_after` |
| **Mang Domeng** (candle/herb vendor) | Knows more than he says. Ties to the church envelope. | `domeng_stall`, `envelope` |
| **The Sacristan** | Hears things in the undercroft. Bribable. | `envelope` |
| **Dizon** (dead watchmaker) | Waited for "the heir." Ledger keeper from 1898. | `bodega_nine` |
| **Baker's apprentice** | Bystander Renzo helps. | `alley_search`, `baker_return` |
| **Aling Cora, Kuya Efren** | Job-board clients. | `job_avenida`, `job_pandacan` |
| **Tolentino** ("Aevum guard") | Polite Aevum negotiator. Wants the watch. | `agent_offer` |
| **Enemies** | Corrupted Aswang (Act 2 boss), Aevum Hound, Tiyanak, Valdez's cousin (`collector_goon`). | `godot/data/enemies.json` |
| **Aevum Filipinas** (faction) | Harvests spirits, runs port and grid security, tags creatures. | Throughout |
| **Planned, not in Episode 1** | Tala (museum archivist), Mayari (moon-spirit), Aurelio Velez, Bakunawa. | `docs/STORY.md` only |

## 4. File Map

**Dialogue and quest data (live game, `godot/data/`)**
- `episode1.json`: legacy scenes exported from the old TS (`shop_morning`, `lender_runner`, `board_intro`, `step_out`, `envelope`, `lola_silence`, `lola_pressed`, `lola_let_go`, `tondo_safehouse`, `cliffhanger`).
- `episode1_extra.json`: the 32 expansion scenes. **Generated** by `tools/build_episode1_extra.py`; edit the script, not the JSON.
- `slice_opening.json`: `stakes`, `dante_call`, `alley_arrival`, `after_fight`, `act1_hook`.
- `episode1_flow.json`: act and beat order, goals, conditions, run and fight parameters. Generated by `tools/build_episode1_extra.py`.
- `structure.json`: season, episode and act titles, hooks, "Previously on" and "Next time on".
- `enemies.json`: enemy lines, opening and victory text, attacks.
- `party.json`, `skills.json`, `amulets.json`: party and progression.
- `build.json`: commit stamp written by CI.
- Scene lookup order: `episode1_extra` → `episode1` → `slice_opening`.

**Logic (`godot/scripts/`)**
- `story.gd`: state, choice effects, flags, conditions, scene lookup.
- `main.gd`: flow driver, cards, job board, settle, end card.
- `dialogue.gd`: bars, choices, QTE.
- `combat.gd`, `battle_model.gd`: battle.
- `courier_run.gd`: rides.
- `progress.gd`: save.

**Tooling:** `tools/export_story.ts` (legacy to JSON), `tools/build_episode1_extra.py`, `tools/estimate_playtime.py`.

**Lore and design docs (`docs/`)**
- `STORY.md`: full season bible (8 chapters, 3 endings, canon revisions, character wants and clashes). 398 lines.
- `EPISODIC_DIRECTION.md`: pivot, Episode 1 shape, playtest direction (three bars, QTE teaching, earned watch), open questions.
- `GAME_DESIGN_DOCUMENT.md`: original prologue flow, combat systems (partly legacy).
- `ROADMAP.md`: Nov 10 polish list, **partly stale**.
- `MERLIN_PROMPTS.md`, `ASSET_MANIFEST.md`, `ASSET_PIPELINE.md`, `renzo-front-back-art-spec.md`: art pipeline.
- `SCAFFOLD.md` (root), `godot/README.md`: build notes.

**Legacy:** `web-legacy/src/narrative/` (`Episode1Script.ts`, `Scenes.ts`, `Episodes.ts`, `DispatchState.ts`, `TutorialScene.ts`) is the original TypeScript source, kept for reference.

## 5. Known Disjointed Areas

**Continuity and lore**
1. **Year math.** `van_talk` says the watch "has not ticked forward in twenty-six years", but `dante_story` dates the flood to June 3, 1998. With the game set in 2026 that is 28 years.
2. **Agusan vs Santa Cruz.** The "Previously on" card says the last watchmakers of **Santa Cruz** sealed the watch in 1898. The cliffhanger etches **"AGUSAN, 1898"**, which is a Mindanao province and is never explained.
3. **4:17 has two meanings.** It is the time the shop clocks stopped, Dizon's key number, and, per `dante_story`, the 4 min 17 s duration of the flood reversal. All are used, but the reveal comes only in Act 3.
4. **"Next time on" refers to things already seen.** The sacristan, the lender envelope and the dead man's watch all happen in Episode 1. The card reads like a recap.
5. **Cliffhanger is soft.** "A time that hasn't happened yet" and AGUSAN are teased with no hook into the Taguig rescue plan.
6. **Rewind rule is inconsistent.** Dante says the watch ticks backward to keep the door locked and forward to open it. The game also uses the backward tick as Renzo's rewind power, and it costs nothing in Episode 1. STORY.md says every use adds to the family debt. The debt-ledger cost is not shown.

**Party and design mismatches**
7. **Dante's combat role.** `party.json` has Dante joining at **Episode 3**. STORY.md Ch. 1 says he joins the formation in Episode 1. `act3_big` gives him a taser and a team plan, but he is not playable in Episode 1.
8. **Prologue vs Episode 1.** STORY.md still describes the prologue as the Quiapo Ambush with a Crown Pull and Dante's van extraction, and Act I as Tala at the museum. Episode 1 now covers the prologue and Chapter 1.1 (Tondo safehouse). Tala and the museum are untouched.
9. **Enemy roster.** The hound and tiyanak are new for Episode 1. Neither is in STORY.md. `tiyanak_after` implies "third one this month" and "Tondo is becoming…" with no payoff. The tiyanak using Lola's voice has no follow-up.

**Pacing and transitions**
10. **Act 2 is thin** (about 13 min against a 20–30 target) and is mostly an alley, a body and a van ride. Total length is about 50 min against a 60–90 min target.
11. **Abrupt tone shifts.** Act 2 ends right after the Aswang and the van chase. Act 3 opens straight in the safehouse with little rest.
12. **Three fights in Act 3's back half.** Hound, offer, then tiyanak with no breather. Act 2's fight is the only one tied to the watch awakening.
13. **Lola is absent from Act 2 and Act 3 except as a voice.** Her confrontation is deferred, and `lola_message` hands Renzo a Pasig lead that Episode 1 never follows.
14. **Conditional branches leave stray state.** The `lola_pressed` / `lola_let_go`, tow, fight and job branches reconverge cleanly. Flags like `msg_vow` and `agent_*` are set but little is read later.
15. **Orphan scenes.** `alley_arrival`, `lender_runner` and `tondo_safehouse` exist in the data but are not in the flow. `after_fight` and `act1_hook` in `slice_opening.json` are shadowed by `episode1_extra.json`.
16. **Aevum raid reuses older lines.** `aevum_raid` carries the old Tondo-gin dialogue ("show me the watch") and now opens Act 3's mid-section. The tone is slightly off after `dante_story`.

**Docs and assets**
17. `docs/ROADMAP.md` still reads as pre-Godot (mentions `ep1_06b`, old combat).
18. Four held Merlin panels are still placeholders. The stopped-clocks panel does not show 4:17 on every clock.
19. The amulet and Episode 2 chooser exists only as data and save fields, with no UI.
