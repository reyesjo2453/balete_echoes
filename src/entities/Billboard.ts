import * as THREE from "three";

export interface BillboardOptions {
  width?: number;
  height?: number;
  texture?: THREE.Texture;
  shadowRadius?: number;
  /** PNG to load over `texture`; on failure the fallback texture stays. */
  textureUrl?: string;
}

/**
 * Camera-facing sprite plane (1.0m x 1.8m by default) with a soft circular
 * contact shadow on the ground. `root` is translated on X/Z only; the sprite
 * child copies the camera quaternion every tick.
 */
export class Billboard {
  readonly root = new THREE.Group();
  readonly sprite: THREE.Mesh<THREE.PlaneGeometry, THREE.MeshStandardMaterial>;
  readonly shadow: THREE.Mesh;

  private readonly spriteHeight: number;

  constructor(opts: BillboardOptions = {}) {
    const width = opts.width ?? 1.0;
    const height = opts.height ?? 1.8;
    this.spriteHeight = height;

    const material = new THREE.MeshStandardMaterial({
      map: opts.texture ?? createPlaceholderTexture(),
      transparent: true,
      alphaTest: 0.5,
      side: THREE.DoubleSide,
      roughness: 0.85,
      metalness: 0,
    });
    this.sprite = new THREE.Mesh(new THREE.PlaneGeometry(width, height), material);
    this.sprite.position.y = height / 2;
    this.sprite.castShadow = true;
    this.root.add(this.sprite);

    const r = opts.shadowRadius ?? width * 0.45;
    const shadowGeo = new THREE.CircleGeometry(r, 24);
    shadowGeo.rotateX(-Math.PI / 2);
    this.shadow = new THREE.Mesh(
      shadowGeo,
      new THREE.MeshBasicMaterial({
        map: createShadowTexture(),
        transparent: true,
        depthWrite: false,
        color: 0x000000,
      })
    );
    this.shadow.position.y = 0.01;
    this.shadow.renderOrder = 1;
    this.root.add(this.shadow);

    if (opts.textureUrl) this.loadTexture(opts.textureUrl);
  }

  /**
   * Async-load a PNG (alpha cut-out) and swap it in. The plane is resized to
   * the image aspect at the same height. Failures keep the current texture.
   */
  loadTexture(url: string): void {
    new THREE.TextureLoader().load(
      url,
      (tex) => {
        tex.colorSpace = THREE.SRGBColorSpace;
        tex.anisotropy = 4;
        const img = tex.image as { width: number; height: number };
        const aspect = img.width / img.height;
        this.sprite.geometry.dispose();
        this.sprite.geometry = new THREE.PlaneGeometry(this.spriteHeight * aspect, this.spriteHeight);
        const mat = this.sprite.material;
        mat.map?.dispose();
        mat.map = tex;
        mat.transparent = true;
        mat.alphaTest = 0.5;
        mat.needsUpdate = true;
      },
      undefined,
      () => console.info(`[Billboard] ${url} not found — using procedural fallback`)
    );
  }

  get position(): THREE.Vector3 {
    return this.root.position;
  }

  /** Face the camera. Call every frame inside the rAF tick. */
  faceCamera(camera: THREE.Camera): void {
    this.sprite.quaternion.copy(camera.quaternion);
  }
}

function createPlaceholderTexture(): THREE.CanvasTexture {
  const w = 128;
  const h = 230;
  const c = document.createElement("canvas");
  c.width = w;
  c.height = h;
  const ctx = c.getContext("2d")!;
  // Simple silhouette: head, torso, legs
  ctx.fillStyle = "#c9a24a";
  ctx.beginPath();
  ctx.arc(w / 2, 34, 22, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#3d5a80";
  ctx.fillRect(w / 2 - 28, 60, 56, 90);
  ctx.fillStyle = "#1f2a40";
  ctx.fillRect(w / 2 - 26, 150, 22, 76);
  ctx.fillRect(w / 2 + 4, 150, 22, 76);
  ctx.strokeStyle = "#e8e4d8";
  ctx.lineWidth = 3;
  ctx.strokeRect(1.5, 1.5, w - 3, h - 3);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

function createShadowTexture(): THREE.CanvasTexture {
  const s = 64;
  const c = document.createElement("canvas");
  c.width = c.height = s;
  const ctx = c.getContext("2d")!;
  const g = ctx.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
  g.addColorStop(0, "rgba(255,255,255,0.65)");
  g.addColorStop(1, "rgba(255,255,255,0)");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, s, s);
  // Used as alpha via the map; material colour is black.
  const tex = new THREE.CanvasTexture(c);
  return tex;
}
