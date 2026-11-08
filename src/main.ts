import "./style.css";
import * as THREE from "three";
import { Engine } from "./core/Engine";
import { InputManager } from "./core/InputManager";
import { Viewport } from "./core/Viewport";
import { Lighting } from "./world/Lighting";
import { DioramaChunk } from "./world/DioramaChunk";
import { Player } from "./entities/Player";
import { createCorruptedAswang } from "./entities/Mob";
import { HitSpark } from "./entities/HitSpark";
import { AgimatSystem } from "./combat/AgimatSystem";
import { CombatEngine } from "./combat/CombatEngine";
import { AudioManager } from "./audio/AudioManager";
import { HUD } from "./ui/HUD";
import { ComicOverlay } from "./ui/ComicOverlay";

const $ = (id: string) => document.getElementById(id)!;
const ZERO2 = new THREE.Vector2();

// --- Core -------------------------------------------------------------
const viewport = new Viewport($("viewport"));
const input = new InputManager($("app"));
const lighting = new Lighting(viewport.scene);
const audio = new AudioManager();
const hud = new HUD($("hud"));
const comics = new ComicOverlay($("comic-overlay"));

// --- World: 20m x 20m asphalt test pad --------------------------------
const testPad = DioramaChunk.createQuiapoBlock();
viewport.scene.add(testPad.root);
lighting.addLantern(new THREE.Vector3(-6, 3, -6));
lighting.addLantern(new THREE.Vector3(6.2, 4.4, 4), 14);
lighting.addQuiapoLights();

// --- Player: 1.0m x 1.8m billboard -----------------------------------
const player = new Player();
player.bounds = 9.5;
viewport.scene.add(player.root);
viewport.snapTo(player.position);

// --- Target dummy: Corrupted Aswang at (3, 0, 3) ------------------------
const aswang = createCorruptedAswang();
viewport.scene.add(aswang.root);
const sparks = new HitSpark();
const healSparks = new HitSpark(0x6dff9c);
viewport.scene.add(sparks.points, healSparks.points);
const sparkOrigin = new THREE.Vector3();

// --- Combat -----------------------------------------------------------
const agimat = new AgimatSystem();
const combat = new CombatEngine(agimat);
combat.audio = audio;
combat.register(player);
combat.register(aswang);
aswang.onStaggerBreak = () => audio.playStaggerBreak();
combat.onHit((e) => {
  if (e.target !== aswang) return;
  sparkOrigin.copy(aswang.position).setY(1.0);
  sparks.burst(sparkOrigin);
});

// Command Wheel execution (runs when the wheel selection is confirmed).
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
const engine = new Engine(() => viewport.render());
engine.onTimeDilationChange((on) => (on ? audio.playCommandEnter() : audio.playCommandExit()));

engine.add({
  update(dt, state, rawDt) {
    // dt = simulation delta (time-dilated); rawDt = real frame delta.
    input.update();

    if (input.consume("pause") && state !== "cutscene") engine.togglePause();

    if (state === "cutscene" && input.consume("confirm")) void comics.advance();

    if (state === "explore" || state === "combat") {
      // Holding Command opens the command HUD and dilates time (active pause).
      const commandHeld = input.isHeld("command");
      if (commandHeld !== hud.wheelOpen) {
        if (commandHeld) {
          hud.setWheelOpen(true);
        } else {
          // Released: execute the highlighted command, hide the wheel.
          hud.confirmSelection();
        }
      }
      // Always back to 1.0x once the wheel is closed (including after Guard).
      engine.setTimeDilation(commandHeld && hud.wheelOpen);

      if (commandHeld) {
        hud.selectByDirection(input.move.x, input.move.y);
        player.update(dt, ZERO2);
      } else {
        player.update(dt, input.move);
        if (input.consume("attack")) {
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
      aswang.update(dt, player.position);
      lighting.update(engine.elapsed);
      // Visual-only: real time so effects never freeze or crawl.
      sparks.update(rawDt);
      healSparks.update(rawDt);
      aswang.updateVisuals(rawDt);
      player.updateVisuals(rawDt);
    }

    // Camera/UI always run on unscaled time.
    viewport.follow(player.position);
    viewport.update(rawDt);
    player.faceCamera(viewport.camera);
    aswang.faceCamera(viewport.camera);
    lighting.track(player.position);

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
