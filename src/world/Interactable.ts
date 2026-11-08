import * as THREE from "three";

export const INTERACT_RANGE = 1.5;
/** Sari-sari stall examine point. */
export const STALL_NODE_POSITION = new THREE.Vector3(-3, 0.5, -1);
const RUNE_COLOR = 0x7fe8ff;

/**
 * A world node with a floating emissive rune. When the player is within
 * INTERACT_RANGE (X/Z) a DOM prompt appears; the caller fires `trigger()`
 * on the action button.
 */
export class Interactable {
  readonly root = new THREE.Group();
  enabled = true;
  /** Fired by `trigger()`. */
  onInteract: (() => void) | null = null;

  protected readonly rune: THREE.Group;
  /** Rune spin in rad/s (0 to leave orientation to a subclass). */
  protected spinRate = 1.6;
  private readonly light: THREE.PointLight;
  private readonly prompt: HTMLElement;
  private inRange = false;
  private clock = 0;

  constructor(
    position: THREE.Vector3,
    promptText: string,
    hudRoot: HTMLElement,
    readonly range = INTERACT_RANGE,
    visual?: THREE.Group
  ) {
    this.root.position.copy(position);

    const glow = new THREE.MeshStandardMaterial({
      color: RUNE_COLOR,
      emissive: RUNE_COLOR,
      emissiveIntensity: 2.2,
      transparent: true,
      opacity: 0.9,
      roughness: 0.3,
    });
    this.rune = visual ?? new THREE.Group();
    if (!visual) {
      const diamond = new THREE.Mesh(new THREE.OctahedronGeometry(0.16), glow);
      diamond.scale.y = 1.6;
      const ring = new THREE.Mesh(new THREE.TorusGeometry(0.28, 0.018, 8, 32), glow);
      const ring2 = ring.clone();
      ring2.rotation.x = Math.PI / 2;
      this.rune.add(diamond, ring, ring2);
    }
    this.rune.position.y = 0.9;
    this.root.add(this.rune);

    this.light = new THREE.PointLight(RUNE_COLOR, 1.2, 4, 2);
    this.light.position.y = 0.9;
    this.root.add(this.light);

    this.prompt = document.createElement("div");
    this.prompt.className = "interact-prompt";
    this.prompt.textContent = promptText;
    hudRoot.appendChild(this.prompt);
  }

  /** True when the prompt is visible and `trigger()` will fire. */
  get ready(): boolean {
    return this.enabled && this.inRange;
  }

  /** Per-frame: pass real (unscaled) dt so the rune animates even in slow-mo. */
  update(playerPos: THREE.Vector3, unscaledDt: number): void {
    this.clock += unscaledDt;
    this.rune.position.y = 0.9 + Math.sin(this.clock * 2.4) * 0.08;
    this.rune.rotation.y += unscaledDt * this.spinRate;
    this.light.intensity = 1.0 + Math.sin(this.clock * 5) * 0.3;

    const dx = playerPos.x - this.root.position.x;
    const dz = playerPos.z - this.root.position.z;
    this.inRange = this.enabled && dx * dx + dz * dz <= this.range * this.range;
    this.prompt.classList.toggle("show", this.inRange);
  }

  trigger(): boolean {
    if (!this.ready) return false;
    this.onInteract?.();
    return true;
  }

  /** Re-arm a disabled node (demo restart). */
  reset(): void {
    this.enabled = true;
    this.root.visible = true;
  }

  /** Remove the DOM prompt; call when discarding the node. */
  dispose(): void {
    this.prompt.remove();
  }

  /** Hide the marker and prompt for good. */
  disable(): void {
    this.enabled = false;
    this.inRange = false;
    this.root.visible = false;
    this.prompt.classList.remove("show");
  }
}

const CYAN = 0x4df0ff;
const RING_POINTS = 36;

/**
 * Defeat reward: a spinning brass gear ringed by glowing cyan particles.
 * Prompts "[A] Pulutin (Pick up)" within 1.5m.
 */
export class LootDrop extends Interactable {
  private readonly gear: THREE.Group;
  private readonly ring: THREE.Points;

  constructor(position: THREE.Vector3, hudRoot: HTMLElement) {
    const visual = new THREE.Group();
    super(position, "[A] Pulutin (Pick up)", hudRoot, INTERACT_RANGE, visual);
    this.spinRate = 0;

    // Brass gear: hub disc + ring + 10 teeth, tilted toward the camera.
    const brass = new THREE.MeshStandardMaterial({ color: 0xc89a3c, metalness: 0.9, roughness: 0.35, emissive: 0x3a2200 });
    this.gear = new THREE.Group();
    const body = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.2, 0.07, 24), brass);
    body.rotation.x = Math.PI / 2;
    const hole = new THREE.Mesh(
      new THREE.CylinderGeometry(0.07, 0.07, 0.09, 12),
      new THREE.MeshStandardMaterial({ color: 0x1a1208, roughness: 0.9 })
    );
    hole.rotation.x = Math.PI / 2;
    this.gear.add(body, hole);
    for (let i = 0; i < 10; i++) {
      const a = (i / 10) * Math.PI * 2;
      const tooth = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.1, 0.07), brass);
      tooth.position.set(Math.cos(a) * 0.24, Math.sin(a) * 0.24, 0);
      tooth.rotation.z = a;
      this.gear.add(tooth);
    }
    const tilt = new THREE.Group();
    tilt.rotation.x = -0.9;
    tilt.add(this.gear);
    visual.add(tilt);

    // Cyan particle ring orbiting the gear.
    const pos = new Float32Array(RING_POINTS * 3);
    for (let i = 0; i < RING_POINTS; i++) {
      const a = (i / RING_POINTS) * Math.PI * 2;
      pos.set([Math.cos(a) * 0.5, 0, Math.sin(a) * 0.5], i * 3);
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute("position", new THREE.BufferAttribute(pos, 3));
    this.ring = new THREE.Points(
      geo,
      new THREE.PointsMaterial({
        color: CYAN,
        size: 0.07,
        transparent: true,
        opacity: 0.95,
        blending: THREE.AdditiveBlending,
        depthWrite: false,
      })
    );
    this.ring.frustumCulled = false;
    visual.add(this.ring);
  }

  override update(playerPos: THREE.Vector3, unscaledDt: number): void {
    super.update(playerPos, unscaledDt);
    this.gear.rotation.z += unscaledDt * 2.2;
    this.ring.rotation.y -= unscaledDt * 1.4;
    this.ring.scale.setScalar(1 + Math.sin(this.ring.rotation.y * -3) * 0.08);
  }
}
