import "./style.css";
import * as THREE from "three";
import { Engine } from "./core/Engine";
import { InputManager } from "./core/InputManager";
import { Viewport } from "./core/Viewport";
import { Lighting } from "./world/Lighting";
import { DioramaChunk } from "./world/DioramaChunk";
import { Player } from "./entities/Player";
import { createCorruptedAswang, ATTACK_DAMAGE, ATTACK_HITBOX_RADIUS, ATTACK_HITBOX_REACH } from "./entities/Mob";
import { Interactable, LootDrop, STALL_NODE_POSITION } from "./world/Interactable";
import { QUIAPO_AMBUSH_SCENE, QUEST_ACT_I, QUEST_ACT_II } from "./narrative/Scenes";
import { HitSpark } from "./entities/HitSpark";
import { AgimatSystem } from "./combat/AgimatSystem";
import { CombatEngine, BAYANIHAN_DAMAGE, GITING_MAX, GITING_PER_COUNTER } from "./combat/CombatEngine";
import { AudioManager } from "./audio/AudioManager";
import { HUD } from "./ui/HUD";
import { DamageNumbers } from "./ui/DamageNumbers";
import { ComicOverlay } from "./ui/ComicOverlay";

const $ = (id: string) => document.getElementById(id)!;
const ZERO2 = new THREE.Vector2();

// --- Core -------------------------------------------------------------
const viewport = new Viewport($("viewport"));
const input = new InputManager($("app"));
const lighting = new Lighting(viewport.scene);
const audio = new AudioManager();
const hud = new HUD($("hud"));
const damageNumbers = new DamageNumbers($("hud"));
const engine = new Engine(() => viewport.render());
const comics = new ComicOverlay($("comic-overlay"), engine);

// --- World: 20m x 20m asphalt test pad --------------------------------
const testPad = DioramaChunk.createQuiapoBlock();
viewport.scene.add(testPad.root);
lighting.addLantern(new THREE.Vector3(-6, 3, -6));
lighting.addLantern(new THREE.Vector3(6.2, 4.4, 4), 14);
lighting.addQuiapoLights();

// --- Interaction: sari-sari stall examine node ------------------------
const stallNode = new Interactable(STALL_NODE_POSITION, "[A] Siyasatin (Examine)", $("hud"));
viewport.scene.add(stallNode.root);

// --- Player: 1.0m x 1.8m billboard -----------------------------------
const player = new Player();
player.bounds = 9.5;
viewport.scene.add(player.root);
viewport.snapTo(player.position);

// --- Corrupted Aswang at (3, 0, 3): dormant until the ambush cutscene ends
const aswang = createCorruptedAswang();
viewport.scene.add(aswang.root);
const sparks = new HitSpark();
const healSparks = new HitSpark(0x6dff9c);
const cyanSparks = new HitSpark(0x4df0ff);
viewport.scene.add(sparks.points, healSparks.points, cyanSparks.points);
const sparkOrigin = new THREE.Vector3();

// --- Combat -----------------------------------------------------------
const agimat = new AgimatSystem();
const combat = new CombatEngine(agimat);
combat.audio = audio;
combat.register(player);
aswang.onStaggerBreak = () => audio.playStaggerBreak();
// The Aswang strikes with a short-lived enemy hitbox along its locked aim.
aswang.onAttack = (mob) => {
  combat.spawnHitbox({
    owner: "enemy",
    center: mob.position.clone().addScaledVector(mob.aim, ATTACK_HITBOX_REACH),
    radius: ATTACK_HITBOX_RADIUS,
    damage: ATTACK_DAMAGE,
    ttl: 0.15,
  });
};
combat.onHit((e) => {
  if (e.target === player) {
    sparkOrigin.copy(player.position).setY(1.0);
    sparks.burst(sparkOrigin);
    damageNumbers.spawn(sparkOrigin.clone().setY(2.1), e.damage, false);
    return;
  }
  if (e.target !== aswang) return;
  sparkOrigin.copy(aswang.position).setY(1.0);
  sparks.burst(sparkOrigin);
  damageNumbers.spawn(sparkOrigin.clone().setY(2.1), e.damage, e.amplified || e.crit);
  if (e.crit) hud.showToast("Critical!");
});

// Defeat: the dissolve finishes, then a loot drop appears where the Aswang fell.
let loot: LootDrop | null = null;
aswang.onDissolveComplete = (mob) => {
  combat.unregister(mob);
  viewport.scene.remove(mob.root);
  loot = new LootDrop(mob.position.clone().setY(0.5), $("hud"));
  viewport.scene.add(loot.root);
  loot.onInteract = () => {
    const drop = loot!;
    drop.disable();
    viewport.scene.remove(drop.root);
    audio.playVictoryJingle();
    engine.setFrozen(true);
    hud.showVictory(
      "Victory!",
      ["+1 Broken Chronometer Spring", "+1 Raw Spirit Brass", "+120 Ginhawa EXP"],
      () => engine.setFrozen(false)
    );
    hud.setQuest(QUEST_ACT_II);
  };
};

// Bayanihan Strike: Giting full -> frozen comic banner, 6 bursts, 150 true damage.
const BAYANIHAN_HITS = 6;
let strikeBusy = false;
function fireBayanihan(): void {
  if (strikeBusy || !combat.gitingReady) return;
  if (!aswang.locked) {
    hud.showToast("No target in range");
    return;
  }
  strikeBusy = true;
  const target = aswang;
  void comics
    .executeBayanihanStrike({
      hits: BAYANIHAN_HITS,
      onHit: (i) => {
        sparkOrigin.copy(target.position).setY(0.9 + (i % 3) * 0.3);
        (i % 2 === 0 ? cyanSparks : sparks).burst(sparkOrigin, 18);
        damageNumbers.spawn(sparkOrigin.clone().setY(2.1), Math.round(BAYANIHAN_DAMAGE / BAYANIHAN_HITS), true);
        audio.playHit();
      },
      onFinish: () => {
        combat.executeBayanihanStrike(target);
        audio.playBassDrop();
      },
    })
    .finally(() => {
      strikeBusy = false;
    });
}
hud.onBayanihan = fireBayanihan;

// Examine the stall -> ambush cutscene -> release the Aswang.
stallNode.onInteract = () => {
  stallNode.disable();
  void comics.play(QUIAPO_AMBUSH_SCENE).then(() => {
    combat.register(aswang);
    aswang.activate();
    hud.showToast("Corrupted Aswang!");
  });
};

let suppressCommand = false;
/** Real seconds of Counter-Dodge slow-motion left. */
let counterSlow = 0;
const COUNTER_SLOW_TIME = 0.3;
const COUNTER_BEHIND_DIST = 1.2;
const behindPos = new THREE.Vector3();

// Command Wheel execution (runs when the wheel selection is confirmed).
hud.setQuest(QUEST_ACT_I);
hud.onCommand = (cmd) => {
  const res = combat.executeCommand(cmd.id, player);
  if (!res.ok) {
    hud.showToast(res.message);
    return;
  }
  if (cmd.id === "item") {
    sparkOrigin.copy(player.position).setY(0.9);
    healSparks.burst(sparkOrigin, 28);
  }
  hud.showToast(res.message);
};
const playerUnit = combat.addUnit(player.id, 0.25);
hud.addUnit({ id: player.id, name: "Renzo", hp: player.hp, maxHp: player.maxHp, unit: playerUnit });

// Browsers require a gesture before audio can start.
const unlockAudio = () => void audio.unlock();
window.addEventListener("pointerdown", unlockAudio, { once: true });
window.addEventListener("keydown", unlockAudio, { once: true });

// --- Loop -------------------------------------------------------------
engine.onTimeDilationChange((on) => (on ? audio.playCommandEnter() : audio.playCommandExit()));

engine.add({
  update(dt, state, rawDt) {
    // dt = simulation delta (time-dilated); rawDt = real frame delta.
    input.update();

    if (input.consume("pause") && state !== "cutscene") engine.togglePause();

    if (state === "cutscene" && input.consume("confirm")) void comics.advance();

    if (hud.modalOpen && input.consume("confirm")) hud.closeModal();

    // Q taps fire Bayanihan when ready; that press must not also open the wheel.
    if (input.consume("bayanihan") && combat.gitingReady && !engine.frozen && !hud.wheelOpen) {
      suppressCommand = true;
      fireBayanihan();
    }
    if (!input.isHeld("command")) suppressCommand = false;

    if ((state === "explore" || state === "combat") && !engine.frozen) {
      // Holding Command opens the command HUD and dilates time (active pause).
      const commandHeld = input.isHeld("command") && !suppressCommand;
      if (commandHeld !== hud.wheelOpen) {
        if (commandHeld) {
          hud.setWheelOpen(true);
        } else {
          // Released: execute the highlighted command, hide the wheel.
          hud.confirmSelection();
        }
      }
      // Always back to 1.0x once the wheel is closed (including after Guard).
      counterSlow = Math.max(0, counterSlow - rawDt);
      engine.setTimeDilation((commandHeld && hud.wheelOpen) || counterSlow > 0);

      if (commandHeld) {
        hud.selectByDirection(input.move.x, input.move.y);
        player.update(dt, ZERO2);
      } else {
        player.update(dt, input.move);
        if (stallNode.ready && (input.consume("attack") || input.consume("confirm"))) {
          // ActionA near the stall examines it instead of swinging.
          stallNode.trigger();
        } else if (loot?.ready && (input.consume("attack") || input.consume("confirm"))) {
          loot.trigger();
        } else if (input.consume("dodge") && aswang.counterWindowOpen && aswang.triggerCounter()) {
          // Counter-Dodge: brief slow-mo, slip behind the Aswang, next hit crits.
          counterSlow = COUNTER_SLOW_TIME;
          player.teleport(aswang.behindPoint(player.position, COUNTER_BEHIND_DIST, behindPos), aswang.position);
          combat.nextHitCritBonus = 1;
          combat.addGiting(GITING_PER_COUNTER);
          hud.showToast("Counter! Next hit crits");
        } else if (input.consume("attack")) {
          const lock = aswang.locked ? aswang.position : null;
          const dir = player.attack(lock);
          const center = player.position.clone().addScaledVector(dir, 1.0);
          combat.spawnHitbox({
            owner: "player",
            center,
            radius: 0.9,
            damage: 12,
            ttl: 0.12,
            element: combat.apoyBladeActive ? "apoy" : "none",
          });
        }
      }
    } else if (engine.timeDilated) {
      engine.setTimeDilation(false);
    }
    player.setWeaponAura(combat.apoyBladeActive);

    if (state !== "paused") {
      // Simulation: scaled by time dilation.
      agimat.update(dt);
      combat.update(dt, state === "combat" || state === "explore");
      stallNode.update(player.position, rawDt);
      aswang.update(dt, player.position);
      lighting.update(engine.elapsed);
      // Visual-only: real time so effects never freeze or crawl.
      sparks.update(rawDt);
      healSparks.update(rawDt);
      cyanSparks.update(rawDt);
      loot?.update(player.position, rawDt);
      aswang.updateVisuals(rawDt);
      player.updateVisuals(rawDt);
    }

    // Camera/UI always run on unscaled time.
    viewport.follow(player.position);
    viewport.update(rawDt);
    player.faceCamera(viewport.camera);
    aswang.faceCamera(viewport.camera);
    lighting.track(player.position);

    const dom = viewport.renderer.domElement;
    damageNumbers.update(rawDt, viewport.camera, dom.clientWidth, dom.clientHeight);
    hud.setGiting(combat.giting, GITING_MAX, combat.gitingReady && !strikeBusy);
    hud.tick(rawDt);
    hud.update([{ id: player.id, name: "Renzo", hp: player.hp, maxHp: player.maxHp, unit: playerUnit }]);
    if (import.meta.env.DEV) {
      const p = player.position;
      hud.setDebug(
        `state ${state}\npos  ${p.x.toFixed(2)}, ${p.z.toFixed(2)}\nhour ${agimat.hour.toFixed(1)}\n` +
          `SP ${combat.sp}/${combat.maxSp}  Lunas ${combat.lunasCharges}  blade ${combat.apoyBladeTime.toFixed(1)}s`
      );
    }

    input.endFrame();
  },
});

engine.start();
