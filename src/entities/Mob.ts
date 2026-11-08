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
  /** Never moves or attacks (training dummy); respawns shortly after dying. */
  stationary?: boolean;
  /** Show a floating HP bar and Stagger gauge above the sprite. */
  showBars?: boolean;
}

const WINDUP_TIME = 0.6;
const ATTACK_TIME = 0.25;
const STAGGER_TIME = 2.5;
const STAGGER_DECAY = 6; // gauge points per second when not being hit
const RESPAWN_TIME = 3;
const BAR_WIDTH = 1.2;
const BAR_HEIGHT = 0.09;
/** Training dummy defaults. */
export const ASWANG_POSITION = new THREE.Vector3(3, 0, 3);
export const ASWANG_HIT_RANGE = 2.5; // metres

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
  private readonly stationary: boolean;
  private hpFill: THREE.Mesh | null = null;
  private staggerFill: THREE.Mesh | null = null;

  constructor(cfg: MobConfig) {
    super(cfg);
    this.stationary = cfg.stationary ?? false;
    if (cfg.showBars) this.buildBars(cfg.height ?? 1.8);
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

    this.updateBars();
    if (this.stationary) {
      this.updateStationary();
      return;
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

  /** True if `point` is within `range` metres on the ground plane. */
  isWithin(point: THREE.Vector3, range: number): boolean {
    const dx = point.x - this.root.position.x;
    const dz = point.z - this.root.position.z;
    return dx * dx + dz * dz <= range * range;
  }

  private updateStationary(): void {
    if (this.state === "dead") {
      if (this.timer <= 0) {
        this.hp = this.maxHp;
        this.stagger = 0;
        this.state = "idle";
        this.root.visible = true;
      }
    } else if (this.state === "staggered" && this.timer <= 0) {
      this.state = "idle";
      this.stagger = 0;
    }
  }

  private buildBars(spriteHeight: number): void {
    const y = spriteHeight + 0.25;
    const make = (color: number, yOff: number): THREE.Mesh => {
      const bg = new THREE.Mesh(
        new THREE.PlaneGeometry(BAR_WIDTH, BAR_HEIGHT),
        new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.6, depthTest: false })
      );
      bg.position.set(0, y + yOff, 0.01);
      bg.renderOrder = 10;
      const fillGeo = new THREE.PlaneGeometry(BAR_WIDTH, BAR_HEIGHT);
      fillGeo.translate(BAR_WIDTH / 2, 0, 0); // anchor left edge so scale.x shrinks rightwards
      const fill = new THREE.Mesh(fillGeo, new THREE.MeshBasicMaterial({ color, depthTest: false }));
      fill.position.set(-BAR_WIDTH / 2, y + yOff, 0.02);
      fill.renderOrder = 11;
      // Sprite is camera-aligned, so children inherit billboarding. The sprite
      // is positioned at height/2; compensate so bars sit above its top.
      bg.position.y -= spriteHeight / 2;
      fill.position.y -= spriteHeight / 2;
      this.sprite.add(bg, fill);
      return fill;
    };
    this.hpFill = make(0xe0485c, 0);
    this.staggerFill = make(0xffc94a, -BAR_HEIGHT * 1.6);
  }

  private updateBars(): void {
    if (this.hpFill) this.hpFill.scale.x = Math.max(0.0001, this.hp / this.maxHp);
    if (this.staggerFill) {
      this.staggerFill.scale.x = Math.max(0.0001, this.stagger / this.staggerMax);
      (this.staggerFill.material as THREE.MeshBasicMaterial).color.set(
        this.state === "staggered" ? 0xffffff : 0xffc94a
      );
    }
  }

  takeDamage(amount: number, staggerDamage = amount * 0.5): void {
    if (this.state === "dead") return;
    this.hp = Math.max(0, this.hp - amount);
    this.sinceHit = 0;
    if (this.hp === 0) {
      this.state = "dead";
      this.timer = RESPAWN_TIME;
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

/** Stationary "Corrupted Aswang" target billboard at (3, 0, 3). */
export function createCorruptedAswang(): Mob {
  const mob = new Mob({
    id: "aswang-dummy",
    texture: createAswangTexture(),
    width: 1.1,
    height: 1.9,
    maxHp: 100,
    staggerMax: 60,
    stationary: true,
    showBars: true,
  });
  mob.root.position.copy(ASWANG_POSITION);
  return mob;
}

function createAswangTexture(): THREE.CanvasTexture {
  const w = 128;
  const h = 220;
  const c = document.createElement("canvas");
  c.width = w;
  c.height = h;
  const ctx = c.getContext("2d")!;
  ctx.fillStyle = "#4a1f3d";
  ctx.beginPath();
  ctx.ellipse(w / 2, 120, 44, 90, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#2a1226";
  ctx.beginPath();
  ctx.arc(w / 2, 36, 24, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#ff4a5e";
  ctx.fillRect(w / 2 - 14, 30, 8, 5);
  ctx.fillRect(w / 2 + 6, 30, 8, 5);
  ctx.strokeStyle = "#9b3fb0";
  ctx.lineWidth = 3;
  ctx.strokeRect(1.5, 1.5, w - 3, h - 3);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}
