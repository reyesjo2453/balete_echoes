import * as THREE from "three";
import { QUIAPO_NEON_LIGHT, QUIAPO_STALL_LIGHT } from "./DioramaChunk";

const MOONLIGHT_COLOR = 0x9fb4d8;
const LANTERN_COLOR = 0xffa64d;
const AMBER_COLOR = 0xffb347;
const NEON_MAGENTA = 0xff2bd0;

/**
 * Night lighting rig: a shadow-casting directional "moon" that tracks the
 * play area, plus a pool of warm point lights (street lanterns, sari-sari
 * store bulbs, candles at the balete roots).
 */
export class Lighting {
  readonly moon: THREE.DirectionalLight;
  readonly lanterns: THREE.PointLight[] = [];
  private readonly moonOffset = new THREE.Vector3(-8, 18, 6);

  constructor(private readonly scene: THREE.Scene) {
    this.moon = new THREE.DirectionalLight(MOONLIGHT_COLOR, 1.4);
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

  addLantern(position: THREE.Vector3, intensity = 18, distance = 9): THREE.PointLight {
    const light = new THREE.PointLight(LANTERN_COLOR, intensity, distance, 2);
    light.position.copy(position);
    light.castShadow = false; // keep point-light shadows off for mobile budgets
    this.scene.add(light);
    this.lanterns.push(light);
    return light;
  }

  /** Amber bulb at the sari-sari stall and a soft neon magenta wash at the street boundary. */
  addQuiapoLights(): void {
    const stall = this.addLantern(QUIAPO_STALL_LIGHT, 16, 9);
    stall.color.set(AMBER_COLOR);
    const neon = this.addLantern(QUIAPO_NEON_LIGHT, 10, 11);
    neon.color.set(NEON_MAGENTA);
    neon.userData.neon = true;
  }

  /** Keep the moon's shadow frustum centred on the focus point. */
  track(focus: THREE.Vector3): void {
    this.moon.target.position.copy(focus);
    this.moon.position.copy(focus).add(this.moonOffset);
  }

  /** Subtle flame flicker on lanterns. */
  update(elapsed: number): void {
    this.lanterns.forEach((l, i) => {
      const base = l.userData.base ?? (l.userData.base = l.intensity);
      if (l.userData.neon) {
        // Faulty-tube buzz: mostly steady with an occasional dip.
        const dip = Math.sin(elapsed * 23 + 1) * Math.sin(elapsed * 5.3) > 0.93 ? 0.55 : 1;
        l.intensity = base * dip * (0.96 + 0.04 * Math.sin(elapsed * 40));
        return;
      }
      l.intensity = base * (0.92 + 0.08 * Math.sin(elapsed * 9 + i * 1.7) * Math.sin(elapsed * 3.3 + i));
    });
  }
}
