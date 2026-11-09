# Balete: Episodic Direction — Narrative-Action, Telltale/Dispatch Shape

**Status:** Approved by John (creative director), Nov 8, 2026.
**Companion docs:** `docs/GAME_DESIGN_DOCUMENT.md` (core systems, combat, world) and
`docs/STORY.md` (full story bible, 8 chapters, 3 endings). This addendum changes the
*shape* of the game, not the story — the story, characters, and endings in STORY.md
stand as written, including the Nov 8 no-tropes expansion.

## The pivot, in one paragraph

Balete becomes an **episodic narrative-action game**: a Telltale/Dispatch-shaped
story game with a real game underneath. Each chapter of the story is an episode,
released one at a time. The player drives the story through choices that cost
something, and plays the consequences out in the field — courier runs, time
pressure, and combat — instead of watching a movie with buttons. The comic-book
art direction (Dispatch-inspired: ink outlines, flat cel color, halftone) applies
to everything: environment, cutscenes, and UI.

## What stays

- **The story.** Prologue + Acts I–III, 8 chapters, 6 bosses, the three endings
  (Ang Bagong Pacto canon). The morally grey Aevum, the two-sided Kasunduan, the
  watch as a debt ledger — all of it.
- **The combat.** Command wheel, Agimat (Apoy Blade, Lunas, Guard), Giting /
  Bayanihan Strike, stagger breaks, the Aswang fights. This is the challenging
  field layer. It is not being removed or simplified away.
- **The world and characters.** Renzo, Dante, Tala, Mayari, Quiapo, Fort Santiago,
  Mount Banahaw. The 2.5D billboard presentation.
- **The Resolve Metric (Loob).** Choices feed a real metric that drives which of
  the three endings the player earns. This is the antidote to "illusion of
  choice" — the knock on Telltale-style games.

## What changes

- **Episodes, not one big map.** The 8 chapters map to episodes. Episode 1 is
  the Prologue + Chapter 1 — the Quiapo alley slice that is already built.
  Each episode is a bounded, shippable unit: a few authored scenes, a dispatch
  day, field encounters, and a cliffhanger ending. Episodes release one at a
  time, when each is done — they do not grow.
- **Exploration and progression stay — they are the game between the story
  beats.** Each episode has real explorable space (the Quiapo alley and its
  corners, shops, side streets) with things to find — hidden Agimat, lore,
  people to talk to — and Renzo grows across episodes: new Agimat, stronger
  commands, gear, and the watch itself changing as the debt grows.
  Exploration is focused, not open-world: every corner has a reason to be
  there, but the player is free to poke around, get lost a little, and be
  rewarded for it. Wandering without purpose goes; wandering with curiosity
  stays.
- **Choices with a clock and a cost.** Some decisions are timed (the watch is
  literally about time pressure). Rewinding a choice, healing, and Agimat use
  all draw on the same ledger: the family debt. Spend it down and something
  gets collected.
- **QTEs in the big moments.** Cutscene set-pieces get quick-time beats — the
  gate ram is the first one. Fail a QTE and the scene plays out worse (injury,
  debt, lost time), not "game over, try again."
- **Cutscenes go full comic-panel.** The motion-comic system becomes panel
  framing, speech bubbles, onomatopoeia, and panel wipes (see Issue #19 for
  the Dante scene). No more camera-swoop cutscenes that look like a different
  game from the characters.

## The signature mechanic: the dispatch board

Renzo is a courier. Each episode opens on a **dispatch board**: a day of
deliveries and debts. The player chooses which jobs to take, who to pay, and
what to risk. Every job costs time; every choice costs something — money,
standing, safety, or ledger debt. The watch lets the player rewind a bad call,
but the ledger charges for every rewind. This is the game's unique play style:
part route-planner, part debt manager, part time gambler — and the field
encounters (deliveries gone wrong, Aswang, Aevum) are where those choices
cash out. The board is the loop; the story is the reason to keep playing it.

## Combat: turn-based with active parry (Expedition 33-inspired, approved Nov 8, 2026)

Combat becomes **phased turn-based with real-time defence**, in the shape of
Clair Obscur: Expedition 33. The watch is the parry — it bends time, so the
parry is the watch doing what the story says it does.

- **Player phase:** pick from the command wheel (Attack, Agimat, Guard, Lunas)
  — already built, unchanged in concept.
- **Enemy phase:** the enemy telegraphs (wind-up, glint, sound cue), then
  strikes. The player answers with **Dodge** (safe, no reward) or **Parry**
  (tight timing window, big reward). A perfect parry stops time for a beat
  and opens a counter — that is where the Giting strike lives. Parries build
  stagger; the existing stagger break (2.0x for 4s) is the payoff.
- **The watch as the parry meter.** A perfect parry spends a little watch
  charge; a failed parry costs health and time. Leaning on the watch grows
  the ledger debt — the same economy as the story: power now, price later.
- **Touch tuning (mandatory).** Parry windows on touch must be generous and
  readable: big telegraphs, a sound cue before the strike, and a window that
  forgives a slightly early tap. Expedition 33 is tuned for controllers; this
  game must feel fair on a foldable.
- **Test bed:** the Aswang dummy fight. One enemy, one parry window — tune
  the feel there before the system goes anywhere else.
- **Sequencing:** this is Phase 2, after the episodic scaffolding (Issue #22).
  Do not land it on top of that restructure. The existing pieces already
  point this way — the command wheel is the player phase, time dilation is
  the parry window, stagger is the reward loop — so this is a restructure of
  the combat flow, not a rebuild from zero.

## Episode structure (target)

- **Length:** roughly 45–60 minutes per episode (to be confirmed in playtesting
  Episode 1).
- **Shape per episode:** cold open → dispatch board (the day's choices) →
  field scenes (explore / combat / story beats) → set-piece (QTE) → cliffhanger.
- **Release:** one episode at a time, in story order. Episode 1 first; nothing
  is held back for a "complete" launch.

## Episode 1 — scope and shape (approved Nov 8, 2026)

Episode 1 is bigger than the current Quiapo slice — the slice is the field core,
not the whole episode. The Aswang attack in Quiapo needs backstory unfolding
around it, before and after, or the attack is just a fight. Principle:
**explain the setting, never overstate the story.** The player learns Quiapo by
living in it (deliveries, the shop, the lenders, the church, the rain) and
learns the story by guessing — every answer opens a new question, NPCs know
more than they say, and the Kasunduan is named but not explained in Episode 1.

Proposed shape (structure, not script — dialogue to be written):

1. **Morning** — courier day on the dispatch board (2–3 deliveries; teaches
   the setting and the debt threads; the board tutorial).
2. **The Envelope** — package delivery to Quiapo Church; a lender's envelope;
   the watch ticks wrong for the first time.
3. **Lola Rosa's Silence** — she hides something about the watch; the player
   chooses whether to press her (Loob consequence).
4. **Dusk** — the Aswang attack, the set-piece; first combat; the watch
   activates on its own (mystery: why did it save him?).
5. **Aftermath** — Dante's van and the gate ram; one answer that creates two
   new questions; cliffhanger: the watch shows a time that hasn't happened yet
   (or a name it shouldn't know).

No lore dumps in Episode 1. The backstory arrives as scenes the player plays,
not text the player reads.

## Art and audio direction

- **Art:** comic-book throughout (see Issue #20). Ink outlines, flat cel color,
  halftone shading, teal + gold + ink-black palette. Neon is an accent, never
  the look.
- **Audio:** licensed music per scene (Aphelion / Undertow / Determined Pursuit
  already in the repo), real recorded SFX, character voices via ElevenLabs
  (one-time generation, files in the repo — no live API in the game).

### Palette (decided Nov 9, 2026)

- Teal `#00ffcc` is an accent only — neon signs, Baybayin glyphs, and watch glow.
- Walls, ground, and sky are neutral: ink black, warm grey, and brown; lit windows are warm gold.
- No teal wash over the whole scene.

## What this means for the current build

1. Add an episode system: episode select / entry, per-episode scene lists,
   cliffhanger endings. Episode 1 = the existing Quiapo slice, restructured.
2. Build the dispatch board shell (jobs, debts, time, ledger display) with
   placeholder data first, then wire it to real story data.
3. Add timed-choice support to the dialogue/cutscene system and a QTE hook
   to the comic-panel cutscenes.
4. Keep combat, the command wheel, and exploration code as the field layer —
   no rewrite of those systems for this direction change.

## Open questions (John decides, not Claude)

- Exact Episode 1 length and cliffhanger beat.
- Voice casting for Renzo / Dante / Tala (ElevenLabs voice picks are John's).
- Release platform and storefront for episodes (itch.io / Steam later).
