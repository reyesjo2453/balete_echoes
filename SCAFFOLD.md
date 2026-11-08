# Balete: Echoes of the Sunken Veil — Scaffold Spec

Source: Gemini spec, saved 2026-11-08. Implement this exactly, then verify
`npm install` runs clean and `npm run dev -- --host` serves on :5173.

## Target directory architecture

```
balete-echoes/
├── public/
│   ├── assets/
│   │   ├── audio/          # Loopable BGM stems (ambient, rhythm, climax) and SFX
│   │   ├── comics/         # Visual novel panel cuts (.webp)
│   │   ├── models/         # Low-poly GLB diorama props and socketed weapons
│   │   └── sprites/        # 32-bit transparent billboard character sheets
├── src/
│   ├── audio/
│   │   └── AudioManager.ts # Multi-stem Web Audio API sync & crossfader
│   ├── combat/
│   │   ├── CombatEngine.ts # Real-time hitbox detection & ATB accumulation
│   │   └── AgimatSystem.ts # Elemental damage multipliers & gear horology
│   ├── core/
│   │   ├── Engine.ts       # Main requestAnimationFrame loop & state machine
│   │   ├── InputManager.ts # Touch virtual stick & HTML5 Gamepad API listener
│   │   └── Viewport.ts     # Three.js scene, shadow renderer, and camera rig
│   ├── entities/
│   │   ├── Billboard.ts    # Camera-facing sprite plane with circular shadow
│   │   ├── Mob.ts          # Enemy AI state controller & stagger gauge
│   │   └── Player.ts       # Renzo controller with 3D weapon socket
│   ├── ui/
│   │   ├── ComicOverlay.ts # DOM-based slanted graphic novel cutscene manager
│   │   └── HUD.ts          # Reflex command wheel, ATB gauges, and HP bars
│   ├── world/
│   │   ├── DioramaChunk.ts # 40x40m modular street geometry loader
│   │   └── Lighting.ts     # PBR directional moonlight & warm point lights
│   ├── main.ts             # Entry point bootstrapping core modules
│   └── style.css           # Viewport reset and HUD positioning rules
├── index.html
├── package.json
├── tsconfig.json
└── vite.config.ts
```

## package.json (exact dependencies)

```json
{
  "name": "balete-echoes",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite --host",
    "build": "tsc && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "gsap": "^3.12.5",
    "howler": "^2.2.4",
    "three": "^0.170.0"
  },
  "devDependencies": {
    "@types/howler": "^2.2.11",
    "@types/three": "^0.170.0",
    "typescript": "^5.6.3",
    "vite": "^5.4.10"
  }
}
```

## vite.config.ts

```ts
import { defineConfig } from "vite";

export default defineConfig({
  server: {
    host: true,
    port: 5173,
    open: false
  },
  build: {
    target: "esnext",
    sourcemap: true
  }
});
```

## Initial commit checklist

### Verify base scaffolding
- [ ] `npm install` runs cleanly, no package peer dependency conflicts.
- [ ] `npm run dev -- --host` produces valid local and network URLs (http://localhost:5173 and http://192.168.x.x:5173).

### Verify viewport rigging
- [ ] `Viewport.ts` uses a 45° downward pitch, blue-gray ambient moonlight (#1a233a), shadow maps enabled (THREE.PCFSoftShadowMap).
- [ ] Mount a test 20m x 20m dark gray asphalt plane with a basic roughness shader.

### Verify billboard & controller baseline
- [ ] Spawn a standalone 1.0m x 1.8m vertical plane with a placeholder sprite texture.
- [ ] The plane quaternion copies the camera quaternion on every tick inside requestAnimationFrame.
- [ ] Map standard vector movement (WASD and left analog stick via navigator.getGamepads()) to translate the plane along X and Z without tilting.
