import * as THREE from "three";
import { QUIAPO_LAMP_LIGHTS, QUIAPO_NEON_LIGHT, QUIAPO_STALL_LIGHT } from "./DioramaChunk";

/** Deep-night palette for the Quiapo alley. */
export const MOONLIGHT_AMBIENT_COLOR = 0x0d1322;
export const MOONLIGHT_AMBIENT_INTENSITY = 0.4;
const MOONLIGHT_COLOR = 0xa9c3e6;
/** Restrained rust-red sign glow: the comic panels are red / teal / amber, not cyan neon. */
const NEON_COLOR = 0xff3a48;
const LANTERN_COLOR = 0xff8822;
const LANTERN_INTENSITY = 2.0;
const STREETLAMP_COLOR = 0xffc27a;

/**
 * Night lighting rig: moonlight ambient (#0d1322 @ 0.4), a shadow-casting
 * directional "moon" that tracks the play area, a flickering cyan neon point
 * light, an amber lantern at the sari-sari stall and two street lamps that
 * can be blacked out.
 */
export class Lighting {
  readonly ambient: THREE.AmbientLight;
  readonly moon: THREE.DirectionalLight;
  readonly lanterns: THREE.PointLight[] = [];
  private readonly streetLamps: THREE.PointLight[] = [];
  private readonly moonOffset = new THREE.Vector3(-8, 18, 6);
  private streetOn = true;
  private neon: THREE.PointLight | null = null;
  private neonHold = 0;
  private neonLevel = 1;

  /** Current neon flicker multiplier (for the emissive tubes). */
  get neonFlicker(): number {
    return this.neonLevel;
  }

  constructor(private readonly scene: THREE.Scene) {
    this.ambient = new THREE.AmbientLight(MOONLIGHT_AMBIENT_COLOR, MOONLIGHT_AMBIENT_INTENSITY);
    scene.add(this.ambient);

    // Teal sky bounce from above, warm street bounce from below: what makes the painted
    // walls and the sprites read as form instead of black shapes in the dark.
    scene.add(new THREE.HemisphereLight(0x5a8aa0, 0x3a2418, 1.35));
    scene.environment = createNightEnvironment();
    scene.environmentIntensity = 1.0;

    this.moon = new THREE.DirectionalLight(MOONLIGHT_COLOR, 1.5);
    this.moon.position.copy(this.moonOffset);
    this.moon.castShadow = true;
    this.moon.shadow.mapSize.set(2048, 2048);
    this.moon.shadow.bias = -0.0005;
    this.moon.shadow.normalBias = 0.02;
    this.moon.shadow.radius = 4;
    const cam = this.moon.shadow.camera;
    cam.near = 1;
    cam.far = 60;
    cam.left = -16;
    cam.right = 16;
    cam.top = 16;
    cam.bottom = -16;
    scene.add(this.moon, this.moon.target);
  }

  addLantern(position: THREE.Vector3, intensity = 18, distance = 9, color = LANTERN_COLOR, decay = 2): THREE.PointLight {
    const light = new THREE.PointLight(color, intensity, distance, decay);
    light.position.copy(position);
    light.castShadow = false; // keep point-light shadows off for mobile budgets
    this.scene.add(light);
    this.lanterns.push(light);
    return light;
  }

  /**
   * Alley lights: amber lantern (#ff8822, intensity 2.0) at the stall, a
   * flickering neon (#00ffcc) on the right wall, and two street lamps.
   * Decay 1 keeps the spec'd low lantern intensity readable at a few metres.
   */
  addQuiapoLights(): void {
    this.addLantern(QUIAPO_STALL_LIGHT, LANTERN_INTENSITY, 12, LANTERN_COLOR, 1);
    this.neon = this.addLantern(QUIAPO_NEON_LIGHT, 4.5, 11, NEON_COLOR, 1);
    this.neon.userData.neon = true;
    for (const p of QUIAPO_LAMP_LIGHTS) {
      const lamp = this.addLantern(p, 9, 13, STREETLAMP_COLOR, 1);
      lamp.userData.street = true;
      this.streetLamps.push(lamp);
    }
  }

  /** Blackout: the street lamps go dark. The neon and stall lantern keep burning. */
  setStreetlights(on: boolean): void {
    this.streetOn = on;
  }

  /** Keep the moon's shadow frustum centred on the focus point. */
  track(focus: THREE.Vector3): void {
    this.moon.target.position.copy(focus);
    this.moon.position.copy(focus).add(this.moonOffset);
  }

  /** Flame flicker on lanterns, random-intensity flicker on the neon, blackout on lamps. */
  update(elapsed: number, realDt = 1 / 60): void {
    this.lanterns.forEach((l, i) => {
      const base = l.userData.base ?? (l.userData.base = l.intensity);
      if (l.userData.neon) {
        // Faulty tube: hold a random level for a few frames, mostly near full, sometimes dropping out.
        this.neonHold -= realDt;
        if (this.neonHold <= 0) {
          const r = Math.random();
          this.neonLevel = r < 0.12 ? 0.05 + Math.random() * 0.2 : r < 0.3 ? 0.5 + Math.random() * 0.3 : 0.9 + Math.random() * 0.2;
          this.neonHold = 0.02 + Math.random() * (r < 0.3 ? 0.12 : 0.25);
        }
        l.intensity = base * this.neonLevel;
        return;
      }
      if (l.userData.street) {
        const target = this.streetOn ? base : 0;
        l.intensity = THREE.MathUtils.lerp(l.intensity, target, 1 - Math.exp(-(this.streetOn ? 6 : 30) * realDt));
        if (!this.streetOn && l.intensity < 0.01) l.intensity = 0;
        return;
      }
      l.intensity = base * (0.92 + 0.08 * Math.sin(elapsed * 9 + i * 1.7) * Math.sin(elapsed * 3.3 + i));
    });
  }
}

/**
 * Painted night-sky environment for reflections and image-based light: deep teal zenith, indigo
 * mid-sky, a warm amber glow low on the horizon (sodium-lit smog), dark ground. Puddles and the
 * glossy props reflect it, which is what makes the wet street read as wet.
 */
function createNightEnvironment(): THREE.Texture {
  const w = 512;
  const h = 256;
  const c = document.createElement("canvas");
  c.width = w;
  c.height = h;
  const g = c.getContext("2d")!;
  const sky = g.createLinearGradient(0, 0, 0, h);
  sky.addColorStop(0, "#1d4350");
  sky.addColorStop(0.35, "#17283a");
  sky.addColorStop(0.5, "#6a4423");
  sky.addColorStop(0.56, "#2a1c16");
  sky.addColorStop(1, "#0b0d11");
  g.fillStyle = sky;
  g.fillRect(0, 0, w, h);
  // A few lamp-lit smears so reflections are not a flat gradient.
  for (const [x, y, r, col] of [[90, 125, 38, "rgba(255,170,80,0.55)"], [300, 130, 30, "rgba(255,150,70,0.45)"], [430, 110, 26, "rgba(255,70,80,0.35)"]] as const) {
    const rg = g.createRadialGradient(x, y, 0, x, y, r);
    rg.addColorStop(0, col);
    rg.addColorStop(1, "rgba(0,0,0,0)");
    g.fillStyle = rg;
    g.fillRect(x - r, y - r, r * 2, r * 2);
  }
  const tex = new THREE.CanvasTexture(c);
  tex.mapping = THREE.EquirectangularReflectionMapping;
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}
