import "./style.css";
import * as THREE from "three";
import { Engine } from "./core/Engine";
import { InputManager } from "./core/InputManager";
import { Viewport } from "./core/Viewport";
import { Lighting } from "./world/Lighting";
import { DioramaChunk, ALLEY_BOUNDS_X, ALLEY_BOUNDS_Z_MAX, ALLEY_BOUNDS_Z_MIN } from "./world/DioramaChunk";
import { Player, SLASH_DAMAGE, SLASH_RADIUS, SLASH_REACH } from "./entities/Player";
import { createCorruptedAswang, type Mob, ATTACK_DAMAGE, ATTACK_HITBOX_RADIUS, ATTACK_HITBOX_REACH } from "./entities/Mob";
import { LootDrop } from "./world/Interactable";
import { QUEST_ACT_II } from "./narrative/Scenes";
import { TutorialDirector } from "./narrative/TutorialScene";
import { HitSpark } from "./entities/HitSpark";
import { AgimatSystem } from "./combat/AgimatSystem";
import { CombatEngine, BAYANIHAN_DAMAGE, GITING_MAX, GITING_PER_COUNTER } from "./combat/CombatEngine";
import { AudioManager, type BgmState } from "./audio/AudioManager";
import { HUD } from "./ui/HUD";
import { DamageNumbers } from "./ui/DamageNumbers";
import { ComicOverlay } from "./ui/ComicOverlay";
import { TitleScreen } from "./ui/TitleScreen";
import { DemoSummary } from "./ui/DemoSummary";
import { DispatchBoard } from "./ui/DispatchBoard";
import { EpisodeSelect } from "./ui/EpisodeSelect";
import { showAssetChecklist } from "./ui/AssetChecklist";
import { EpisodeDirector, EPISODES, EPISODE_1 } from "./narrative/Episodes";

if (new URLSearchParams(location.search).has("assets")) void showAssetChecklist();

const $ = (id: string) => document.getElementById(id)!;
const ZERO2 = new THREE.Vector2();

// --- Core -------------------------------------------------------------
const viewport = new Viewport($("viewport"));
const input = new InputManager($("app"));
const lighting = new Lighting(viewport.scene);
const audio = new AudioManager();
audio.loadSfxFiles();
const hud = new HUD($("hud"));
const damageNumbers = new DamageNumbers($("hud"));
const engine = new Engine(() => viewport.render());
const comics = new ComicOverlay($("comic-overlay"), engine);

// --- World: enclosed 8m x 28m Quiapo alley, deep night ------------------
const alley = DioramaChunk.createQuiapoAlley();
viewport.scene.add(alley.root);
void alley.loadQuiapoModels(); // generated GLBs replace the procedural stall/lamp when present
lighting.addQuiapoLights();

// --- Player: 1.0m x 1.8m lit billboard, starting at the back of the alley
const PLAYER_SPAWN = new THREE.Vector3(0, 0, 9.5);
const player = new Player();
player.boundsX = ALLEY_BOUNDS_X;
player.boundsZ = ALLEY_BOUNDS_Z_MAX;
player.root.position.copy(PLAYER_SPAWN);
viewport.scene.add(player.root);
viewport.snapTo(player.position);
const ALLEY_Z_MIN = ALLEY_BOUNDS_Z_MIN;

// --- Corrupted Aswang at (3, 0, 3): dormant until the ambush cutscene ends
let aswang: Mob = createCorruptedAswang();
viewport.scene.add(aswang.root);
const sparks = new HitSpark();
const healSparks = new HitSpark(0x6dff9c);
const cyanSparks = new HitSpark(0xe0864a);
viewport.scene.add(sparks.points, healSparks.points, cyanSparks.points);
const sparkOrigin = new THREE.Vector3();

// --- Combat -----------------------------------------------------------
const agimat = new AgimatSystem();
const combat = new CombatEngine(agimat);
combat.audio = audio;
combat.register(player);
combat.onHit((e) => {
  if (e.target === player) {
    sparkOrigin.copy(player.position).setY(1.0);
    sparks.burst(sparkOrigin);
    damageNumbers.spawn(sparkOrigin.clone().setY(2.1), e.damage, false);
    // A direct Aswang hit is heavy: camera shake + red screen vignette.
    viewport.shake(0.85, 0.6);
    hud.flashDamage(Math.min(1, e.damage / 40));
    player.flinch(Math.min(1, e.damage / 40));
    return;
  }
  if (e.target !== aswang) return;
  if (e.hitbox.owner === "player") tutorial.notifySlashHit();
  sparkOrigin.copy(aswang.position).setY(1.0);
  sparks.burst(sparkOrigin);
  damageNumbers.spawn(sparkOrigin.clone().setY(2.1), e.damage, e.amplified || e.crit);
  if (e.crit) hud.showToast("Critical!");
  if (aswang.isStaggered) maxStaggerCombo = Math.max(maxStaggerCombo, ++staggerCombo);
});

// --- Run stats for the demo summary ------------------------------------
let playTime = 0;
let staggerCombo = 0;
let maxStaggerCombo = 0;
let gitingStrikes = 0;
const demoSummary = new DemoSummary($("app"));

// The mob's behaviour hooks; re-applied to each freshly spawned Aswang.
let loot: LootDrop | null = null;
function wireAswang(mob: Mob): void {
  mob.onStaggerBreak = () => {
    audio.playStaggerBreak();
    staggerCombo = 0;
  };
  // The Aswang strikes with a short-lived enemy hitbox along its locked aim.
  mob.onAttack = (m) => {
    combat.spawnHitbox({
      owner: "enemy",
      center: m.position.clone().addScaledVector(m.aim, ATTACK_HITBOX_REACH),
      radius: ATTACK_HITBOX_RADIUS,
      damage: ATTACK_DAMAGE,
      ttl: 0.15,
    });
  };
  // Defeat: the dissolve finishes, then a loot drop appears where the Aswang fell.
  mob.onDissolveComplete = (m) => {
    combat.unregister(m);
    viewport.scene.remove(m.root);
    loot = new LootDrop(m.position.clone().setY(0.5), $("hud"));
    viewport.scene.add(loot.root);
    loot.onInteract = collectLoot;
  };
}

function collectLoot(): void {
  const drop = loot;
  if (!drop) return;
  drop.disable();
  drop.dispose();
  viewport.scene.remove(drop.root);
  loot = null;
  audio.playVictoryJingle();
  engine.setFrozen(true);
  hud.showVictory(
    "Victory!",
    ["+1 Broken Chronometer Spring", "+1 Raw Spirit Brass", "+120 Ginhawa EXP"],
    // Stay frozen: the summary card decides what happens next.
    () => demoSummary.show({ timeElapsed: playTime, maxStaggerCombo, gitingStrikes })
  );
  hud.setQuest(QUEST_ACT_II);
}

function restartDemo(): void {
  // Despawn the current mob and any loot, then bring in a fresh dormant Aswang.
  combat.unregister(aswang);
  viewport.scene.remove(aswang.root);
  if (loot) {
    loot.dispose();
    viewport.scene.remove(loot.root);
    loot = null;
  }
  aswang = createCorruptedAswang();
  viewport.scene.add(aswang.root);
  wireAswang(aswang);

  player.teleport(PLAYER_SPAWN, PLAYER_SPAWN.clone().add(new THREE.Vector3(0, 0, -1)));
  player.hp = player.maxHp;
  combat.sp = combat.maxSp;
  combat.lunasCharges = 3;
  combat.giting = 0;
  combat.apoyBladeTime = 0;
  combat.guardActive = false;
  combat.nextHitCritBonus = 0;
  playerUnit.atb = 0;
  viewport.snapTo(player.position);
  engine.setFrozen(false);
  tutorial.reset();
  void episodes.start(episodes.current ?? EPISODE_1); // cold open -> board -> field (plays its own intro, which re-freezes the world)
  playTime = staggerCombo = maxStaggerCombo = gitingStrikes = 0;
}
demoSummary.onRestart = restartDemo;
demoSummary.onFreeRoam = () => {
  player.root.visible = true; // Renzo climbed out of the van for a look around
  engine.setFrozen(false);
  hud.showToast("Free Roam");
};
wireAswang(aswang);

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
        gitingStrikes++;
        audio.playBassDrop();
      },
    })
    .finally(() => {
      strikeBusy = false;
    });
}
hud.onBayanihan = fireBayanihan;

// --- Tutorial: delivery -> ambush -> survival -> extraction -> ACT I ------
const tutorial = new TutorialDirector({
  engine,
  comics,
  hud,
  viewport,
  audio,
  lighting,
  chunk: alley,
  scene: viewport.scene,
  player,
  combat,
  sparks,
  shockSparks: cyanSparks,
  getAswang: () => aswang,
  onComplete: () => {
    engine.setFrozen(false);
    engine.setState("explore");
  },
  // Renzo is in the van: the field scene is over. The episode director plays the cliffhanger, then the summary.
  onBoarded: () => episodes.notifyFieldComplete(),
  onGateQte: (ok) => episodes.gateQte(ok),
});

// --- Episodes: cold open -> dispatch board -> field (the Quiapo slice) -> cliffhanger ---
const board = new DispatchBoard($("app"), $("hud"));
const episodeSelect = new EpisodeSelect($("app"));
const episodes = new EpisodeDirector({
  comics,
  board,
  hud,
  player,
  beginField: () => tutorial.begin(),
  onEpisodeEnd: (episode, state) => {
    hud.setQuest(QUEST_ACT_II);
    demoSummary.show({
      timeElapsed: playTime,
      maxStaggerCombo,
      gitingStrikes,
      title: `EPISODE ${episode.id} COMPLETE`,
      extras: [
        ["Ledger (family debt)", String(state.ledger)],
        ["Jobs Taken", String(state.taken.length)],
        ["Watch Rewinds", String(state.rewinds)],
      ],
    });
  },
});
episodeSelect.onSelect = (episode) => void episodes.start(episode);

let suppressCommand = false;
/** Real seconds of Counter-Dodge slow-motion left. */
let counterSlow = 0;
const COUNTER_SLOW_TIME = 0.3;
const COUNTER_BEHIND_DIST = 1.2;
const behindPos = new THREE.Vector3();

// Command Wheel execution (runs when the wheel selection is confirmed).
hud.onSelectionChange = () => audio.playUiSelect();
hud.onCommand = (cmd) => {
  const res = combat.executeCommand(cmd.id, player);
  if (!res.ok) {
    hud.showToast(res.message);
    return;
  }
  if (cmd.id === "item") {
    sparkOrigin.copy(player.position).setY(0.9);
    healSparks.burst(sparkOrigin, 28);
    audio.playHeal();
  }
  hud.showToast(res.message);
};
player.onStep = () => audio.playFootstep();
const playerUnit =combat.addUnit(player.id, 0.25);
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
    // Scripted beats run on real time (the world is frozen under them) but must still honour Pause.
    if (state !== "paused") tutorial.update(rawDt);

    if (state === "title") title.poll();
    if (input.consume("pause") && state !== "cutscene" && state !== "title") engine.togglePause();

    // Demo summary card: confirm activates, left/right moves the highlight.
    if (demoSummary.open) {
      const dir = Math.abs(input.move.x) > 0.6 ? Math.sign(input.move.x) : 0;
      if (dir !== 0 && dir !== summaryDir) demoSummary.move(dir);
      summaryDir = dir;
      if (input.consume("confirm")) demoSummary.confirm();
    }

    if (state === "cutscene" && input.consume("confirm")) void comics.advance();

    if (hud.modalOpen && input.consume("confirm")) hud.closeModal();
    if ((state === "explore" || state === "combat") && !engine.frozen) playTime += rawDt;

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
        if (loot?.ready && (input.consume("attack") || input.consume("confirm"))) {
          loot.trigger();
        } else if (input.consume("dodge") && aswang.counterWindowOpen && aswang.triggerCounter()) {
          // Counter-Dodge: brief slow-mo, slip behind the Aswang, next hit crits.
          counterSlow = COUNTER_SLOW_TIME;
          audio.playDodge();
          tutorial.notifyCounter();
          player.teleport(aswang.behindPoint(player.position, COUNTER_BEHIND_DIST, behindPos), aswang.position);
          combat.nextHitCritBonus = 1;
          combat.addGiting(GITING_PER_COUNTER);
          hud.showToast("Counter! Next hit crits");
        } else if (player.canAttack && input.consume("attack")) {
          // Raw balisong slash: short reach, tight arc, near-instant recovery.
          const lock = aswang.locked ? aswang.position : null;
          const dir = player.attack(lock);
          const center = player.position.clone().addScaledVector(dir, SLASH_REACH);
          combat.spawnHitbox({
            owner: "player",
            center,
            radius: SLASH_RADIUS,
            damage: SLASH_DAMAGE,
            ttl: 0.1,
            element: combat.apoyBladeActive ? "apoy" : "none",
          });
        }
      }
    } else if (engine.timeDilated) {
      engine.setTimeDilation(false);
    }
    player.setWeaponAura(combat.apoyBladeActive);

    // Adaptive BGM follows the fight: ambient -> +rhythm -> +climax.
    const bgm: BgmState = strikeBusy
      ? "BAYANIHAN"
      : aswang.engaged && aswang.staggerRatio >= 0.8
        ? "STAGGERED"
        : aswang.engaged
          ? "COMBAT"
          : "EXPLORATION";
    if (bgm !== audio.bgmMix) audio.setBgmState(bgm);
    // File BGM: one song at a time (title / exploration / combat), crossfaded.
    audio.setBgmScene(state === "title" ? "title" : aswang.engaged ? "combat" : "exploration");

    if (state !== "paused") {
      // Simulation: scaled by time dilation.
      agimat.update(dt);
      combat.update(dt, state === "combat" || state === "explore");
      aswang.update(dt, player.position);
      if (aswang.engaged) {
        // The alley walls are solid for the Aswang too.
        const ap = aswang.root.position;
        ap.x = THREE.MathUtils.clamp(ap.x, -ALLEY_BOUNDS_X, ALLEY_BOUNDS_X);
        ap.z = THREE.MathUtils.clamp(ap.z, ALLEY_Z_MIN, ALLEY_BOUNDS_Z_MAX + 2);
      }
      lighting.update(engine.elapsed, rawDt);
      alley.setNeonLevel(lighting.neonFlicker);
      // Visual-only: real time so effects never freeze or crawl.
      sparks.update(rawDt);
      healSparks.update(rawDt);
      cyanSparks.update(rawDt);
      loot?.update(player.position, rawDt);
      aswang.updateVisuals(rawDt);
      player.updateVisuals(rawDt);
    }

    // Camera/UI always run on unscaled time.
    viewport.follow(tutorial.cameraFocus ?? player.position);
    viewport.update(rawDt);
    player.faceCamera(viewport.camera);
    aswang.faceCamera(viewport.camera);
    lighting.track(player.position);

    const dom = viewport.renderer.domElement;
    damageNumbers.update(rawDt, viewport.camera, dom.clientWidth, dom.clientHeight);
    hud.setGiting(combat.giting, GITING_MAX, combat.gitingReady && !strikeBusy);
    hud.tick(rawDt);
    hud.update([{ id: player.id, name: "Renzo", hp: player.hp, maxHp: player.maxHp, unit: playerUnit }]);
    if (import.meta.env.DEV && new URLSearchParams(location.search).has("debug")) {
      const p = player.position;
      hud.setDebug(
        `state ${state}\npos  ${p.x.toFixed(2)}, ${p.z.toFixed(2)}\nhour ${agimat.hour.toFixed(1)}\n` +
          `SP ${combat.sp}/${combat.maxSp}  Lunas ${combat.lunasCharges}  blade ${combat.apoyBladeTime.toFixed(1)}s`
      );
    }

    input.endFrame();
  },
});

// --- Title screen -----------------------------------------------------
let summaryDir = 0;
const title = new TitleScreen($("app"));
viewport.startOrbit();
title.onStart = () => {
  // First input is a user gesture: unlock Web Audio and start the BGM.
  void audio.unlock().then(() => {
    audio.startBgm(); // procedural stems: fallback while/if the files are unavailable
    audio.loadBgmFiles();
  });
  // Pan from the orbit to Renzo's 45-degree tracking position, then play.
  viewport.panToFollow(1.6, () => {
    engine.setState("explore");
    engine.setFrozen(true); // the world waits on the episode select
    episodeSelect.show(EPISODES);
  });
};

engine.start("title");

// Dev-only handle for automated visual checks (stripped from production builds).
if (import.meta.env.DEV) {
  (window as unknown as { __balete: unknown }).__balete = {
    player,
    engine,
    viewport,
    comics,
    hud,
    tutorial,
    alley,
    lighting,
    get aswang() {
      return aswang;
    },
  };
}

// Offline app shell (production builds only, so dev reloads are never stale).
if (import.meta.env.PROD && "serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register(`${import.meta.env.BASE_URL}sw.js`).catch(() => {});
  });
}
