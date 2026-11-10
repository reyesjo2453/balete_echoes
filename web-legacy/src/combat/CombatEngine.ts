import * as THREE from "three";
import { AgimatSystem, type Element } from "./AgimatSystem";
import type { AudioManager } from "../audio/AudioManager";

export type Team = "player" | "enemy";

/** Anything that can be struck: a circle on the X/Z plane. */
export interface Hurtbox {
  readonly id: string;
  readonly team: Team;
  readonly radius: number;
  readonly position: THREE.Vector3;
  hp: number;
  /** Applies the hit and returns the damage actually dealt (after mob-side modifiers). */
  takeDamage(amount: number, staggerDamage?: number): number;
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

/** Reflex commands the Command Wheel can execute. */
export type CommandId = "strike" | "agimat" | "guard" | "item";

export interface CommandResult {
  ok: boolean;
  message: string;
}

export const APOY_BLADE_SP_COST = 15;
export const APOY_BLADE_DURATION = 8;
export const APOY_BLADE_STAGGER_BONUS = 1.5;
export const LUNAS_HEAL = 250;
export const GUARD_REDUCTION = 0.7;
export const CRIT_MULTIPLIER = 2;
export const GITING_MAX = 100;
export const GITING_PER_ATTACK = 6;
export const GITING_PER_COUNTER = 25;
export const BAYANIHAN_DAMAGE = 150;

export interface HitEvent {
  target: Hurtbox;
  /** Damage actually dealt (includes e.g. the 2x stagger-break bonus). */
  damage: number;
  /** True when the target's own modifiers raised the damage above the base hit. */
  amplified: boolean;
  /** True when this hit was a critical strike. */
  crit: boolean;
  hitbox: Hitbox;
}

/**
 * Real-time hitbox detection (circle vs circle on X/Z) and ATB accumulation.
 * ATB fills continuously; full gauges unlock reflex commands in the HUD.
 */
export class CombatEngine {
  readonly hurtboxes = new Set<Hurtbox>();
  readonly units = new Map<string, CombatUnit>();
  /** Skill points spent by Agimat commands. */
  sp = 30;
  readonly maxSp = 30;
  /** Remaining Kagamitan (Lunas) charges. */
  lunasCharges = 3;
  /** Seconds of Apoy Blade remaining (stagger bonus + fire aura). */
  apoyBladeTime = 0;
  /** When true the next hit on the player is reduced by GUARD_REDUCTION. */
  guardActive = false;
  /** Giting (Valor) gauge, 0–GITING_MAX. Fills on landed attacks and counter-dodges. */
  giting = 0;
  /** Base critical-strike chance (0–1) for player hits. */
  critChance = 0;
  /** One-shot extra crit chance consumed by the next player hit (Counter-Dodge grants +1.0). */
  nextHitCritBonus = 0;
  /** Optional SFX sink: slash on player hitbox spawn, thud on player hits. */
  audio: AudioManager | null = null;
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
    if (h.owner === "player") this.audio?.playSlash();
    return hitbox;
  }

  onHit(fn: (e: HitEvent) => void): () => void {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }

  get gitingReady(): boolean {
    return this.giting >= GITING_MAX;
  }

  addGiting(amount: number): void {
    this.giting = Math.min(GITING_MAX, this.giting + amount);
  }

  /**
   * Bayanihan Strike finisher: 150 true damage (ignores element, weakness and
   * stagger multipliers), then the Giting gauge resets. Returns damage dealt.
   */
  executeBayanihanStrike(target: Hurtbox & { takeTrueDamage(amount: number): number }): number {
    if (!this.gitingReady) return 0;
    this.giting = 0;
    return target.takeTrueDamage(BAYANIHAN_DAMAGE);
  }

  get apoyBladeActive(): boolean {
    return this.apoyBladeTime > 0;
  }

  /**
   * Execute a Command Wheel action against `player`.
   * Callers are responsible for restoring time dilation and hiding the wheel.
   */
  executeCommand(cmd: CommandId, player: Hurtbox & { maxHp: number }): CommandResult {
    switch (cmd) {
      case "agimat":
        if (this.sp < APOY_BLADE_SP_COST) return { ok: false, message: "Not enough SP" };
        this.sp -= APOY_BLADE_SP_COST;
        this.apoyBladeTime = APOY_BLADE_DURATION;
        return { ok: true, message: "Apoy Blade" };
      case "item":
        if (this.lunasCharges <= 0) return { ok: false, message: "No Lunas left" };
        this.lunasCharges--;
        player.hp = Math.min(player.maxHp, player.hp + LUNAS_HEAL);
        return { ok: true, message: "Lunas" };
      case "guard":
        this.guardActive = true;
        return { ok: true, message: "Guard" };
      case "strike":
        return { ok: true, message: "Strike" };
    }
  }

  /** Ticks buff timers; call with simulation (time-dilated) delta. */
  update(dt: number, active: boolean): void {
    if (this.apoyBladeTime > 0) this.apoyBladeTime = Math.max(0, this.apoyBladeTime - dt);
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
        let damage =
          hb.owner === "player"
            ? this.agimat.resolveDamage(hb.damage, hb.element ?? "none", defElement, weakness)
            : hb.damage;
        let crit = false;
        if (hb.owner === "player") {
          crit = Math.random() < this.critChance + this.nextHitCritBonus;
          this.nextHitCritBonus = 0;
          if (crit) damage = Math.round(damage * CRIT_MULTIPLIER);
        }
        let stagger = hb.stagger;
        if (hb.owner === "player" && this.apoyBladeActive) {
          stagger = (stagger ?? damage * 0.5) * APOY_BLADE_STAGGER_BONUS;
        }
        if (target.team === "player" && this.guardActive) {
          damage = Math.round(damage * (1 - GUARD_REDUCTION));
          this.guardActive = false;
        }
        const dealt = target.takeDamage(damage, stagger);
        if (hb.owner === "player") {
          this.audio?.playHit();
          this.addGiting(GITING_PER_ATTACK);
        }
        this.listeners.forEach((fn) => fn({ target, damage: dealt, amplified: dealt > damage, crit, hitbox: hb }));
      }
      hb.ttl -= dt;
    }
    this.hitboxes = this.hitboxes.filter((h) => h.ttl > 0);
  }
}
