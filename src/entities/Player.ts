import * as THREE from "three";
import { Billboard } from "./Billboard";
import type { Hurtbox } from "../combat/CombatEngine";
import { createRenzoTexture } from "./ProceduralSprites";

const MOVE_SPEED = 4.2; // m/s
const ACCEL = 14;
const SLASH_TIME = 0.09;
/**
 * Renzo's opening kit: raw, desperate balisong slashes. Short reach, a small
 * arc and almost no recovery, so they come fast but trade damage for speed.
 */
export const SLASH_REACH = 0.7;
export const SLASH_RADIUS = 0.7;
export const SLASH_DAMAGE = 9;
export const SLASH_RECOVERY = 0.16;
/** Damage a direct Aswang hit deals to Renzo. */
export const AMBUSH_HIT_DAMAGE = 40;
/** Max distance to a locked target for attacks to snap toward it. */
export const AIM_SNAP_RANGE = 3.5;
/** Total length of the slash animation: matches the cooldown so the clip never overlaps the next. */
const SLASH_ANIM = SLASH_TIME + SLASH_RECOVERY;
const FLINCH_TIME = 0.45;
const DODGE_TIME = 0.26;
/** Seconds for the down clip to play out (fall) and to reverse (get up). */
const FALL_TIME = 0.55;
const GETUP_TIME = 0.9;
/** Ground speed (m/s) at which the walk clip plays at its authored pace. */
const WALK_REF_SPEED = 2.4;
const AURA_COLOR = 0xff7a1a;
const SLASH_COLOR = 0xdfe8ff;

/**
 * Renzo: billboard character with planar (X/Z) movement and a 3D weapon
 * socket that GLB weapons are parented to.
 */
export class Player extends Billboard implements Hurtbox {
  readonly id = "renzo";
  readonly team = "player" as const;
  readonly radius = 0.4;
  readonly velocity = new THREE.Vector3();
  /** Follows the painted hand and yaws to the facing direction. */
  readonly weaponSocket = new THREE.Object3D();
  /** 0..1 how rattled Renzo is: hunched, shaky, small. Eases toward `setFear`'s target. */
  fear = 0;
  /** Last non-zero facing on the ground plane. */
  readonly facing = new THREE.Vector3(0, 0, -1);

  maxHp = 120;
  hp = this.maxHp;
  /** Optional walkable half-extents on X and Z. */
  boundsX = Infinity;
  boundsZ = Infinity;
  /** Seconds until the next slash is allowed. */
  private slashCooldown = 0;

  private readonly desired = new THREE.Vector3();
  private readonly toLock = new THREE.Vector3();
  private readonly slash: THREE.Mesh<THREE.RingGeometry, THREE.MeshBasicMaterial>;
  private slashTimer = 0;
  private fearTarget = 0;
  private slashAnim = -1;
  private flinchT = 0;
  private dodgeT = 0;
  private armed = true;
  private walkSpeed = 0;
  private walkClock = 0;
  /** Last walk-cycle index a footstep fired for (-1 while not walking). */
  private stepCycle = -1;
  /** Fired once per walk-cycle (not per frame) while walking. */
  onStep: (() => void) | null = null;
  private idleClock = 0;
  private readonly lastPos = new THREE.Vector3(Infinity, 0, 0);
  private downedTarget = 0;
  private downedAmount = 0;
  /** Which view the walk/idle clips use: side (mirrored), front (south, to camera) or back (north). */
  private view: "side" | "front" | "back" = "side";
  /** Last horizontal side Renzo faced (+1 right, -1 left). */
  private sideSign = 1;

  constructor(texture?: THREE.Texture) {
    super({
      width: 1.0,
      height: 1.8,
      texture: texture ?? createRenzoTexture(),
      textureUrl: texture ? undefined : `${import.meta.env.BASE_URL}assets/sprites/renzo_idle.png`,
      // Baked by scripts/generate-sprite-normals.ts; the animated atlas loads its own _n/_r maps.
      normalMapUrl: texture ? undefined : `${import.meta.env.BASE_URL}assets/sprites/renzo_idle_n.png`,
      roughnessMapUrl: texture ? undefined : `${import.meta.env.BASE_URL}assets/sprites/renzo_idle_r.png`,
    });
    // Hand-drawn frames already carry the knife; the socket only hosts an optional GLB weapon.
    this.weaponSocket.name = "WeaponSocket";
    this.weaponSocket.position.set(0.4, 1.0, 0.1);
    this.weaponSocket.visible = false;
    this.root.add(this.weaponSocket);
    this.loadSheet(`${import.meta.env.BASE_URL}assets/sprites/renzo_sheet`);

    // Slash flash: a flat crescent on the ground plane in front of Renzo.
    const arc = new THREE.RingGeometry(0.35, 0.78, 20, 1, -Math.PI / 4, Math.PI / 2);
    arc.rotateX(-Math.PI / 2);
    this.slash = new THREE.Mesh(
      arc,
      new THREE.MeshBasicMaterial({
        color: SLASH_COLOR,
        transparent: true,
        opacity: 0,
        side: THREE.DoubleSide,
        depthWrite: false,
        blending: THREE.AdditiveBlending,
      })
    );
    this.slash.position.y = 0.9;
    this.slash.visible = false;
    this.root.add(this.slash);
  }

  /** Fire aura (emissive orange) on the weapon and slash trail. */
  setWeaponAura(on: boolean): void {
    this.weaponSocket.traverse((o) => {
      const m = (o as THREE.Mesh).material;
      if (m instanceof THREE.MeshStandardMaterial) {
        m.emissive.set(on ? AURA_COLOR : 0x000000);
        m.emissiveIntensity = on ? 1.6 : 1;
      }
    });
    this.slash.material.color.set(on ? AURA_COLOR : SLASH_COLOR);
  }

  /**
   * Begin an attack. If `lockTarget` is within AIM_SNAP_RANGE the facing vector
   * snaps toward it. Returns the (possibly snapped) attack direction.
   */
  get canAttack(): boolean {
    return this.slashCooldown <= 0;
  }

  attack(lockTarget: THREE.Vector3 | null): THREE.Vector3 {
    this.slashCooldown = SLASH_TIME + SLASH_RECOVERY;
    this.slashAnim = 0;
    if (lockTarget) {
      this.toLock.subVectors(lockTarget, this.root.position).setY(0);
      const d = this.toLock.length();
      if (d > 0.001 && d <= AIM_SNAP_RANGE) {
        this.facing.copy(this.toLock).divideScalar(d);
        this.faceSide();
      }
    }
    this.slash.rotation.y = Math.atan2(-this.facing.z, this.facing.x);
    this.slashTimer = SLASH_TIME;
    this.slash.visible = true;
    return this.facing;
  }

  /** Slash flash animation; pass the unscaled frame delta. */
  updateVisuals(unscaledDt: number, elapsed = performance.now() / 1000): void {
    this.slashCooldown = Math.max(0, this.slashCooldown - unscaledDt);
    this.animate(unscaledDt, elapsed);
    if (this.slashTimer <= 0) return;
    this.slashTimer = Math.max(0, this.slashTimer - unscaledDt);
    const k = this.slashTimer / SLASH_TIME;
    this.slash.material.opacity = k * 0.9;
    this.slash.scale.setScalar(1 + (1 - k) * 0.25);
    if (this.slashTimer === 0) this.slash.visible = false;
  }

  /** Where Renzo's nerve is at (0 = steady, 1 = terrified). Eased, so call it freely. */
  setFear(target: number): void {
    this.fearTarget = THREE.MathUtils.clamp(target, 0, 1);
  }

  /** Recoil from a hit (0..1 strength): plays the hurt clip. */
  flinch(strength = 1): void {
    this.flinchT = FLINCH_TIME * THREE.MathUtils.clamp(strength, 0.5, 1);
  }

  /** Renzo pulls his balisong: switches from the unarmed (pocket watch) clips to the armed ones. */
  drawBlade(): void {
    this.armed = true;
  }

  /** Knock down (1) or get up (0). The fall/get-up clip is scrubbed toward this target over time. */
  setDowned(amount: number): void {
    this.downedTarget = THREE.MathUtils.clamp(amount, 0, 1);
  }

  /**
   * Chooses the animation clip from movement and combat state. Real-time dt.
   * Priority: down > hurt > dodge > slash > walk > idle.
   */
  private animate(dt: number, elapsed: number): void {
    if (dt <= 0) dt = 1e-4;
    this.fear += (this.fearTarget - this.fear) * (1 - Math.exp(-3 * dt));

    // Fall plays faster than the get-up.
    const dDir = this.downedTarget - this.downedAmount;
    const dRate = dDir > 0 ? 1 / FALL_TIME : 1 / GETUP_TIME;
    this.downedAmount += Math.sign(dDir) * Math.min(Math.abs(dDir), dRate * dt);

    // Ground speed from real motion, so cutscenes and knockbacks read correctly.
    const p = this.root.position;
    if (this.lastPos.x === Infinity) this.lastPos.copy(p);
    const moved = Math.hypot(p.x - this.lastPos.x, p.z - this.lastPos.z) / dt;
    this.lastPos.copy(p);
    this.walkSpeed += (Math.min(moved, 7) - this.walkSpeed) * (1 - Math.exp(-14 * dt));

    if (this.flinchT > 0) this.flinchT = Math.max(0, this.flinchT - dt);
    if (this.dodgeT > 0) this.dodgeT = Math.max(0, this.dodgeT - dt);
    if (this.slashAnim >= 0) {
      this.slashAnim += dt;
      if (this.slashAnim >= SLASH_ANIM) this.slashAnim = -1;
    }

    let frame = -1;
    if (this.downedAmount > 0.001) {
      frame = this.clipFrame("down", this.downedAmount * 0.999);
    } else if (this.flinchT > 0) {
      frame = this.clipFrame("hurt", 1 - this.flinchT / FLINCH_TIME);
    } else if (this.dodgeT > 0) {
      frame = this.clipFrame("dodge", 1 - this.dodgeT / DODGE_TIME);
    } else if (this.slashAnim >= 0) {
      frame = this.clipFrame("slash", this.slashAnim / SLASH_ANIM);
    } else if (this.walkSpeed > 0.45) {
      const walkName = this.locomotionClip("walk");
      const c = this.sheet?.clips[walkName];
      const rate = THREE.MathUtils.clamp(this.walkSpeed / WALK_REF_SPEED, 0.6, 1.8);
      this.walkClock += dt * (c?.fps ?? 8) * rate;
      frame = this.loopClipFrame(walkName, this.walkClock);
      const cycle = Math.floor(this.walkClock / Math.max(1, c?.count ?? 8));
      if (cycle !== this.stepCycle) {
        this.stepCycle = cycle;
        this.onStep?.();
      }
      this.idleClock = 0;
    } else {
      const idleName = this.locomotionClip("idle");
      const c = this.sheet?.clips[idleName];
      // A rattled Renzo breathes fast and shallow.
      this.idleClock += dt * (c?.fps ?? 5) * (1 + this.fear * 1.4);
      frame = this.loopClipFrame(idleName, this.idleClock);
      this.walkClock = 0;
      this.stepCycle = -1;
    }
    if (frame >= 0) this.showFrame(frame);

    // Fear: a fine whole-body shiver (screen-space), strongest when standing still.
    const still = this.walkSpeed < 0.45 && this.downedAmount < 0.05 ? 1 : 0.25;
    this.sprite.position.x = Math.sin(elapsed * 43) * 0.012 * this.fear * still;
  }

  /**
   * @param move normalised input: x = right, y = forward (-Z)
   */
  update(dt: number, move: THREE.Vector2): void {
    this.desired.set(move.x, 0, -move.y).multiplyScalar(MOVE_SPEED);
    const t = 1 - Math.exp(-ACCEL * dt);
    this.velocity.lerp(this.desired, t);

    // Translate on X/Z only — no tilt, no vertical drift.
    this.root.position.x += this.velocity.x * dt;
    this.root.position.z += this.velocity.z * dt;
    this.clampToBounds();

    if (this.desired.lengthSq() > 0.01) {
      this.facing.copy(this.desired).normalize();
      // Mirror the sprite horizontally to face left/right.
      this.faceSide();
    }
  }

  /** Snap to a ground position (clamped to bounds) and face `lookAt`. Used by Counter-Dodge. */
  teleport(to: THREE.Vector3, lookAt: THREE.Vector3): void {
    this.root.position.x = to.x;
    this.root.position.z = to.z;
    this.clampToBounds();
    this.velocity.set(0, 0, 0);
    this.dodgeT = DODGE_TIME;
    this.facing.subVectors(lookAt, this.root.position).setY(0);
    if (this.facing.lengthSq() < 1e-6) this.facing.set(0, 0, -1);
    this.facing.normalize();
    this.faceSide();
  }

  /** Suffix of the front/back clips if the sheet has them for the current view, else null. */
  private viewSuffix(): "f" | "b" | null {
    if (!this.armed || this.view === "side") return null;
    const s = this.view === "front" ? "f" : "b";
    return this.sheet?.clips[`walk_${s}`] && this.sheet.clips[`idle_${s}`] ? s : null;
  }

  /**
   * Walk/idle clip name for the current view. Front/back clips (`walk_f`, `idle_f`, `walk_b`, `idle_b`)
   * exist only for the armed Renzo and once the art is in the sheet; otherwise fall back to the side clip.
   */
  private locomotionClip(kind: "walk" | "idle"): string {
    const s = this.viewSuffix();
    if (s) return `${kind}_${s}`;
    return this.armed ? kind : `${kind}_u`;
  }

  /** Pick side/front/back from the facing vector; mirror side art (and the weapon socket) to the facing side. */
  private faceSide(): void {
    const { x, z } = this.facing;
    if (Math.abs(x) > 0.1) this.sideSign = Math.sign(x);
    // Hysteresis: leave the current view only when the other axis clearly dominates (no flicker on diagonals).
    const bias = this.view === "side" ? 1.2 : 0.8;
    this.view = Math.abs(z) > Math.abs(x) * bias ? (z > 0 ? "front" : "back") : "side";
    // Front/back art is drawn as-is; only side art (which faces right) is mirrored.
    this.sprite.scale.x = this.viewSuffix() ? 1 : this.sideSign;
    this.weaponSocket.position.x = 0.4 * this.sideSign;
  }

  private clampToBounds(): void {
    const p = this.root.position;
    p.x = THREE.MathUtils.clamp(p.x, -this.boundsX, this.boundsX);
    p.z = THREE.MathUtils.clamp(p.z, -this.boundsZ, this.boundsZ);
  }

  /** Armed (balisong in hand) or not (pocket watch). Also toggles the optional GLB weapon socket. */
  setWeaponVisible(visible: boolean): void {
    this.armed = visible;
    if (!visible) this.weaponSocket.visible = false;
  }

  /** Attach a GLB weapon (e.g. the Apoy blade) at the hand; hidden until one is equipped. */
  equipWeapon(weapon: THREE.Object3D): void {
    this.weaponSocket.clear();
    this.weaponSocket.add(weapon);
    this.weaponSocket.visible = true;
  }

  takeDamage(amount: number): number {
    this.hp = Math.max(0, this.hp - amount);
    return amount;
  }
}
