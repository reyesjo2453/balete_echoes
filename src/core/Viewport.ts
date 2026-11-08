import * as THREE from "three";

/** Camera rig parameters. */
const CAMERA_PITCH_DEG = 45; // downward pitch
const CAMERA_DISTANCE = 14; // metres from target along the pitched view axis
const CAMERA_FOV = 40;
const CAMERA_FOLLOW_LERP = 6; // higher = snappier follow

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

  update(dt: number): void {
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
