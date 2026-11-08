import * as THREE from "three";
import { Billboard, type BillboardOptions } from "./Billboard";
import type { Hurtbox } from "../combat/CombatEngine";
import type { Element } from "../combat/AgimatSystem";

export type MobState = "idle" | "chase" | "windup" | "attack" | "staggered" | "dead";

export interface MobConfig extends BillboardOptions {
  id: string;
  maxHp?: number;
  speed?: number;
  aggroRange?: number;
  attackRange?: number;
  staggerMax?: number;
  element?: Element;
  weakness?: Element[];
}

const WINDUP_TIME = 0.6;
const ATTACK_TIME = 0.25;
const STAGGER_TIME = 2.5;
const STAGGER_DECAY = 6; // gauge points per second when not being hit

/**
 * Enemy AI state controller with a stagger gauge. Filling the gauge breaks
 * the mob's guard for a few seconds, during which it takes bonus damage.
 */
export class Mob extends Billboard implements Hurtbox {
  readonly id: string;
  readonly team = "enemy" as const;
  readonly radius = 0.45;
  readonly maxHp: number;
  readonly staggerMax: number;
  readonly element: Element;
  readonly weakness: Element[];
  hp: number;
  stagger = 0;
  state: MobState = "idle";

  /** Fired the frame an attack lands so CombatEngine can open a hitbox. */
  onAttack: ((mob: Mob) => void) | null = null;

  private readonly speed: number;
  private readonly aggroRange: number;
  private readonly attackRange: number;
  private timer = 0;
  private sinceHit = 0;
  private readonly toTarget = new THREE.Vector3();

  constructor(cfg: MobConfig) {
    super(cfg);
    this.id = cfg.id;
    this.maxHp = this.hp = cfg.maxHp ?? 60;
    this.speed = cfg.speed ?? 2.4;
    this.aggroRange = cfg.aggroRange ?? 9;
    this.attackRange = cfg.attackRange ?? 1.3;
    this.staggerMax = cfg.staggerMax ?? 100;
    this.element = cfg.element ?? "none";
    this.weakness = cfg.weakness ?? [];
  }

  get isStaggered(): boolean {
    return this.state === "staggered";
  }

  update(dt: number, target: THREE.Vector3): void {
    this.timer -= dt;
    this.sinceHit += dt;
    if (this.state !== "staggered" && this.sinceHit > 1.5) {
      this.stagger = Math.max(0, this.stagger - STAGGER_DECAY * dt);
    }

    this.toTarget.subVectors(target, this.root.position).setY(0);
    const dist = this.toTarget.length();

    switch (this.state) {
      case "idle":
        if (dist < this.aggroRange) this.state = "chase";
        break;
      case "chase":
        if (dist > this.aggroRange * 1.5) {
          this.state = "idle";
        } else if (dist < this.attackRange) {
          this.state = "windup";
          this.timer = WINDUP_TIME;
        } else {
          this.toTarget.multiplyScalar((this.speed * dt) / dist);
          this.root.position.x += this.toTarget.x;
          this.root.position.z += this.toTarget.z;
        }
        break;
      case "windup":
        if (this.timer <= 0) {
          this.state = "attack";
          this.timer = ATTACK_TIME;
          this.onAttack?.(this);
        }
        break;
      case "attack":
        if (this.timer <= 0) this.state = "chase";
        break;
      case "staggered":
        if (this.timer <= 0) {
          this.state = "chase";
          this.stagger = 0;
        }
        break;
      case "dead":
        break;
    }
  }

  takeDamage(amount: number, staggerDamage = amount * 0.5): void {
    if (this.state === "dead") return;
    this.hp = Math.max(0, this.hp - amount);
    this.sinceHit = 0;
    if (this.hp === 0) {
      this.state = "dead";
      this.root.visible = false;
      return;
    }
    if (this.state !== "staggered") {
      this.stagger = Math.min(this.staggerMax, this.stagger + staggerDamage);
      if (this.stagger >= this.staggerMax) {
        this.state = "staggered";
        this.timer = STAGGER_TIME;
      }
    }
  }
}
