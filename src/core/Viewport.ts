import * as THREE from "three";

/** Camera rig parameters. */
const CAMERA_PITCH_DEG = 45; // downward pitch
const CAMERA_DISTANCE = 14; // metres from target along the pitched view axis
const CAMERA_FOV = 40;
const CAMERA_FOLLOW_LERP = 6; // higher = snappier follow

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
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.0;
    container.appendChild(this.renderer.domElement);

    this.ambient = new THREE.AmbientLight(AMBIENT_MOONLIGHT, 1.6);
    this.scene.add(this.ambient);

    this.resizeObserver = new ResizeObserver(() => this.resize());
    this.resizeObserver.observe(container);
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

  resize(): void {
    const w = this.container.clientWidth || window.innerWidth;
    const h = this.container.clientHeight || window.innerHeight;
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h, false);
  }

  dispose(): void {
    this.resizeObserver.disconnect();
    this.renderer.dispose();
    this.renderer.domElement.remove();
  }
}
