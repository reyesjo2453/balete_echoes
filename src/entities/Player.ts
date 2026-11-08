import * as THREE from "three";
import { Billboard } from "./Billboard";
import type { Hurtbox } from "../combat/CombatEngine";

const MOVE_SPEED = 4.2; // m/s
const ACCEL = 14;

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

  constructor(texture?: THREE.Texture) {
    super({ width: 1.0, height: 1.8, texture });
    this.weaponSocket.name = "WeaponSocket";
    this.weaponSocket.position.set(0.45, 1.0, 0.05);
    this.root.add(this.weaponSocket);
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

  equipWeapon(weapon: THREE.Object3D): void {
    this.weaponSocket.clear();
    this.weaponSocket.add(weapon);
  }

  takeDamage(amount: number): void {
    this.hp = Math.max(0, this.hp - amount);
  }
}
