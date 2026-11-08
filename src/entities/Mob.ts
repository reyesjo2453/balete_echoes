import * as THREE from "three";
import { Billboard, type BillboardOptions } from "./Billboard";
import type { Hurtbox } from "../combat/CombatEngine";
import type { Element } from "../combat/AgimatSystem";
import { createAswangTexture } from "./ProceduralSprites";

export type MobState = "idle" | "chase" | "telegraph" | "attack" | "recovery" | "staggered" | "dying" | "dead";

export interface MobConfig extends BillboardOptions {
  id: string;
  maxHp?: number;
  speed?: number;
  aggroRange?: number;
  attackRange?: number;
  staggerMax?: number;
  element?: Element;
  weakness?: Element[];
  /** Never moves or attacks (training dummy). Stays dead once killed. */
  stationary?: boolean;
  /** Start dormant (hidden, no AI) until `activate()` is called. */
  dormant?: boolean;
  /** Show a floating HP bar and Stagger gauge above the sprite. */
  showBars?: boolean;
}

/** Red ground indicator duration before the strike lands. */
export const TELEGRAPH_TIME = 1.2;
/** Final stretch of the telegraph in which Dodge triggers a Counter-Dodge. */
export const COUNTER_WINDOW = 0.4;
const ATTACK_TIME = 0.25;
/** Seconds for the defeat dissolve (opacity -> 0, sprite grows outward). */
export const DISSOLVE_TIME = 0.8;
const DISSOLVE_GROWTH = 0.25;
const RECOVERY_TIME = 0.9;
const COUNTER_RECOVERY_TIME = 1.6;
/** Attack hitbox as spawned by the owner of `onAttack`. */
export const ATTACK_DAMAGE = 40;
export const ATTACK_HITBOX_REACH = 1.0;
export const ATTACK_HITBOX_RADIUS = 0.9;
const CONE_RADIUS = 2.2;
const CONE_HALF_ANGLE = Math.PI / 5;
const STAGGER_TIME = 4;
const STAGGER_DAMAGE_MULT = 2;
const STAGGER_TINT = 0xfff3a8;
/** Auto-lock reticle range (metres) around the mob. */
export const LOCK_RANGE = 3.5;
const STAGGER_DECAY = 6; // gauge points per second when not being hit
const BAR_WIDTH = 1.2;
const BAR_HEIGHT = 0.09;
/** Corrupted Aswang spawn point. */
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

  /** Ground direction the current/last attack points in (unit vector, locked late in the telegraph). */
  readonly aim = new THREE.Vector3(0, 0, 1);

  /** Fired the frame an attack lands so CombatEngine can open a hitbox. */
  onAttack: ((mob: Mob) => void) | null = null;
  /** Fired once the defeat dissolve finishes, just before the mob hides; spawn loot here. */
  onDissolveComplete: ((mob: Mob) => void) | null = null;
  /** Fired once when the stagger gauge hits 100%. */
  onStaggerBreak: ((mob: Mob) => void) | null = null;

  private readonly speed: number;
  private readonly aggroRange: number;
  private readonly attackRange: number;
  private timer = 0;
  private sinceHit = 0;
  private readonly toTarget = new THREE.Vector3();
  private readonly stationary: boolean;
  private hpFill: THREE.Mesh | null = null;
  private staggerFill: THREE.Mesh | null = null;
  private readonly reticle: THREE.LineSegments;
  private _locked = false;
  private dormant: boolean;
  private flashClock = 0;
  private dyingTime = 0;
  private recoveryTotal = RECOVERY_TIME;
  private animClock = 0;
  private poseClip: string | null = null;
  private poseProgress = 0;
  private readonly telegraph = new THREE.Group();
  private readonly coneFill: THREE.Mesh<THREE.CircleGeometry, THREE.MeshBasicMaterial>;
  private readonly coneEdge: THREE.Mesh<THREE.CircleGeometry, THREE.MeshBasicMaterial>;
  private readonly warning: THREE.Sprite;

  constructor(cfg: MobConfig) {
    super(cfg);
    this.stationary = cfg.stationary ?? false;
    this.dormant = cfg.dormant ?? false;
    this.root.visible = !this.dormant;
    if (cfg.showBars) this.buildBars(cfg.height ?? 1.8);
    this.reticle = this.buildReticle(cfg.width ?? 1, cfg.height ?? 1.8);

    // Telegraph: flat red cone on the ground that fills over TELEGRAPH_TIME.
    const makeCone = (opacity: number): THREE.Mesh<THREE.CircleGeometry, THREE.MeshBasicMaterial> => {
      const geo = new THREE.CircleGeometry(CONE_RADIUS, 28, -CONE_HALF_ANGLE, CONE_HALF_ANGLE * 2);
      geo.rotateX(-Math.PI / 2);
      return new THREE.Mesh(
        geo,
        new THREE.MeshBasicMaterial({ color: 0xff2020, transparent: true, opacity, depthWrite: false, side: THREE.DoubleSide })
      );
    };
    this.coneEdge = makeCone(0.22);
    this.coneFill = makeCone(0.5);
    this.coneFill.renderOrder = 3;
    this.coneEdge.renderOrder = 2;
    this.telegraph.position.y = 0.04;
    this.telegraph.add(this.coneEdge, this.coneFill);
    this.telegraph.visible = false;
    this.root.add(this.telegraph);

    this.warning = new THREE.Sprite(
      new THREE.SpriteMaterial({ map: createWarningTexture(), transparent: true, depthTest: false })
    );
    this.warning.scale.set(0.7, 0.7, 1);
    this.warning.position.y = (cfg.height ?? 1.8) + 0.9;
    this.warning.renderOrder = 13;
    this.warning.visible = false;
    this.root.add(this.warning);
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

  /** Awake and alive (not dormant, dying or dead). */
  get engaged(): boolean {
    return !this.dormant && this.state !== "dying" && this.state !== "dead" && this.state !== "idle";
  }

  /** Stagger gauge fill 0–1 (1 while broken). */
  get staggerRatio(): number {
    return this.state === "staggered" ? 1 : Math.min(1, this.stagger / this.staggerMax);
  }

  /** True while Renzo is inside LOCK_RANGE and the mob is alive. */
  get locked(): boolean {
    return this._locked;
  }

  /** UI-side animation (reticle spin); pass the unscaled frame delta. */
  updateVisuals(unscaledDt: number): void {
    if (this.state === "dying") {
      this.stepDissolve(unscaledDt);
      return;
    }
    this.reticle.visible = this._locked && !this.dormant;
    if (this._locked) this.reticle.rotation.z += unscaledDt * 1.8;
    this.flashClock += unscaledDt;
    const telegraphing = this.state === "telegraph";
    this.telegraph.visible = telegraphing;
    this.warning.visible = telegraphing;
    if (telegraphing) {
      const progress = 1 - Math.max(0, this.timer) / TELEGRAPH_TIME;
      this.telegraph.rotation.y = Math.atan2(-this.aim.z, this.aim.x);
      this.coneFill.scale.setScalar(Math.max(0.05, progress));
      // Warning icon flashes faster (and the cone brightens) in the counter window.
      const hot = this.counterWindowOpen;
      const rate = hot ? 26 : 10;
      this.warning.visible = Math.sin(this.flashClock * rate) > -0.2;
      this.coneFill.material.color.set(hot ? 0xff8a1a : 0xff2020);
    }
  }

  /** True during the last COUNTER_WINDOW seconds of the telegraph. */
  get counterWindowOpen(): boolean {
    return this.state === "telegraph" && this.timer <= COUNTER_WINDOW;
  }

  /** Wake a dormant mob: show it and let the AI run. */
  activate(): void {
    this.dormant = false;
    this.root.visible = true;
    this.state = "idle";
  }

  /**
   * Cancel the telegraphed strike (Counter-Dodge). Returns true if the
   * window was open; the mob then stumbles through a long recovery.
   */
  triggerCounter(): boolean {
    if (!this.counterWindowOpen) return false;
    this.state = "recovery";
    this.recoveryTotal = COUNTER_RECOVERY_TIME;
    this.timer = COUNTER_RECOVERY_TIME;
    return true;
  }

  /** Point `dist` metres past this mob, on the far side from `from` (ground plane). */
  behindPoint(from: THREE.Vector3, dist: number, out = new THREE.Vector3()): THREE.Vector3 {
    out.subVectors(this.root.position, from).setY(0);
    if (out.lengthSq() < 1e-6) out.set(0, 0, -1);
    out.normalize().multiplyScalar(dist).add(this.root.position);
    out.y = 0;
    return out;
  }

  /**
   * Hold a named animation clip at `progress` (0..1), overriding the AI-driven clip (cutscene moves
   * such as the fire-escape drop). Pass null to hand control back to the state machine.
   */
  setPose(clip: string | null, progress = 0): void {
    this.poseClip = clip;
    this.poseProgress = progress;
    if (clip) this.stepAnim(0);
  }

  /** Face a point on the ground plane (the sheet art faces right; left is a UV mirror). */
  faceToward(point: THREE.Vector3): void {
    const dx = point.x - this.root.position.x;
    if (Math.abs(dx) > 0.25) this.mirror = dx < 0;
  }

  /**
   * Pick the animation frame from the AI state. Phase timers advance on simulation time, so Command
   * Mode slows the animation together with the Aswang.
   */
  private stepAnim(dt: number): void {
    if (!this.sheet || this.dormant || this.state === "dying" || this.state === "dead") return;
    let frame = -1;
    if (this.poseClip) {
      frame = this.clipFrame(this.poseClip, this.poseProgress);
    } else {
      const fps = (name: string, d: number) => this.sheet?.clips[name]?.fps ?? d;
      switch (this.state) {
        case "telegraph": {
          // Rear up quickly, then hold the roar through the counter window.
          const k = 1 - Math.max(0, this.timer) / TELEGRAPH_TIME;
          frame = this.clipFrame("telegraph", Math.min(1, k * 1.4));
          break;
        }
        case "attack":
          frame = this.clipFrame("attack", 1 - Math.max(0, this.timer) / ATTACK_TIME);
          break;
        case "recovery":
          frame = this.clipFrame("recover", 1 - Math.max(0, this.timer) / this.recoveryTotal);
          break;
        case "staggered":
          this.animClock += dt * fps("stagger", 5);
          frame = this.loopClipFrame("stagger", this.animClock);
          break;
        case "chase":
          this.animClock += dt * fps("walk", 7);
          frame = this.loopClipFrame("walk", this.animClock);
          break;
        default:
          this.animClock += dt * fps("idle", 6);
          frame = this.loopClipFrame("idle", this.animClock);
      }
    }
    if (frame >= 0) this.showFrame(frame);
  }

  update(dt: number, target: THREE.Vector3): void {
    this.stepAnim(dt);
    if (this.dormant || this.state === "dying" || this.state === "dead") {
      this._locked = false;
      return;
    }
    this._locked = this.isWithin(target, LOCK_RANGE);
    this.timer -= dt;
    this.sinceHit += dt;
    if (this.state !== "staggered" && this.sinceHit > 1.5) {
      this.stagger = Math.max(0, this.stagger - STAGGER_DECAY * dt);
    }

    this.updateBars();
    // Multiplying the dark sprite by a pale tint barely shows, so also make it glow.
    const broken = this.state === "staggered";
    this.sprite.material.color.set(broken ? STAGGER_TINT : 0xffffff);
    this.sprite.material.emissive.set(broken ? STAGGER_TINT : 0x000000);
    this.sprite.material.emissiveIntensity = broken ? 0.6 + 0.2 * Math.sin(this.timer * 14) : 1;
    if (this.stationary) {
      this.updateStationary();
      return;
    }

    this.toTarget.subVectors(target, this.root.position).setY(0);
    const dist = this.toTarget.length();
    // Turn toward Renzo, but commit to a direction once the strike is under way.
    if (this.state !== "attack" && this.state !== "recovery" && !(this.state === "telegraph" && this.timer <= COUNTER_WINDOW)) {
      this.faceToward(target);
    }

    switch (this.state) {
      case "idle":
        if (dist < this.aggroRange) this.state = "chase";
        break;
      case "chase":
        if (dist > this.aggroRange * 1.5) {
          this.state = "idle";
        } else if (dist < this.attackRange) {
          this.state = "telegraph";
          this.timer = TELEGRAPH_TIME;
          if (dist > 1e-4) this.aim.copy(this.toTarget).divideScalar(dist);
        } else {
          this.toTarget.multiplyScalar((this.speed * dt) / dist);
          this.root.position.x += this.toTarget.x;
          this.root.position.z += this.toTarget.z;
        }
        break;
      case "telegraph":
        // Track Renzo until the counter window opens, then commit to the direction.
        if (this.timer > COUNTER_WINDOW && dist > 1e-4) this.aim.copy(this.toTarget).divideScalar(dist);
        if (this.timer <= 0) {
          this.state = "attack";
          this.timer = ATTACK_TIME;
          this.onAttack?.(this);
        }
        break;
      case "attack":
        if (this.timer <= 0) {
          this.state = "recovery";
          this.recoveryTotal = RECOVERY_TIME;
          this.timer = RECOVERY_TIME;
        }
        break;
      case "recovery":
        if (this.timer <= 0) this.state = "chase";
        break;
      case "staggered":
        if (this.timer <= 0) {
          this.state = "chase";
          this.stagger = 0;
        }
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
    if (this.state === "staggered" && this.timer <= 0) {
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

  /** Four rotating corner brackets drawn over the sprite (camera-aligned child). */
  private buildReticle(w: number, h: number): THREE.LineSegments {
    const half = Math.max(w, h) * 0.5 + 0.1;
    const len = half * 0.4;
    const pts: number[] = [];
    for (const [sx, sy] of [[1, 1], [-1, 1], [-1, -1], [1, -1]] as const) {
      const cx = sx * half;
      const cy = sy * half;
      pts.push(cx, cy - sy * len, 0, cx, cy, 0, cx, cy, 0, cx - sx * len, cy, 0);
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute("position", new THREE.Float32BufferAttribute(pts, 3));
    const line = new THREE.LineSegments(
      geo,
      new THREE.LineBasicMaterial({ color: 0xff5a3c, depthTest: false, transparent: true })
    );
    line.renderOrder = 12;
    line.visible = false;
    line.position.z = 0.03;
    this.sprite.add(line);
    return line;
  }

  private updateBars(): void {
    const clamp01 = (v: number) => Math.min(1, Math.max(0, v));
    if (this.hpFill) this.hpFill.scale.x = Math.max(0.0001, clamp01(this.hp / this.maxHp));
    if (this.staggerFill) {
      const ratio = this.state === "staggered" ? 1 : this.stagger / this.staggerMax;
      this.staggerFill.scale.x = Math.max(0.0001, clamp01(ratio));
      (this.staggerFill.material as THREE.MeshBasicMaterial).color.set(
        this.state === "staggered" ? 0xffffff : 0xffc94a
      );
    }
  }

  /** Unmodifiable damage (no stagger multiplier, no stagger gain). Returns damage dealt. */
  takeTrueDamage(amount: number): number {
    if (this.state === "dying" || this.state === "dead") return 0;
    const dealt = Math.min(this.hp, amount);
    this.hp -= dealt;
    this.sinceHit = 0;
    if (this.hp <= 0) this.beginDying();
    return dealt;
  }

  /** HP hit 0: enter DYING and start the dissolve. */
  private beginDying(): void {
    this.state = "dying";
    this.hp = 0;
    this.dyingTime = 0;
    this._locked = false;
    this.sprite.children.forEach((c) => (c.visible = false)); // bars + reticle
    this.telegraph.visible = false;
    this.warning.visible = false;
    const mat = this.sprite.material;
    mat.alphaTest = 0; // alpha-cutout would pop instead of fade
    mat.transparent = true;
    mat.color.set(0xffffff);
    mat.emissive.set(0x7a3cff);
    mat.emissiveIntensity = 0.8;
  }

  private stepDissolve(unscaledDt: number): void {
    this.dyingTime += unscaledDt;
    const k = Math.min(1, this.dyingTime / DISSOLVE_TIME);
    // The death clip plays out first; the body only fades over its last stretch.
    const fade = 1 - Math.min(1, Math.max(0, (k - 0.55) / 0.45));
    this.sprite.material.opacity = fade;
    this.sprite.scale.setScalar(1 + DISSOLVE_GROWTH * k * k);
    (this.shadow.material as THREE.MeshBasicMaterial).opacity = fade;
    const f = this.clipFrame("die", k);
    if (f >= 0) this.showFrame(f);
    if (k >= 1) {
      this.state = "dead";
      this.root.visible = false;
      this.onDissolveComplete?.(this);
    }
  }

  takeDamage(amount: number, staggerDamage = amount * 0.5): number {
    if (this.state === "dead" || this.state === "dying") return 0;
    if (this.state === "staggered") amount = Math.round(amount * STAGGER_DAMAGE_MULT);
    this.hp = Math.max(0, this.hp - amount);
    this.sinceHit = 0;
    if (this.hp === 0) {
      this.beginDying();
      return amount;
    }
    if (this.state !== "staggered") {
      this.stagger = Math.min(this.staggerMax, this.stagger + staggerDamage);
      if (this.stagger >= this.staggerMax) {
        this.state = "staggered";
        this.timer = STAGGER_TIME;
        this.onStaggerBreak?.(this);
      }
    }
    return amount;
  }
}

/** Yellow warning triangle with an exclamation mark. */
function createWarningTexture(): THREE.CanvasTexture {
  const c = document.createElement("canvas");
  c.width = c.height = 128;
  const g = c.getContext("2d")!;
  g.fillStyle = "#ffd31a";
  g.strokeStyle = "#1a1200";
  g.lineWidth = 8;
  g.lineJoin = "round";
  g.beginPath();
  g.moveTo(64, 10);
  g.lineTo(120, 112);
  g.lineTo(8, 112);
  g.closePath();
  g.fill();
  g.stroke();
  g.fillStyle = "#1a1200";
  g.fillRect(58, 44, 12, 38);
  g.beginPath();
  g.arc(64, 96, 7, 0, Math.PI * 2);
  g.fill();
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

/** Corrupted Aswang at (3, 0, 3): dormant until the Quiapo ambush cutscene ends. */
export function createCorruptedAswang(): Mob {
  const mob = new Mob({
    id: "aswang",
    texture: createAswangTexture(),
    textureUrl: `${import.meta.env.BASE_URL}assets/sprites/aswang_idle.png`,
    width: 1.1,
    height: 2.3,
    maxHp: 400,
    staggerMax: 60,
    speed: 2.2,
    aggroRange: 8,
    attackRange: 2.0,
    dormant: true,
    showBars: true,
  });
  mob.root.position.copy(ASWANG_POSITION);
  mob.loadSheet(`${import.meta.env.BASE_URL}assets/sprites/aswang_sheet`);
  return mob;
}
