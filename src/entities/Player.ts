import * as THREE from "three";
import { Billboard } from "./Billboard";
import type { Hurtbox } from "../combat/CombatEngine";
import { createRenzoTexture } from "./ProceduralSprites";

const MOVE_SPEED = 4.2; // m/s
const ACCEL = 14;
const SLASH_TIME = 0.15;
/** Max distance to a locked target for attacks to snap toward it. */
export const AIM_SNAP_RANGE = 3.5;
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
  readonly weaponSocket = new THREE.Object3D();
  /** Last non-zero facing on the ground plane. */
  readonly facing = new THREE.Vector3(0, 0, -1);

  maxHp = 120;
  hp = this.maxHp;
  /** Optional bounds clamp (half-extent on X/Z). */
  bounds = Infinity;

  private readonly desired = new THREE.Vector3();
  private readonly toLock = new THREE.Vector3();
  private readonly slash: THREE.Mesh<THREE.RingGeometry, THREE.MeshBasicMaterial>;
  private slashTimer = 0;
  private readonly blade: THREE.Mesh<THREE.BoxGeometry, THREE.MeshStandardMaterial>;

  constructor(texture?: THREE.Texture) {
    super({
      width: 1.0,
      height: 1.8,
      texture: texture ?? createRenzoTexture(),
      textureUrl: texture ? undefined : `${import.meta.env.BASE_URL}assets/sprites/renzo_idle.png`,
    });
    this.weaponSocket.name = "WeaponSocket";
    this.weaponSocket.position.set(0.45, 1.0, 0.05);
    this.root.add(this.weaponSocket);

    // Placeholder blade so the fire aura has something to glow on until a GLB is equipped.
    this.blade = new THREE.Mesh(
      new THREE.BoxGeometry(0.06, 0.7, 0.06),
      new THREE.MeshStandardMaterial({ color: 0xb8c2d6, metalness: 0.6, roughness: 0.4, emissive: 0x000000 })
    );
    this.blade.position.y = 0.3;
    this.weaponSocket.add(this.blade);

    // Slash flash: a flat crescent on the ground plane in front of Renzo.
    const arc = new THREE.RingGeometry(0.55, 1.05, 20, 1, -Math.PI / 3, (Math.PI * 2) / 3);
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
  attack(lockTarget: THREE.Vector3 | null): THREE.Vector3 {
    if (lockTarget) {
      this.toLock.subVectors(lockTarget, this.root.position).setY(0);
      const d = this.toLock.length();
      if (d > 0.001 && d <= AIM_SNAP_RANGE) {
        this.facing.copy(this.toLock).divideScalar(d);
        if (Math.abs(this.facing.x) > 0.1) this.sprite.scale.x = Math.sign(this.facing.x);
        this.weaponSocket.position.x = 0.45 * this.sprite.scale.x;
      }
    }
    this.slash.rotation.y = Math.atan2(-this.facing.z, this.facing.x);
    this.slashTimer = SLASH_TIME;
    this.slash.visible = true;
    return this.facing;
  }

  /** Slash flash animation; pass the unscaled frame delta. */
  updateVisuals(unscaledDt: number): void {
    if (this.slashTimer <= 0) return;
    this.slashTimer = Math.max(0, this.slashTimer - unscaledDt);
    const k = this.slashTimer / SLASH_TIME;
    this.slash.material.opacity = k * 0.9;
    this.slash.scale.setScalar(1 + (1 - k) * 0.25);
    if (this.slashTimer === 0) this.slash.visible = false;
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
    if (Number.isFinite(this.bounds)) {
      this.root.position.x = THREE.MathUtils.clamp(this.root.position.x, -this.bounds, this.bounds);
      this.root.position.z = THREE.MathUtils.clamp(this.root.position.z, -this.bounds, this.bounds);
    }

    if (this.desired.lengthSq() > 0.01) {
      this.facing.copy(this.desired).normalize();
      // Mirror the sprite horizontally to face left/right.
      if (Math.abs(this.facing.x) > 0.1) this.sprite.scale.x = Math.sign(this.facing.x);
      this.weaponSocket.position.x = 0.45 * this.sprite.scale.x;
    }
  }

  /** Snap to a ground position (clamped to bounds) and face `lookAt`. Used by Counter-Dodge. */
  teleport(to: THREE.Vector3, lookAt: THREE.Vector3): void {
    this.root.position.x = THREE.MathUtils.clamp(to.x, -this.bounds, this.bounds);
    this.root.position.z = THREE.MathUtils.clamp(to.z, -this.bounds, this.bounds);
    this.velocity.set(0, 0, 0);
    this.facing.subVectors(lookAt, this.root.position).setY(0);
    if (this.facing.lengthSq() < 1e-6) this.facing.set(0, 0, -1);
    this.facing.normalize();
    if (Math.abs(this.facing.x) > 0.1) this.sprite.scale.x = Math.sign(this.facing.x);
    this.weaponSocket.position.x = 0.45 * this.sprite.scale.x;
  }

  equipWeapon(weapon: THREE.Object3D): void {
    this.weaponSocket.clear();
    this.weaponSocket.add(weapon);
  }

  takeDamage(amount: number): number {
    this.hp = Math.max(0, this.hp - amount);
    return amount;
  }
}
