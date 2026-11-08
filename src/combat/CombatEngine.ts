import * as THREE from "three";
import { AgimatSystem, type Element } from "./AgimatSystem";

export type Team = "player" | "enemy";

/** Anything that can be struck: a circle on the X/Z plane. */
export interface Hurtbox {
  readonly id: string;
  readonly team: Team;
  readonly radius: number;
  readonly position: THREE.Vector3;
  hp: number;
  takeDamage(amount: number, staggerDamage?: number): void;
}

export interface Hitbox {
  owner: Team;
  /** Centre on the ground plane (y ignored). */
  center: THREE.Vector3;
  radius: number;
  damage: number;
  stagger?: number;
  element?: Element;
  /** Seconds the hitbox stays active. */
  ttl: number;
  /** Ids already struck — each hitbox hits a target at most once. */
  readonly struck: Set<string>;
}

export interface CombatUnit {
  id: string;
  /** ATB gauge 0–1. */
  atb: number;
  /** Gauge fill per second. */
  atbRate: number;
}

export interface HitEvent {
  target: Hurtbox;
  damage: number;
  hitbox: Hitbox;
}

/**
 * Real-time hitbox detection (circle vs circle on X/Z) and ATB accumulation.
 * ATB fills continuously; full gauges unlock reflex commands in the HUD.
 */
export class CombatEngine {
  readonly hurtboxes = new Set<Hurtbox>();
  readonly units = new Map<string, CombatUnit>();
  private hitboxes: Hitbox[] = [];
  private readonly listeners = new Set<(e: HitEvent) => void>();

  constructor(readonly agimat: AgimatSystem) {}

  register(h: Hurtbox): void {
    this.hurtboxes.add(h);
  }

  unregister(h: Hurtbox): void {
    this.hurtboxes.delete(h);
  }

  addUnit(id: string, atbRate = 0.2): CombatUnit {
    const unit: CombatUnit = { id, atb: 0, atbRate };
    this.units.set(id, unit);
    return unit;
  }

  /** Spend a full ATB bar. Returns false if the gauge was not ready. */
  spendAtb(id: string): boolean {
    const unit = this.units.get(id);
    if (!unit || unit.atb < 1) return false;
    unit.atb = 0;
    return true;
  }

  spawnHitbox(h: Omit<Hitbox, "struck">): Hitbox {
    const hitbox: Hitbox = { ...h, center: h.center.clone(), struck: new Set() };
    this.hitboxes.push(hitbox);
    return hitbox;
  }

  onHit(fn: (e: HitEvent) => void): () => void {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }

  update(dt: number, active: boolean): void {
    if (active) {
      for (const unit of this.units.values()) {
        unit.atb = Math.min(1, unit.atb + unit.atbRate * dt);
      }
    }

    for (const hb of this.hitboxes) {
      for (const target of this.hurtboxes) {
        if (target.team === hb.owner || target.hp <= 0 || hb.struck.has(target.id)) continue;
        const dx = target.position.x - hb.center.x;
        const dz = target.position.z - hb.center.z;
        const r = target.radius + hb.radius;
        if (dx * dx + dz * dz > r * r) continue;

        hb.struck.add(target.id);
        const defElement = (target as { element?: Element }).element ?? "none";
        const weakness = (target as { weakness?: Element[] }).weakness ?? [];
        const damage =
          hb.owner === "player"
            ? this.agimat.resolveDamage(hb.damage, hb.element ?? "none", defElement, weakness)
            : hb.damage;
        target.takeDamage(damage, hb.stagger);
        this.listeners.forEach((fn) => fn({ target, damage, hitbox: hb }));
      }
      hb.ttl -= dt;
    }
    this.hitboxes = this.hitboxes.filter((h) => h.ttl > 0);
  }
}
