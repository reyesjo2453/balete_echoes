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

### The Lore

In modern Metro Manila, the ancient **Kasunduan ng Lupa** (The Earth Covenant)—brokered centuries ago between indigenous shamans (*Babaylan*) and supernatural spirit courts (*Engkanto*)—is collapsing due to unchecked commercial dredging and urban sprawl.

* **The Bleed:** Neon billboards flicker with ancient Baybayin glyphs, rain carries the scent of swamp mist, and spiritual underworld corridors (*Kailaliman*) bleed into the streets.
* **Aevum Filipinas:** A shadow conglomerate weaponizing spirit vitality (*Ginhawa*) to manufacture synthetic amulets (*Agimat*).
* **The Cosmic Threat:** The celestial dragon **Bakunawa** stirs beneath the Sibuyan Sea to devour the astral moon during an impending total eclipse (*Laho*).

### The Cast

1. **Renzo (Player Character):** A 22-year-old cynical delivery courier and watchmaker's apprentice in Quiapo. Disregards occult folklore as street con games until an undelivered antique chronometer saves his life. Wields a utility folding balisong dagger and the time-altering pocket watch.
2. **Dante:** An ex-mechanic from Tondo. Pragmatic, heavily built, wears oil-stained coveralls. Wields electrified industrial Arnis/Escrima batons powered by a converted battery harness. Serves as the party's vanguard and extraction driver.
3. **Tala:** A junior conservator at the National Museum. Quiet, scholarly, wears an archival trench coat over woven indigenous textiles. Channels Baybayin sigils into offensive and defensive ground glyphs.
4. **Mayari (Late-Game):** A renegade moon-court assassin from the Sierra Madre who phases through shadow planes.

---

## 3. Prologue & Tutorial Narrative Flow (Minute 0:00 – 5:00)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PROLOGUE NARRATIVE BEATS                        │
│                                                                        │
│  [0:00 - 1:30] Delivery in Dead-End Quiapo Alley                       │
│                Renzo inspects fake invoice; alley plunges into black    │
│                                   │                                    │
│                                   ▼                                    │
│  [1:30 - 2:45] Traversal & Ambient Buildup                             │
│                Navigate flooded alleyway; watch ticks counter-clockwise │
│                                   │                                    │
│                                   ▼                                    │
│  [2:45 - 3:30] The Ambush & Crown Pull                                 │
│                Corrupted Aswang drops; prompt: [HOLD L1 / PULL CROWN]  │
│                Time drops to 0.05x; assess attack vector               │
│                                   │                                    │
│                                   ▼                                    │
│  [3:30 - 4:30] Survival Trial & Stagger Break                          │
│                Telegraph cone appears; Counter-Dodge [B/Circle]        │
│                Aswang hits brick wall; land 3 desperate balisong hits  │
│                                   │                                    │
│                                   ▼                                    │
│  [4:30 - 5:00] Extraction by Dante                                     │
│                Aswang knocks Renzo down; delivery van smashes gate     │
│                Dante shocks beast; van escapes into Manila rain        │
└────────────────────────────────────────────────────────────────────────┘
```

1. **Phase 1 (The Delivery):** Renzo stands in a rain-slicked Quiapo back-alley behind Evangelista Street. Monobloc chairs, puddles, and corrugated tin overhangs surround him. Streetlights flicker violently and die. The pocket watch in his satchel begins spinning counter-clockwise.
2. **Phase 2 (The Ambush):** An emaciated Corrupted Aswang drops from an overhead fire escape. Comic cut-in panels freeze the scene to capture Renzo's shock.
3. **Phase 3 (Survival & Mechanics):** The monster charges. Pulling the pocket watch crown (`L1` / Command button) engages reflex mode, dilating time to `0.05x`. Releasing into a timed Dodge (`B / Circle`) triggers a Counter-Dodge, putting Renzo behind the creature to strike its exposed core and build Stagger.
4. **Phase 4 (Extraction):** The Aswang recovers and swats Renzo across the pavement (dealing 40 HP damage with camera shake). Headlights blast down the alley as Dante crashes a delivery van through the gate, tasers the monster, pulls Renzo aboard, and speeds away.

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
