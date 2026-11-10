import * as THREE from "three";

const MAX_SPARKS = 48;
const LIFETIME = 0.35;
const GRAVITY = 9;

/**
 * Pooled burst of additive points used for melee hit feedback.
 * Call `burst()` on impact and `update(dt)` every tick (pass the unscaled frame delta
 * so sparks never freeze during command time dilation).
 */
export class HitSpark {
  readonly points: THREE.Points;
  private readonly positions = new Float32Array(MAX_SPARKS * 3);
  private readonly velocities = new Float32Array(MAX_SPARKS * 3);
  private readonly ages = new Float32Array(MAX_SPARKS).fill(LIFETIME);
  private cursor = 0;

  constructor(color = 0xffd98a) {
    const geo = new THREE.BufferGeometry();
    geo.setAttribute("position", new THREE.BufferAttribute(this.positions, 3));
    const mat = new THREE.PointsMaterial({
      color,
      size: 0.14,
      transparent: true,
      opacity: 1,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
    });
    this.points = new THREE.Points(geo, mat);
    this.points.frustumCulled = false;
    this.positions.fill(1e4); // park unused sparks off-screen
  }

  burst(origin: THREE.Vector3, count = 14): void {
    for (let n = 0; n < count; n++) {
      const i = this.cursor;
      this.cursor = (this.cursor + 1) % MAX_SPARKS;
      this.ages[i] = 0;
      this.positions.set([origin.x, origin.y, origin.z], i * 3);
      const speed = 2 + Math.random() * 3;
      const theta = Math.random() * Math.PI * 2;
      this.velocities.set(
        [Math.cos(theta) * speed, 1.5 + Math.random() * 2.5, Math.sin(theta) * speed],
        i * 3
      );
    }
  }

  update(dt: number): void {
    let alive = false;
    for (let i = 0; i < MAX_SPARKS; i++) {
      if (this.ages[i] >= LIFETIME) continue;
      this.ages[i] += dt;
      if (this.ages[i] >= LIFETIME) {
        this.positions.set([1e4, 1e4, 1e4], i * 3);
        continue;
      }
      alive = true;
      const o = i * 3;
      this.velocities[o + 1] -= GRAVITY * dt;
      this.positions[o] += this.velocities[o] * dt;
      this.positions[o + 1] += this.velocities[o + 1] * dt;
      this.positions[o + 2] += this.velocities[o + 2] * dt;
    }
    this.points.visible = alive;
    (this.points.geometry.attributes.position as THREE.BufferAttribute).needsUpdate = true;
  }

  dispose(): void {
    this.points.geometry.dispose();
    (this.points.material as THREE.Material).dispose();
  }
}
