import * as THREE from "three";
import type { Engine } from "../core/Engine";
import type { Viewport } from "../core/Viewport";
import type { AudioManager } from "../audio/AudioManager";
import type { CombatEngine } from "../combat/CombatEngine";
import type { HitSpark } from "../entities/HitSpark";
import type { Mob } from "../entities/Mob";
import { AMBUSH_HIT_DAMAGE, type Player } from "../entities/Player";
import { createDeliveryVan, FIRE_ESCAPE_DROP, GATE_Z, type DeliveryVan, type DioramaChunk } from "../world/DioramaChunk";
import type { Lighting } from "../world/Lighting";
import type { ComicOverlay, CutsceneStep } from "../ui/ComicOverlay";
import type { HUD } from "../ui/HUD";

const PORTRAIT = (name: string): string => `${import.meta.env.BASE_URL}assets/portraits/${name}.png`;
const COMICS = (name: string): string => `${import.meta.env.BASE_URL}assets/comics/${name}`;

// ---------------------------------------------------------------------------
// Script
// ---------------------------------------------------------------------------

export const QUEST_DELIVERY = "Deliver the pocket watch: walk to the far end of the alley";
export const QUEST_SURVIVE = "Survive the Aswang";
export const QUEST_ACT_I = "Act I: Get in Dante's van";

/** Phase 1 opener: Renzo at the back of the alley with the watch. */
export const DELIVERY_INTRO: CutsceneStep[] = [
  {
    speaker: "Renzo",
    portrait: PORTRAIT("renzo"),
    text: "*Quiapo, past midnight. The pocket watch ticks against Renzo's palm: one last delivery before dawn.*",
    layout: "banner",
    art: "seal",
  },
  {
    speaker: "Renzo",
    portrait: PORTRAIT("renzo"),
    text: "Lola's watch, to the man at the end of the alley. Easy money. Easy.",
  },
];

/** Phase 2 comic cut-in: the creature drops from the fire escape; Renzo's shock. */
export const AMBUSH_CUTIN: CutsceneStep[] = [
  {
    speaker: "???",
    text: "*Rusted iron screams overhead. Something heavy lands in the dark.*",
    layout: "right-split",
    art: "silhouette",
    flash: true,
    shake: true,
    autoAdvance: 1.1,
  },
  {
    speaker: "Renzo",
    portrait: PORTRAIT("renzo"),
    text: "Diyos ko... the lamps, they all went out. And that thing... it was on the fire escape the whole time.",
    layout: "left-split",
    art: "claws",
    shake: true,
  },
  {
    speaker: "Renzo",
    portrait: PORTRAIT("renzo"),
    text: "All I've got is a balisong... Walang atrasan. Walang atrasan. Say it like you mean it, Renzo.",
    layout: "left-split",
    art: "claws",
    // Frightened, out of his depth. The confident renzo_draws_blade.webp is saved for later acts.
    panelImage: COMICS("renzo_cornered.webp"),
    shake: true,
  },
];

/** Phase 4: Dante's rescue. */
export const EXTRACTION_SCENE: CutsceneStep[] = [
  {
    speaker: "Dante",
    portrait: PORTRAIT("dante"),
    text: "RENZO! Get in the van! Lola's seal is broken. That thing isn't supposed to be out of the Veil!",
    layout: "right-split",
    art: "blade",
    panelImage: COMICS("dante_assist.webp"),
    flash: true,
    shake: true,
  },
  {
    speaker: "Renzo",
    portrait: PORTRAIT("renzo"),
    text: "Dante?! You... you crashed through the gate. Of course you did.",
  },
];

// ---------------------------------------------------------------------------
// Director
// ---------------------------------------------------------------------------

export interface TutorialDeps {
  engine: Engine;
  comics: ComicOverlay;
  hud: HUD;
  viewport: Viewport;
  audio: AudioManager;
  lighting: Lighting;
  chunk: DioramaChunk;
  scene: THREE.Scene;
  player: Player;
  combat: CombatEngine;
  sparks: HitSpark;
  /** Always returns the live Aswang (it is respawned on restart). */
  getAswang: () => Mob;
  /** Called when the opening finishes and Renzo gets control (the van is waiting). */
  onComplete: () => void;
  /** Called once Renzo has climbed in and the van has pulled out: end of Act I. */
  onBoarded: () => void;
}

type Phase =
  | "idle"
  | "delivery"
  | "blackout"
  | "drop"
  | "ambush"
  | "survival"
  | "knockdown"
  | "headlights"
  | "crash"
  | "rescue"
  | "board"
  | "boarding"
  | "done";
type SurvivalStep = "command" | "counter" | "slash";

/** The walk-forward line that fires the blackout (Renzo starts around z=9.5). */
export const BLACKOUT_Z = 3;
const AMBUSH_SLASHES = 3;
const GRAVITY = 20;
const AMBUSH_LAND = new THREE.Vector3(-1.9, 0, -1.4);
const VAN_START_Z = 26;
const VAN_SWEEP_Z = 20;
/** Passenger door, relative to the parked van (it faces -Z; the right-hand door is +X). */
const VAN_DOOR = new THREE.Vector3(1.9, 0, -1.3);
/** How close (m) Renzo must get to the door marker to climb in. */
const BOARD_RADIUS = 1.1;

const easeOutCubic = (k: number) => 1 - Math.pow(1 - k, 3);
const easeInQuad = (k: number) => k * k;

/**
 * Drives the four-phase Quiapo opening:
 *  1 Delivery   – walk forward holding the pocket watch (painted into the unarmed sprite clips); crossing BLACKOUT_Z cuts the lamps.
 *  2 Ambush     – the Aswang drops from the fire escape; comic cut-in.
 *  3 Survival   – teach Command Mode, Counter-Dodge, then 3 balisong slashes.
 *  4 Extraction – the Aswang floors Renzo, headlights sweep, Dante's van bursts the gate.
 * and hands over to the ACT I title card.
 */
export class TutorialDirector {
  phase: Phase = "idle";
  private step: SurvivalStep = "command";
  private t = 0;
  private slashes = 0;
  private commandOpened = false;
  private van: DeliveryVan | null = null;
  private vy = 0;
  private dropFrom = new THREE.Vector3();
  private dropTime = 0;
  private startedCrash = false;
  private gateBurst = false;
  private aswangFlinch = false;
  private readonly from = new THREE.Vector3();
  private readonly tmp = new THREE.Vector3();
  private readonly knockFrom = new THREE.Vector3();
  private readonly knockTo = new THREE.Vector3();
  private aswangSlideFrom = new THREE.Vector3();
  private aswangSlideTo = new THREE.Vector3();
  private vanStopZ = 0;
  private marker: THREE.Mesh | null = null;
  private readonly focus = new THREE.Vector3();
  private readonly door = new THREE.Vector3();
  private readonly baseBoundsZ: number;
  private boardedHidden = false;
  private cardShown = false;

  constructor(private readonly d: TutorialDeps) {
    this.baseBoundsZ = d.player.boundsZ;
  }

  /**
   * Where the camera should look while the van is in play: between Renzo and the van (it parks toward
   * the camera, so following Renzo alone leaves it off-screen). Null = just follow Renzo.
   */
  get cameraFocus(): THREE.Vector3 | null {
    const { player } = this.d;
    switch (this.phase) {
      case "headlights":
      case "crash":
      case "rescue":
        if (!this.van) return null;
        return this.focus.copy(player.position).lerp(this.van.root.position, 0.45);
      case "board":
      case "boarding":
        return this.focus.copy(player.position).lerp(this.door, 0.5);
      default:
        return null;
    }
  }

  /** Whether the tutorial still owns the Aswang (the old stall-examine flow is bypassed). */
  get active(): boolean {
    return this.phase !== "idle" && this.phase !== "done";
  }

  /** Phase 1: Renzo at the back of the alley with the pocket watch. */
  begin(): void {
    const { player, hud } = this.d;
    this.reset();
    this.phase = "delivery";
    player.setWeaponVisible(false);
    player.setFear(0.25); // uneasy, not yet terrified
    hud.setQuest(QUEST_DELIVERY);
    void this.d.comics.play(DELIVERY_INTRO).then(() => {
      if (this.phase === "delivery") hud.setCoach("Walk forward: [WASD] / Left Stick");
    });
  }

  /** Back to a clean pre-tutorial state (restart). */
  reset(): void {
    const { lighting, chunk, scene, hud, player } = this.d;
    lighting.setStreetlights(true);
    chunk.setStreetlights(true);
    if (this.van) {
      scene.remove(this.van.root);
      this.van = null;
    }
    this.resetGate();
    this.clearMarker();
    player.root.visible = true;
    player.boundsZ = this.baseBoundsZ;
    this.boardedHidden = false;
    this.cardShown = false;
    hud.setCoach(null);
    player.setDowned(0);
    player.setWeaponVisible(true);
    player.setFear(0);
    this.d.getAswang().setPose(null);
    this.phase = "idle";
    this.step = "command";
    this.slashes = 0;
    this.commandOpened = false;
    this.startedCrash = false;
    this.gateBurst = false;
    this.aswangFlinch = false;
    this.t = 0;
  }

  /** A player slash connected with the Aswang. */
  notifySlashHit(): void {
    if (this.phase !== "survival" || this.step !== "slash") return;
    this.slashes++;
    this.d.player.setFear(1 - this.slashes * 0.2); // every landed cut steadies him a little
    if (this.slashes >= AMBUSH_SLASHES) {
      this.startKnockdown();
    } else {
      this.d.hud.setCoach(this.slashPrompt());
    }
  }

  /** A successful Counter-Dodge. */
  notifyCounter(): void {
    if (this.phase !== "survival") return;
    if (this.step === "counter") {
      this.step = "slash";
      this.slashes = 0;
      this.d.hud.setCoach(this.slashPrompt());
    }
  }

  update(rawDt: number): void {
    const dt = Math.min(rawDt, 0.05);
    const { player } = this.d;
    switch (this.phase) {
      case "delivery":
        if (player.position.z <= BLACKOUT_Z && !this.d.comics.active) this.startBlackout();
        break;
      case "blackout":
        this.t += dt;
        if (this.t >= 1.1) this.startDrop();
        break;
      case "drop":
        this.stepDrop(dt);
        break;
      case "survival":
        this.stepSurvival();
        // Renzo is meant to learn, not die: a direct hit still hurts but leaves 1 HP.
        if (player.hp < 1) player.hp = 1;
        break;
      case "knockdown":
        this.stepKnockdown(dt);
        break;
      case "headlights":
        this.stepHeadlights(dt);
        break;
      case "crash":
        this.stepCrash(dt);
        break;
      case "board":
        this.stepBoard(dt);
        break;
      case "boarding":
        this.stepBoarding(dt);
        break;
      default:
        break;
    }
  }

  // --- Phase 2: blackout + drop ------------------------------------------

  private startBlackout(): void {
    const { engine, lighting, chunk, hud, audio, player, viewport } = this.d;
    this.phase = "blackout";
    this.t = 0;
    engine.setFrozen(true);
    hud.setCoach(null);
    lighting.setStreetlights(false);
    chunk.setStreetlights(false);
    audio.playBassDrop(); // transformer dying
    viewport.shake(0.12, 0.3);
    hud.setQuest(QUEST_SURVIVE);
    player.setFear(0.7);
    hud.showToast("The streetlights die...", 1.6);
  }

  private startDrop(): void {
    const aswang = this.d.getAswang();
    this.phase = "drop";
    this.d.player.setFear(1);
    this.vy = 0;
    this.dropTime = 0;
    this.dropFrom.copy(FIRE_ESCAPE_DROP);
    aswang.root.position.copy(this.dropFrom);
    aswang.root.visible = true;
    aswang.setPose("leap", 0.45);
    aswang.faceToward(this.d.player.position);
    this.d.audio.playStaggerBreak(); // rusted iron screech
  }

  private stepDrop(dt: number): void {
    const aswang = this.d.getAswang();
    this.dropTime += dt;
    this.vy -= GRAVITY * dt;
    const p = aswang.root.position;
    p.y += this.vy * dt;
    // Glide sideways toward the landing spot while falling.
    const fall = Math.sqrt((2 * this.dropFrom.y) / GRAVITY);
    const k = Math.min(1, this.dropTime / fall);
    p.x = THREE.MathUtils.lerp(this.dropFrom.x, AMBUSH_LAND.x, k);
    p.z = THREE.MathUtils.lerp(this.dropFrom.z, AMBUSH_LAND.z, k);
    aswang.setPose("leap", 0.45 + 0.55 * k); // plummets with claws out
    if (p.y <= 0) {
      p.set(AMBUSH_LAND.x, 0, AMBUSH_LAND.z);
      this.land();
    }
  }

  private land(): void {
    const { viewport, audio, sparks, comics, combat, hud } = this.d;
    const aswang = this.d.getAswang();
    this.phase = "ambush";
    viewport.shake(0.5, 0.55);
    audio.playHit();
    aswang.setPose("telegraph", 0.55); // lands in a rearing roar while the comic plays
    this.tmp.copy(aswang.position).setY(0.2);
    sparks.burst(this.tmp, 26);
    void comics.play(AMBUSH_CUTIN).then(() => {
      // Cut-in over: release the Aswang and open the Survival lesson.
      combat.register(aswang);
      aswang.setPose(null);
      aswang.activate();
      this.d.player.drawBlade(); // thumb flicks the balisong open
      this.phase = "survival";
      this.step = "command";
      this.t = 0;
      this.slashes = 0;
      hud.setCoach("Hold [Q] / [L1] for COMMAND MODE: time slows to a crawl while you decide");
    });
  }

  // --- Phase 3: survival tutorial ----------------------------------------

  private stepSurvival(): void {
    const { hud } = this.d;
    const aswang = this.d.getAswang();
    if (this.step === "command") {
      if (hud.wheelOpen) this.commandOpened = true;
      // Learned once the wheel was opened and closed again, or when the first strike telegraph starts.
      const learned = this.commandOpened && !hud.wheelOpen;
      if (learned || aswang.state === "telegraph") {
        this.step = "counter";
        hud.setCoach(this.counterPrompt(aswang));
      }
    } else if (this.step === "counter") {
      hud.setCoach(this.counterPrompt(aswang));
    }
  }

  private counterPrompt(aswang: Mob): string {
    if (aswang.counterWindowOpen) return "NOW! Press [B] / Circle / [Shift]: COUNTER-DODGE!";
    if (aswang.state === "telegraph") return "Red strike warning! Wait for the flash, then [B] / Circle / [Shift]";
    if (aswang.state === "recovery") return "Missed it? Keep your distance: it will strike again";
    return "Let it close in. When the red cone flashes orange, press [B] / Circle / [Shift] to COUNTER-DODGE";
  }

  private slashPrompt(): string {
    return `Slash it! [Space] / [A] / Atk (${this.slashes}/${AMBUSH_SLASHES})`;
  }

  // --- Phase 4: knockdown, headlights, van -------------------------------

  private startKnockdown(): void {
    const { engine, hud, player } = this.d;
    const aswang = this.d.getAswang();
    this.phase = "knockdown";
    this.t = 0;
    engine.setFrozen(true);
    engine.setTimeDilation(false);
    hud.setCoach(null);
    // Aswang lunges to just in front of Renzo; Renzo is thrown back along the lunge.
    this.aswangSlideFrom.copy(aswang.position);
    this.tmp.subVectors(player.position, aswang.position).setY(0);
    if (this.tmp.lengthSq() < 1e-4) this.tmp.set(0, 0, 1);
    this.tmp.normalize();
    this.aswangSlideTo.copy(player.position).addScaledVector(this.tmp, -0.9).setY(0);
    this.knockFrom.copy(player.position);
    this.knockTo.copy(player.position).addScaledVector(this.tmp, 1.3);
    this.knockTo.x = THREE.MathUtils.clamp(this.knockTo.x, -3.2, 3.2);
    this.knockTo.z = Math.min(this.knockTo.z, 8);
    this.startedCrash = false;
  }

  private stepKnockdown(dt: number): void {
    const { player, viewport, hud, audio, sparks } = this.d;
    const aswang = this.d.getAswang();
    this.t += dt;
    // 0 - 0.25s: lunge
    const lunge = Math.min(1, this.t / 0.25);
    aswang.root.position.lerpVectors(this.aswangSlideFrom, this.aswangSlideTo, easeOutCubic(lunge));
    aswang.faceToward(player.position);
    aswang.setPose("attack", Math.min(1, this.t / 0.4)); // the lunge and claw swipe
    if (!this.startedCrash && this.t >= 0.25) {
      this.startedCrash = true; // reused as the "impact landed" flag
      player.takeDamage(AMBUSH_HIT_DAMAGE);
      player.flinch(1);
      player.setFear(1);
      if (player.hp < 1) player.hp = 1;
      viewport.shake(0.9, 0.7);
      hud.flashDamage(1);
      audio.playHit();
      this.tmp.copy(player.position).setY(1.0);
      sparks.burst(this.tmp, 24);
    }
    if (this.t >= 0.25) {
      const k = Math.min(1, (this.t - 0.25) / 0.3);
      player.root.position.lerpVectors(this.knockFrom, this.knockTo, easeOutCubic(k));
      player.setDowned(1); // the fall clip plays itself out
    }
    if (this.t >= 1.4) this.startHeadlights();
  }

  private startHeadlights(): void {
    this.d.getAswang().setPose("telegraph", 1); // rears back and snarls into the light
    const { scene, hud } = this.d;
    this.phase = "headlights";
    this.t = 0;
    this.van = createDeliveryVan();
    this.van.root.position.set(0, 0, VAN_START_Z);
    scene.add(this.van.root);
    hud.showToast("Headlights...", 1.4);
  }

  private stepHeadlights(dt: number): void {
    const van = this.van!;
    this.t += dt;
    // Sweep the beams across the alley (a van swinging in off the street), creeping closer.
    van.root.rotation.y = Math.sin((this.t / 2.0) * Math.PI * 2) * 0.55;
    van.root.position.z = THREE.MathUtils.lerp(VAN_START_Z, VAN_SWEEP_Z, Math.min(1, this.t / 2.0));
    if (this.t >= 2.1) {
      this.phase = "crash";
      this.t = 0;
      this.from.copy(van.root.position);
      van.root.rotation.y = 0;
      this.vanStopZ = this.d.player.position.z + 5.4;
      this.gateBurst = false;
      this.aswangFlinch = false;
      this.gateT = 0;
      this.flinchT = 0;
    }
  }

  private stepCrash(dt: number): void {
    const van = this.van!;
    const { viewport, audio, sparks } = this.d;
    const aswang = this.d.getAswang();
    this.t += dt;
    const DUR = 1.5;
    const k = Math.min(1, this.t / DUR);
    // Hard acceleration then the brakes: fast through the gate, stopped just behind Renzo.
    const speedK = k < 0.45 ? easeInQuad(k / 0.45) * 0.5 : 0.5 + easeOutCubic((k - 0.45) / 0.55) * 0.5;
    van.root.position.z = THREE.MathUtils.lerp(this.from.z, this.vanStopZ, speedK);

    // Front bumper crosses the gate line: the leaves burst inward.
    if (!this.gateBurst && van.root.position.z - 2.6 <= GATE_Z) {
      this.gateBurst = true;
      audio.playBassDrop();
      viewport.shake(0.8, 0.8);
      this.tmp.set(0, 1, GATE_Z);
      sparks.burst(this.tmp, 40);
    }
    if (this.gateBurst && this.d.chunk.gate) {
      const open = Math.min(1, this.gateElapsed(dt) / 0.35);
      this.d.chunk.gate.left.rotation.y = easeOutCubic(open) * 1.7;
      this.d.chunk.gate.right.rotation.y = -easeOutCubic(open) * 1.7;
    }

    // The headlights blind it: the Aswang recoils up the fire escape.
    if (this.gateBurst && !this.aswangFlinch) {
      this.aswangFlinch = true;
      this.aswangSlideFrom.copy(aswang.position);
      this.flinchT = 0;
    }
    if (this.aswangFlinch) {
      this.flinchT += dt;
      const f = Math.min(1, this.flinchT / 0.9);
      const e = easeOutCubic(f);
      aswang.faceToward(FIRE_ESCAPE_DROP);
      aswang.setPose("leap", 0.3 + 0.7 * f); // springs back up to the fire escape
      aswang.root.position.x = THREE.MathUtils.lerp(this.aswangSlideFrom.x, FIRE_ESCAPE_DROP.x, e);
      aswang.root.position.z = THREE.MathUtils.lerp(this.aswangSlideFrom.z, FIRE_ESCAPE_DROP.z, e);
      aswang.root.position.y = Math.sin(f * Math.PI) * 2.2 + FIRE_ESCAPE_DROP.y * f * f;
      if (f >= 1) {
        aswang.root.visible = false;
        this.d.combat.unregister(aswang);
      }
    }

    // Renzo stands back up once the van has stopped.
    if (this.t > DUR) this.d.player.setDowned(0); // the get-up clip plays the fall in reverse
    if (this.t >= DUR + 0.5) this.startRescue();
  }

  private flinchT = 0;
  private gateT = 0;
  private gateElapsed(dt: number): number {
    this.gateT += dt;
    return this.gateT;
  }

  private startRescue(): void {
    const { comics, player } = this.d;
    this.phase = "rescue";
    player.setDowned(0);
    void comics
      .play(EXTRACTION_SCENE)
      .then(() => this.titleCard())
      .then(() => this.beginBoardPhase());
  }

  // --- Phase 5: climb into Dante's van ------------------------------------

  /** Renzo has control again; a glowing ring marks the van's passenger door. */
  private beginBoardPhase(): void {
    const { hud, player, scene } = this.d;
    this.phase = "board";
    player.setFear(0.3); // shaken, but he has already fought something
    const van = this.van;
    if (van) {
      this.door.copy(VAN_DOOR).applyAxisAngle(THREE.Object3D.DEFAULT_UP, van.root.rotation.y).add(van.root.position);
    } else {
      this.door.set(1.9, 0, 6);
    }
    this.door.y = 0;
    // The door must be reachable even if the van parked beyond the usual walkable edge.
    player.boundsZ = Math.max(this.baseBoundsZ, this.door.z + 1);
    const ring = new THREE.Mesh(
      new THREE.RingGeometry(0.62, 0.82, 40).rotateX(-Math.PI / 2),
      new THREE.MeshBasicMaterial({ color: 0xffb347, transparent: true, opacity: 0.9, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide })
    );
    ring.position.copy(this.door).setY(0.06);
    ring.renderOrder = 4;
    scene.add(ring);
    this.marker = ring;
    hud.setQuest(QUEST_ACT_I);
    hud.setCoach("Dante: \"Get in, Renzo!\" Run to the van's glowing door");
    this.d.onComplete();
  }

  private clearMarker(): void {
    if (!this.marker) return;
    this.d.scene.remove(this.marker);
    this.marker.geometry.dispose();
    (this.marker.material as THREE.Material).dispose();
    this.marker = null;
  }

  private stepBoard(dt: number): void {
    const { player } = this.d;
    this.t += dt;
    if (this.marker) {
      const pulse = 1 + Math.sin(this.t * 5) * 0.12;
      this.marker.scale.set(pulse, 1, pulse);
      (this.marker.material as THREE.MeshBasicMaterial).opacity = 0.65 + Math.sin(this.t * 5) * 0.3;
    }
    const dx = player.position.x - this.door.x;
    const dz = player.position.z - this.door.z;
    if (dx * dx + dz * dz <= BOARD_RADIUS * BOARD_RADIUS) this.startBoarding();
  }

  private startBoarding(): void {
    const { engine, hud, player } = this.d;
    this.phase = "boarding";
    this.t = 0;
    this.boardedHidden = false;
    this.cardShown = false;
    engine.setFrozen(true);
    hud.setCoach(null);
    this.clearMarker();
    this.knockFrom.copy(player.position); // reused: where the walk to the door starts
    player.facing.set(-1, 0, 0);
  }

  private stepBoarding(dt: number): void {
    const { player, viewport, audio, comics, hud } = this.d;
    const van = this.van;
    this.t += dt;
    // 0 - 0.5s: step to the door.
    const walk = Math.min(1, this.t / 0.5);
    player.root.position.lerpVectors(this.knockFrom, this.door, easeOutCubic(walk));
    // 0.5s: in; the door slams.
    if (!this.boardedHidden && this.t >= 0.5) {
      this.boardedHidden = true;
      player.root.visible = false;
      audio.playHit();
      viewport.shake(0.3, 0.25);
    }
    // 0.9s onward: Dante reverses out through the broken gate.
    if (van && this.t >= 0.9) {
      const k = Math.min(1, (this.t - 0.9) / 1.6);
      van.root.position.z = THREE.MathUtils.lerp(this.vanStopZ, VAN_START_Z + 8, easeInQuad(k));
      if (k < 1) viewport.shake(0.05 + k * 0.08, 0.1);
    }
    // 1.8s: Act I closes on a title card, then the summary takes over.
    if (!this.cardShown && this.t >= 1.8) {
      this.cardShown = true;
      void comics
        .showTitleCard({ act: "End of Act I", title: "Ang Lumang Orasan", subtitle: "Next: Fort Santiago", hold: 1.8 })
        .then(() => {
          this.phase = "done";
          hud.setQuest("");
          this.d.onBoarded();
        });
    }
  }

  private titleCard(): Promise<void> {
    return this.d.comics.showTitleCard({
      act: "Act I",
      title: "Ang Lumang Orasan",
      subtitle: "Quiapo · 1:12 AM",
      hold: 2.0,
    });
  }

  private resetGate(): void {
    this.gateT = 0;
    const gate = this.d.chunk.gate;
    if (gate) {
      gate.left.rotation.y = 0;
      gate.right.rotation.y = 0;
    }
  }
}

