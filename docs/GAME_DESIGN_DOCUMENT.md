# BALETE: Echoes of the Sunken Veil — Master Game Design & Technical Specification

## 1. Project Identity & Target Specifications

* **Title:** *Balete: Echoes of the Sunken Veil*
* **Repository:** `reyesjo2453/balete_echoes`
* **Target Platforms:** Mobile Web / PWA (specifically optimized for Samsung Galaxy Z Fold 8 inner and outer screens), Bluetooth Gamepad (GameSir G8+), and Desktop Web.
* **Core Engine Stack:** Vite 5 + TypeScript, Three.js ^0.170.0, GSAP ^3.12.5, Howler ^2.2.4, and the Web Audio API.
* **Visual Rendering Paradigm:** Lit 2.5D Billboard Sprites (diffuse + normal maps) rendered inside enclosed, high-density 3D dioramas with PBR wet-surface shaders and Three.js post-processing.
* **Asset Production Pipeline:** Automated via `fal.ai` MCP server (`flux/dev` + `rembg` for 2D sprites, `trellis` for low-poly GLB props, and `flux-pro` for graphic novel cutscene panels).

---

## 2. Worldbuilding & Narrative Canon

**Canon now lives in `docs/STORY.md` (approved Nov 11, 2026).** In short: the Dimaculangans run a funeral parlor in
Quiapo and are hereditary *sundô* who walk the dead home. Lolo Pido's pocket watch, cut from Sidapa's balete,
borrows time and writes it against the family (*utang*). Hiraya Energy bottles unsent souls (*ginhawa*) as free
power. Bakunawa is the collector, and the eclipse (*Laho*) is collection day.

**Cast:** Teo Dimaculangan (20, protagonist), Lola Ising (75), Kardo Bagwis (53, embalmer and ex-lineman), Celeste
Villacorta / Liwayway (28, Teo's sister, Hiraya's COO), Gregorio Villacorta (45, Hiraya), Sol Agbayani (museum
conservator, Ep 2+), Mayari (moon goddess, Ep 7+).

---

## 3. Episode 1 Cold Open & Tutorial (as built)

The old five-minute "Quiapo Ambush" prologue is replaced. Episode 1 opens in **1998**: the player is Lolo Pido in
the flooded parlor, learning the parry against the drowned (guided ring), then watching him rewind the flood for
4 min 17 s and age ten years. The tutorial continues in the present: the dodge is taught against Mang Berto's ligaw,
the watch awakens against the tagged aswang, and Kardo's circuit is taught in the hound fight. Full beats:
`docs/STORY.md`; script: `tools/build_episode1.py`; systems: `docs/EPISODIC_DIRECTION.md`.

> The real-time systems below (reflex mode, counter-dodge, Giting) are from the original web build. The Godot game
> uses the turn-based model with real-time parry and dodge described in `docs/EPISODIC_DIRECTION.md`.

---

## 4. Combat & Gameplay Systems Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 Engine Dual-Delta Clock Loop                │
│                                                             │
│  [simulationDelta = delta * timeDilation]                   │
│  ├── Mob AI Behavior & Chase Vectors                        │
│  ├── Entity Movement & Hitbox Overlaps                      │
│  └── Status Effect Durations & Attack Cooldowns             │
│                                                             │
│  [unscaledDelta = raw frame delta]                          │
│  ├── Camera Tracking & Smoothing Interpolations             │
│  ├── InputManager Event Polling & Gamepad States            │
│  └── UI / HUD Render Passes & HitSpark Particle Decay       │
└─────────────────────────────────────────────────────────────┘
```

### A. Reflex Mode (Time-Dilation)

* Holding the Command button (`L1` / Gamepad Button 4 / On-screen button) dials `timeDilation` down to `0.05x`.
* Opens the tactical Command Menu:
* **Agimat (Apoy Blade):** Consumes 15 SP. Infuses weapon with fire (orange emissive glow), boosting Stagger buildup by +50% for 8 seconds.
* **Kagamitan (Lunas):** Consumes 1 charge to heal 250 HP with a green rising particle ring.
* **Guard:** Raises poise, reducing incoming attack damage by 70%.

### B. Active Combat & Stagger Mechanics

* **Auto-Lock Targeting:** When within 3.5m of an active enemy, an emissive bracket reticle appears over the target, snapping Renzo’s attack vectors toward it.
* **Telegraphing & Counter-Dodge:** Enemies project a red ground-plane cone/circle 1.2s before attacking. Dodging (`B / Circle`) inside the final 0.4s triggers `COUNTER-DODGE!`: 0.3s slow motion, teleport behind target, and +100% crit chance on the next hit.
* **Stagger Break:** Hitting enemies fills their Stagger gauge. At 100%, the mob freezes in pale yellow, takes 2.0x damage, and remains helpless for 4 seconds.

### C. Giting (Valor) & Bayanihan Strike

* Normal hits build +6% Giting; successful Counter-Dodges grant +25%.
* At 100%, the HUD pulses gold and displays `Bayanihan Strike Ready! [R1]`.
* Triggering `R1` (Gamepad Button 5 / `Q`) pauses world simulation, slides in an angled comic banner, delivers a 6-hit barrage, detonates for 150 true damage, and shatters the target's Stagger bar.

### D. Horology Gear Matrix (Character Progression)

Weapons are upgraded through watch components:

* **Escapement Wheels:** Control base ATB fill rate.
* **Mainspring Alloys:** Multiply Stagger damage output.
* **Jewel Bearings:** Reduce Agimat SP consumption costs.
* **Balance Springs:** Widen or narrow Counter-Dodge timing windows.

---

## 5. Technical Visual & Environmental Specifications

### A. The Enclosed Alley Diorama (Option B)

* **Dimensions:** 8 meters wide, 28 meters long, bounded by 12-meter-tall tenement walls.
* **Geometry:** Weathered concrete walls, iron window grilles (*rehas*), rusted air conditioning compressors, PVC drainage pipes, overhead fire escapes, and hanging high-voltage wire bundles.
* **Ground Surface:** Wet asphalt shader with puddle roughness maps (`0.04` in puddles, `0.75` on dry road) and blue-tinted specular highlights.
* **Lighting Rig:**
* Ambient Moonlight: `#0d1322`, intensity 0.45.
* Flickering Neon Sign: Point light `#00ffcc`, intensity 1.5 with random micro-flickers.
* Sari-Sari Lantern: Warm amber point light `#ff8822`, intensity 2.2, radius 6.0m.

### B. Lit 2.5D Billboard Sprites

* Sprites are rendered on standard `THREE.PlaneGeometry(1.0, 1.8)` but utilize `THREE.MeshStandardMaterial` supporting:
* `map`: 32-bit transparent diffuse PNG.
* `normalMap`: Tangent-space normal map enabling dynamic specular bounce from neon signs and street lamps.
* `roughnessMap`: Realistic surface response (wet skin vs. matte denim).
* `alphaTest: 0.5`: Clean silhouette cutoff with zero edge bleeding.
* Billboard planes lock their quaternion to the camera on every render tick while preserving their world-space light calculations.

---

## 6. Sound Architecture (Web Audio API Engine)

```
┌────────────────────────────────────────────────────────┐
│               Adaptive 3-Stem BGM Controller           │
│                                                        │
│  Stem 1: Ambient Base (Gain 1.0 Always)                │
│  - Soft Bandurria pluck arpeggios + ambient rain noise │
│                                                        │
│  Stem 2: Combat Rhythm (Gain ramps 0 -> 1 in 0.6s)     │
│  - Tuned Kulintang gong pulses + syncopated sub-bass   │
│                                                        │
│  Stem 3: Climax Tension (Gain ramps on Stagger/Boss)   │
│  - Sawtooth string ostinatos through low-pass filters  │
└────────────────────────────────────────────────────────┘
```

* **Procedural SFX Generation:**
* `playSlash()`: 0.08s modulated noise sweep with pitch drop.
* `playHit()`: 0.12s punchy dual-frequency impact thud.
* `playStaggerBreak()`: Resonant metallic three-tone harmonic chord (880Hz, 1320Hz, 1760Hz).
* `playCommandEnter()` / `playCommandExit()`: Low-pass filter frequency sweeps signaling time-dilation transitions.

---

## 7. Motion-Comic Cutscene Layer (`ComicOverlay.ts`)

* Built as a high `z-index` responsive DOM overlay above the Three.js canvas.
* Panels use CSS polygon masks: `clip-path: polygon(0 0, 100% 4%, 96% 100%, 0% 96%)`.
* Entrance transitions are powered by GSAP timelines (`easeOutBack` slide-ins with screen shake and onomatopoeia).
* Step advancement binds universally to Gamepad Button 0 (`A/Cross`), Spacebar, Enter, or screen touch.
* When active, sets `timeDilation = 0.0` to freeze world simulation while keeping UI animations running at full speed.

---

## 8. Directory & Architecture Map

```text
balete_echoes/
├── public/
│   ├── assets/
│   │   ├── audio/          # Pre-rendered BGM stems and stinger cues
│   │   ├── comics/         # Graphic novel cutscene panels (.webp)
│   │   ├── models/         # Modular GLB diorama props and weapons
│   │   └── sprites/        # Diffuse and normal-mapped 2.5D character sheets
│   └── manifest.webmanifest# PWA configuration for full-screen mobile
├── src/
│   ├── audio/
│   │   └── AudioManager.ts # Multi-stem Web Audio engine and procedural SFX
│   ├── combat/
│   │   ├── AgimatSystem.ts # Horology matrix, elemental weaknesses, and buffs
│   │   └── CombatEngine.ts # Real-time hitbox checks, Stagger, and Giting meters
│   ├── core/
│   │   ├── Engine.ts       # Main loop managing simulationDelta and unscaledDelta
│   │   ├── InputManager.ts # Touch joystick, Gamepad API listener, and keybinds
│   │   └── Viewport.ts     # Three.js scene, camera rig, and post-processing
│   ├── entities/
│   │   ├── Billboard.ts    # Lit 2.5D normal-mapped sprite plane
│   │   ├── HitSpark.ts     # Particle burst pools for hits, heals, and slashes
│   │   ├── Mob.ts          # State machine AI, telegraph cones, and dissolve death
│   │   └── Player.ts       # Renzo controller, weapon sockets, and dodge vectors
│   ├── narrative/
│   │   ├── Scenes.ts       # Cutscene script arrays and dialogue trees
│   │   └── TutorialScene.ts# Minute 0-5 scripted triggers and camera events
│   ├── ui/
│   │   ├── ComicOverlay.ts # Motion-comic DOM layer with GSAP panel animations
│   │   ├── HUD.ts          # Touch controls, command wheel, and HP/ATB/Giting bars
│   │   └── TitleScreen.ts  # Title sequence, audio context unlock, and demo reset
│   ├── world/
│   │   ├── DioramaChunk.ts # 8x28m enclosed Quiapo alley geometry
│   │   ├── Interactable.ts # Floating glyph interaction nodes and loot orbs
│   │   └── Lighting.ts     # PBR directional moonlight, lanterns, and neon point lights
│   ├── main.ts             # App bootstrap
│   └── style.css           # Mobile viewport locks, safe-area offsets, and HUD CSS
├── index.html
├── package.json
├── tsconfig.json
└── vite.config.ts
```
