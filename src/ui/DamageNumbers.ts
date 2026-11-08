import * as THREE from "three";

interface Floater {
  el: HTMLElement;
  world: THREE.Vector3;
  age: number;
  life: number;
}

const LIFE = 0.9;
const RISE_PX = 56;

/**
 * Floating damage numbers projected from world space into the HUD layer.
 * Amplified hits (e.g. stagger-break 2x) render larger, yellow, with a "x2" tag.
 * Advance with the unscaled frame delta so numbers stay readable during Command.
 */
export class DamageNumbers {
  private readonly active: Floater[] = [];
  private readonly v = new THREE.Vector3();

  constructor(private readonly root: HTMLElement) {}

  spawn(world: THREE.Vector3, amount: number, amplified: boolean): void {
    const el = document.createElement("div");
    el.className = amplified ? "dmg-num dmg-amplified" : "dmg-num";
    el.textContent = amplified ? `${amount}!` : String(amount);
    this.root.appendChild(el);
    // Slight horizontal jitter so rapid hits don't stack exactly.
    const w = world.clone();
    w.x += (Math.random() - 0.5) * 0.4;
    this.active.push({ el, world: w, age: 0, life: LIFE });
  }

  update(unscaledDt: number, camera: THREE.Camera, width: number, height: number): void {
    for (let i = this.active.length - 1; i >= 0; i--) {
      const f = this.active[i];
      f.age += unscaledDt;
      if (f.age >= f.life) {
        f.el.remove();
        this.active.splice(i, 1);
        continue;
      }
      const t = f.age / f.life;
      this.v.copy(f.world).project(camera);
      const x = (this.v.x * 0.5 + 0.5) * width;
      const y = (-this.v.y * 0.5 + 0.5) * height - t * RISE_PX;
      f.el.style.transform = `translate(${x}px, ${y}px) translate(-50%, -50%)`;
      f.el.style.opacity = String(1 - t * t);
    }
  }
}
