import * as THREE from "three";
import { PostFX, fxModeFromUrl } from "./PostFX";

/** Camera rig parameters. */
const CAMERA_PITCH_DEG = 45; // downward pitch
const CAMERA_DISTANCE = 14; // metres from target along the pitched view axis
const CAMERA_FOV = 40;
const CAMERA_FOLLOW_LERP = 6; // higher = snappier follow

// Title-screen fly-through: the alley is enclosed by 12m walls, so instead of
// circling it from outside the camera drifts up and down the lane.
const ORBIT_SPEED = 0.12; // rad/s
const ORBIT_LOOK_AT = new THREE.Vector3();

const MAX_PIXEL_RATIO = 2.0;

/**
 * Owns the Three.js scene, renderer (with soft shadow maps) and a
 * fixed-pitch follow camera rig.
 */
export class Viewport {
  readonly scene = new THREE.Scene();
  readonly camera: THREE.PerspectiveCamera;
  readonly renderer: THREE.WebGLRenderer;
  private shakeTime = 0;
  private shakeDuration = 0;
  private shakeAmp = 0;

  /** World-space point the camera rig looks at. */
  private readonly focus = new THREE.Vector3();
  private readonly desiredFocus = new THREE.Vector3();
  private readonly offset: THREE.Vector3;
  private readonly resizeObserver: ResizeObserver;
  private readonly cleanup: Array<() => void> = [];
  private mode: "follow" | "orbit" | "pan" = "follow";
  private orbitAngle = Math.PI * 0.25;
  private panT = 0;
  private panDuration = 1.5;
  private panDone: (() => void) | null = null;
  private readonly panFromPos = new THREE.Vector3();
  private readonly panFromQuat = new THREE.Quaternion();
  private readonly followQuat = new THREE.Quaternion();
  private readonly tmpPos = new THREE.Vector3();
  private fx: PostFX | null = null;
  private resizeRaf = 0;
  private lastW = 0;
  private lastH = 0;
  private lastDpr = 0;

  constructor(private readonly container: HTMLElement) {
    this.scene.background = new THREE.Color(0x0a1219);
    this.scene.fog = new THREE.Fog(0x0a1219, 20, 52);

    this.camera = new THREE.PerspectiveCamera(CAMERA_FOV, 1, 0.1, 200);

    const pitch = THREE.MathUtils.degToRad(CAMERA_PITCH_DEG);
    this.offset = new THREE.Vector3(
      0,
      Math.sin(pitch) * CAMERA_DISTANCE,
      Math.cos(pitch) * CAMERA_DISTANCE
    );
    // Fixed orientation: pitch down 45° about X, no yaw/roll.
    this.camera.rotation.set(-pitch, 0, 0, "YXZ");
    this.followQuat.copy(this.camera.quaternion);
    this.camera.position.copy(this.offset);

    this.renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: "high-performance" });
        this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.25;
    container.appendChild(this.renderer.domElement);
    const fxMode = fxModeFromUrl();
    if (fxMode !== "off") {
      this.fx = new PostFX(this.renderer, this.scene, this.camera, fxMode);
      this.renderer.toneMappingExposure = 1.4; // the grade and vignette take a little light back
    }

    // Container observer covers fold/unfold and split-screen; the window /
    // visualViewport / orientation hooks cover browsers that report those
    // transitions (and DPR changes) before the container box updates.
    this.resizeObserver = new ResizeObserver(() => this.scheduleResize());
    this.resizeObserver.observe(container);
    const listen = (target: EventTarget | null | undefined, type: string) => {
      if (!target) return;
      const fn = () => this.scheduleResize();
      target.addEventListener(type, fn);
      this.cleanup.push(() => target.removeEventListener(type, fn));
    };
    listen(window, "resize");
    listen(window, "orientationchange");
    listen(window.visualViewport, "resize");
    listen(screen.orientation, "change");
    this.resize();
  }

  /** Set the world point the rig should track (eased each frame). */
  follow(target: THREE.Vector3): void {
    this.desiredFocus.copy(target);
  }

  /** Snap the rig to the target immediately. */
  snapTo(target: THREE.Vector3): void {
    this.desiredFocus.copy(target);
    this.focus.copy(target);
    this.camera.position.copy(this.focus).add(this.offset);
  }

  /** Title-screen mode: slow circular pan around the diorama. */
  startOrbit(): void {
    this.mode = "orbit";
    this.updateOrbit(0);
  }

  /**
   * Leave the orbit: ease the camera to the fixed 45-degree rig tracking
   * the follow target, then resume normal following.
   */
  panToFollow(seconds = 1.6, onDone?: () => void): void {
    this.focus.copy(this.desiredFocus);
    this.panFromPos.copy(this.camera.position);
    this.panFromQuat.copy(this.camera.quaternion);
    this.panT = 0;
    this.panDuration = Math.max(0.01, seconds);
    this.panDone = onDone ?? null;
    this.mode = "pan";
  }

  private updateOrbit(dt: number): void {
    this.orbitAngle += ORBIT_SPEED * dt;
    const a = this.orbitAngle;
    const z = 2 + Math.sin(a * 0.8) * 8;
    this.camera.position.set(Math.sin(a * 1.9) * 2.4, 5.2 + Math.sin(a * 0.7) * 1.0, z);
    ORBIT_LOOK_AT.set(Math.sin(a * 1.3) * 1.2, 2.2, z - 9);
    this.camera.lookAt(ORBIT_LOOK_AT);
  }

  /** Camera shake: `amplitude` metres of decaying random offset over `seconds` (real time). */
  shake(amplitude: number, seconds = 0.4): void {
    this.shakeAmp = Math.max(this.shakeAmp * (this.shakeTime / Math.max(this.shakeDuration, 1e-3)), amplitude);
    this.shakeDuration = this.shakeTime = seconds;
  }

  update(dt: number): void {
    this.stepRig(dt);
    if (this.shakeTime > 0) {
      this.shakeTime = Math.max(0, this.shakeTime - dt);
      const k = this.shakeTime / this.shakeDuration;
      const a = this.shakeAmp * k * k;
      this.camera.position.x += (Math.random() - 0.5) * 2 * a;
      this.camera.position.y += (Math.random() - 0.5) * 2 * a;
      this.camera.position.z += (Math.random() - 0.5) * 2 * a * 0.5;
      if (this.shakeTime === 0) this.shakeAmp = 0;
    }
  }

  private stepRig(dt: number): void {
    if (this.mode === "orbit") {
      this.updateOrbit(dt);
      return;
    }
    if (this.mode === "pan") {
      this.panT = Math.min(1, this.panT + dt / this.panDuration);
      const k = this.panT * this.panT * (3 - 2 * this.panT); // smoothstep
      this.tmpPos.copy(this.focus).add(this.offset);
      this.camera.position.lerpVectors(this.panFromPos, this.tmpPos, k);
      this.camera.quaternion.slerpQuaternions(this.panFromQuat, this.followQuat, k);
      if (this.panT >= 1) {
        this.mode = "follow";
        const done = this.panDone;
        this.panDone = null;
        done?.();
      }
      return;
    }
    const t = 1 - Math.exp(-CAMERA_FOLLOW_LERP * dt);
    this.focus.lerp(this.desiredFocus, t);
    this.camera.position.copy(this.focus).add(this.offset);
  }

  render(dt = 1 / 60): void {
    if (this.fx) this.fx.render(dt);
    else this.renderer.render(this.scene, this.camera);
  }

  /** Coalesce bursts of resize events (fold animations fire many) into one per frame. */
  private scheduleResize(): void {
    if (this.resizeRaf) return;
    this.resizeRaf = requestAnimationFrame(() => {
      this.resizeRaf = 0;
      this.resize();
    });
  }

  resize(): void {
    const w = Math.max(1, this.container.clientWidth || window.innerWidth);
    const h = Math.max(1, this.container.clientHeight || window.innerHeight);
    // DPR can change when a foldable switches displays or the page is moved.
    const dpr = Math.min(window.devicePixelRatio || 1, MAX_PIXEL_RATIO);
    if (w === this.lastW && h === this.lastH && dpr === this.lastDpr) return;
    this.lastW = w;
    this.lastH = h;
    this.lastDpr = dpr;
    this.renderer.setPixelRatio(dpr);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h, false);
    this.fx?.setSize(w, h, Math.min(dpr, 1.5));
  }

  dispose(): void {
    this.resizeObserver.disconnect();
    this.cleanup.forEach((off) => off());
    cancelAnimationFrame(this.resizeRaf);
    this.renderer.dispose();
    this.renderer.domElement.remove();
  }
}
