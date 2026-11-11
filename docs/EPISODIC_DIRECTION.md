# Balete: Episodic Direction — gameplay shape

**Status:** Approved by John (creative director), Nov 11, 2026. Replaces the Nov 8–10 direction (the dispatch board,
the courier runs, the money and time meters). Story canon: `docs/STORY.md`.

## In one paragraph

Balete is an **episodic narrative-action game**: an epic set in Filipino folklore in modern Manila, told like a
teleserye, one episode at a time. The story unfolds as a **comic book** (panels, three kinds of caption, sensible
QTEs where a character's own action decides the outcome). The fighting is **turn-based with real-time defence**, in
the shape of *Clair Obscur: Expedition 33*. Between them, the player **works the case**: a wake, a creek, a museum,
talking to people in any order. Every system serves one theme: *everything is borrowed, and every debt gets collected.*

## Why the old shape went

| Old layer | Problem | Now |
|---|---|---|
| Courier run (dodge potholes) | A fail state with nothing to do with the story | Removed |
| Job board, time budget, money, noon settle | Route-planning and spreadsheets in a story about gods and the dead | Removed. The money debt is story (Kapitan Obet, Hiraya), not a meter |
| A timed choice in nearly every scene, seven meters | Choice clutter; most picks changed nothing | Fewer, heavier choices; untimed unless the scene is violent; one meter that matters |
| Watchmaker *and* courier | Two jobs, neither connected to the folklore | Teo works the family funeral parlor; the family are sundô |

## The pillars

### 1. Combat: Expedition 33 shape (the core)
- **Turn-based** with enemy intents shown (what it will do, what Guard saves).
- **Real-time defence on the enemy's turn**, one ring for everything:
  - **Parry** (tight window): a perfect parry takes no damage, staggers, opens a **counter**, and charges the watch.
  - **Dodge**: some attacks *cannot be parried* (water, nets, sweeps: the intent card says DODGE). Any hit in the zone
    avoids them; no counter; Guard does not help. Reading which is which is the skill.
- **Action economy:** attacks and perfect parries charge the watch; watch powers and team moves spend it.
- **Stagger break:** three staggers break the guard; the next hit lands double.
- **Each party member's mechanic is their character:**
  - **Teo — Borrowed Time.** Watch powers (Rewind in Ep 1, then Slow, Echo, the Seventeenth Minute). Rewind costs
    *utang*. A fatal miss rewinds the round, and costs utang too.
  - **Kardo — the Circuit.** WIRE clamps a stack on the enemy (max 3); DISCHARGE spends them all: damage and stagger
    per stack, three stacks break the guard outright.
  - **Sol — Baybayin** (Ep 2): write a syllable each turn; finished words cast.
  - **Mayari — Moon phases** (Ep 7): build crescent to full, then release.
  - **Celeste — Hiraya tech** (guest): borrowed power with no personal cost, because someone else pays it.
- **Anting-anting** (`data/amulets.json`) work like Pictos: equip one, each with a perk and a cost.
- **Guided teaching, then hands off:** the first parry is a guided lesson (the cold open, as Lolo Pido); the first
  dodge gets its own lesson; after that the ring is yours.

### 2. Utang: the one meter that matters
Borrowed time. It rises when the watch saves you (Rewind, a rewound fall, the awakening). While Teo carries the watch,
**it greys him**: a first white streak at the awakening, then greying, grey, and finally white like Lolo Pido. The
game shows it (Teo's portrait desaturates, his battle rim whitens, a banner says so) and the endings read it.
Power now, price later: the same economy as the story.

### 3. Story: comic panels with sensible QTEs
- Full comic presentation: panels, speech bars, onomatopoeia, flashes and shakes.
- **Three kinds of line, three bars** (from the Nov 10 playtest, kept): `say` (spoken: dark bar, portrait, name),
  `think` (inner voice: violet bar, italic), `narr` (the story: yellow caption, no portrait).
- **QTE rules:**
  1. Only where a character's *own physical action* decides the outcome: catching the watch, catching the oil,
     bracing for the gate. No chore QTEs (no kick-starting bikes).
  2. **The same ring as the parry**, so the player learns one skill.
  3. A miss plays out **worse, never game over**: an injury carried into the next fight, a cut hand Kardo stitches
     later, a different line. Each QTE sets `<id>_ok` or `<id>_miss` so later scenes answer it.
  4. At most 3–4 per episode. Episode 1 has three: the watch catch (guided), the oil (assisted), the gate (free).

### 4. Choices: fewer, heavier, remembered
- **Two or three big choices per act**, untimed unless the scene is violent (a fight, a gate, a phone call with a
  deadline). Each one changes a later scene, and the important ones say *"<who> will remember that."*
- **Dialogue picks for voice and flavour.** They still set flags that later lines answer.
- **Bonds** (Kardo, Lola Ising, and others later) decide who stands with Teo in the finale.
- **Loob** (resolve) from the big choices decides whether watch powers take a protective or aggressive form.
- The end card lists what was remembered.

### 5. Exploration: the case hubs
Each episode has one or two **hubs**: the wake in Episode 1, the estero at 2 AM. The player talks to people in any
order; some must be heard before moving on, the rest are optional and pay off later (a clue, a line in a later
scene, a soul sent home). This is where the setting is explained and the soap opera happens. Later episodes add
optional side cases: short fights that award anting-anting.

## Episode structure

- **Length:** about 60–75 minutes (Episode 1 estimates at ~54; `tools/estimate_playtime.py` runs in CI).
- **Shape:** cold open (a flashback or another point of view) → three acts, each ending on a reveal → *"Abangan..."*
  end card with the next-episode teaser.
- **A-plot** (the case of the week, starting with someone dead) + **B-plot** (a family secret) + **season arc**.
- **Release:** one episode at a time, in story order.

## Episode 1 — as built
See `docs/STORY.md` for the beats. Systems in it: 5 fights (the drowned as Lolo Pido; Mang Berto, ligaw; the creek's
unsent; the tagged aswang, where the watch awakens; the Hiraya hound, beside Kardo), 2 hubs (the wake, the estero),
3 story QTEs, 3 big choices, Teo's first white streak.

## Saves and chapters
Every beat is a checkpoint; the title offers "Continue: Chapter N". An episode has a prologue (the cold open) and
four chapters, each with a card (Episode 1: about 7, 22, 31 and 41 minutes in). Continuing opens with a skippable
"Previously on Balete" built from the player's own choices. Quitting mid-fight restarts that fight, injuries kept.

## Art and audio
- Comic-book throughout: ink outlines, flat cel colour, halftone. Teal `#00ffcc` only as an accent (watch glow,
  Baybayin, neon); walls, ground and sky neutral; lit windows warm gold.
- Music by mood cue (wake, tension, battle, boss, sting), crossfaded at scene and battle changes, and silence on the
  big emotional beats. Only CC0 or clearly licensed tracks, credited in `godot/assets/bgm/CREDITS.md`. Recorded SFX;
  voices generated once and stored in the repo.
- New panels Episode 1 needs are listed in `docs/ASSET_MANIFEST.md`; until they exist the game shows a labelled slot.

## Open questions (John decides)
- Voice casting for Teo, Lola Ising, Kardo, Celeste.
- Whether Episode 1 should grow toward 70 minutes (candidates: a longer Act 3 rest beat, an optional side case at the
  wake).
- Release platform and storefront.
