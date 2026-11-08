import * as THREE from "three";

/** Camera rig parameters. */
const CAMERA_PITCH_DEG = 45; // downward pitch
const CAMERA_DISTANCE = 14; // metres from target along the pitched view axis
const CAMERA_FOV = 40;
const CAMERA_FOLLOW_LERP = 6; // higher = snappier follow

const ORBIT_RADIUS = 17;
const ORBIT_HEIGHT = 9;
const ORBIT_SPEED = 0.12; // rad/s
const ORBIT_LOOK_AT = new THREE.Vector3(0, 1, 0);

const MAX_PIXEL_RATIO = 2.0;

const AMBIENT_MOONLIGHT = 0x1a233a;

/**
 * Owns the Three.js scene, renderer (with soft shadow maps) and a
 * fixed-pitch follow camera rig.
 */
export class Viewport {
  readonly scene = new THREE.Scene();
  readonly camera: THREE.PerspectiveCamera;
  readonly renderer: THREE.WebGLRenderer;
  readonly ambient: THREE.AmbientLight;

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
  private resizeRaf = 0;
  private lastW = 0;
  private lastH = 0;
  private lastDpr = 0;

  constructor(private readonly container: HTMLElement) {
    this.scene.background = new THREE.Color(0x05070d);
    this.scene.fog = new THREE.Fog(0x05070d, 18, 48);

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
    this.renderer.toneMappingExposure = 1.0;
    container.appendChild(this.renderer.domElement);

    this.ambient = new THREE.AmbientLight(AMBIENT_MOONLIGHT, 1.6);
    this.scene.add(this.ambient);

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
    this.camera.position.set(
      ORBIT_LOOK_AT.x + Math.cos(this.orbitAngle) * ORBIT_RADIUS,
      ORBIT_HEIGHT + Math.sin(this.orbitAngle * 0.7) * 1.2,
      ORBIT_LOOK_AT.z + Math.sin(this.orbitAngle) * ORBIT_RADIUS
    );
    this.camera.lookAt(ORBIT_LOOK_AT);
  }

  update(dt: number): void {
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

  render(): void {
    this.renderer.render(this.scene, this.camera);
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
  }

  dispose(): void {
    this.resizeObserver.disconnect();
    this.cleanup.forEach((off) => off());
    cancelAnimationFrame(this.resizeRaf);
    this.renderer.dispose();
    this.renderer.domElement.remove();
  }
}
