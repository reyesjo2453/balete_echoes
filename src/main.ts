import "./style.css";
import * as THREE from "three";
import { Engine } from "./core/Engine";
import { InputManager } from "./core/InputManager";
import { Viewport } from "./core/Viewport";
import { Lighting } from "./world/Lighting";
import { DioramaChunk } from "./world/DioramaChunk";
import { Player } from "./entities/Player";
import { createCorruptedAswang, ASWANG_HIT_RANGE } from "./entities/Mob";
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
const testPad = DioramaChunk.createTestPlane();
viewport.scene.add(testPad.root);
lighting.addLantern(new THREE.Vector3(-6, 3, -6));
lighting.addLantern(new THREE.Vector3(6, 3, 4), 14);

// --- Player: 1.0m x 1.8m billboard -----------------------------------
const player = new Player();
player.bounds = 9.5;
viewport.scene.add(player.root);
viewport.snapTo(player.position);

// --- Target dummy: Corrupted Aswang at (3, 0, 3) ------------------------
const aswang = createCorruptedAswang();
viewport.scene.add(aswang.root);
const sparks = new HitSpark();
viewport.scene.add(sparks.points);
const ATTACK_DAMAGE = 12;
const sparkOrigin = new THREE.Vector3();

// --- Combat -----------------------------------------------------------
const agimat = new AgimatSystem();
const combat = new CombatEngine(agimat);
combat.register(player);
const playerUnit = combat.addUnit(player.id, 0.25);
hud.addUnit({ id: player.id, name: "Renzo", hp: player.hp, maxHp: player.maxHp, unit: playerUnit });

// Browsers require a gesture before audio can start.
const unlockAudio = () => void audio.unlock();
window.addEventListener("pointerdown", unlockAudio, { once: true });
window.addEventListener("keydown", unlockAudio, { once: true });

// --- Loop -------------------------------------------------------------
const engine = new Engine(() => viewport.render());

engine.add({
  update(dt, state) {
    input.update();

    if (input.consume("pause") && state !== "cutscene") engine.togglePause();

    if (state === "cutscene" && input.consume("confirm")) void comics.advance();

    if (state === "explore" || state === "combat") {
      // Holding Command opens the command HUD and dilates time (active pause).
      const commandHeld = input.isHeld("command");
      if (commandHeld !== hud.wheelOpen) hud.setWheelOpen(commandHeld);
      engine.setTimeDilation(commandHeld);

      if (commandHeld) {
        hud.selectByDirection(input.move.x, input.move.y);
        player.update(dt, ZERO2);
      } else {
        player.update(dt, input.move);
        if (input.consume("attack")) {
          const center = player.position.clone().addScaledVector(player.facing, 0.9);
          combat.spawnHitbox({ owner: "player", center, radius: 0.6, damage: 12, ttl: 0.12 });
          // Proximity trigger: Attack within range of the dummy lands a hit.
          if (aswang.state !== "dead" && aswang.isWithin(player.position, ASWANG_HIT_RANGE)) {
            aswang.takeDamage(ATTACK_DAMAGE);
            sparkOrigin.copy(aswang.position).setY(1.0);
            sparks.burst(sparkOrigin);
          }
        }
      }
    } else if (engine.timeDilated) {
      engine.setTimeDilation(false);
    }

    if (state !== "paused") {
      agimat.update(dt);
      combat.update(dt, state === "combat" || state === "explore");
      aswang.update(dt, player.position);
      sparks.update(dt);
      lighting.update(engine.elapsed);
    }

    // Billboard: copy the camera quaternion every tick.
    viewport.follow(player.position);
    viewport.update(dt);
    player.faceCamera(viewport.camera);
    aswang.faceCamera(viewport.camera);
    lighting.track(player.position);

    hud.update([{ id: player.id, name: "Renzo", hp: player.hp, maxHp: player.maxHp, unit: playerUnit }]);
    if (import.meta.env.DEV) {
      const p = player.position;
      hud.setDebug(
        `state ${state}\npos  ${p.x.toFixed(2)}, ${p.z.toFixed(2)}\nhour ${agimat.hour.toFixed(1)}`
      );
    }

    input.endFrame();
  },
});

engine.start();
