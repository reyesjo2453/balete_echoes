import * as THREE from "three";

/** Layout of a packed frame-animation atlas (see scripts/animate-renzo.ts). */
export interface SheetManifest {
  image: string;
  cols: number;
  rows: number;
  cellW: number;
  cellH: number;
  /** Fraction of the cell height the standing figure occupies. */
  standFraction: number;
  /** Feet baseline as a fraction of cell height from the top. */
  groundFraction: number;
  clips: Record<string, { start: number; count: number; fps: number; loop: boolean; pingpong: boolean }>;
}

export interface BillboardOptions {
  width?: number;
  height?: number;
  texture?: THREE.Texture;
  shadowRadius?: number;
  /** PNG to load over `texture`; on failure the fallback texture stays. */
  textureUrl?: string;
  /** Tangent-space normal map; sprite normals then react to the diorama's point lights. */
  normalMap?: THREE.Texture;
  /** Roughness map (green channel). */
  roughnessMap?: THREE.Texture;
  /** Optional files loaded over the maps; missing files are ignored (flat-lit fallback). */
  normalMapUrl?: string;
  roughnessMapUrl?: string;
}

/**
 * Lit 2.5D camera-facing sprite plane (1.0m x 1.8m by default) with a soft
 * circular contact shadow on the ground. `root` is translated on X/Z only; the
 * sprite child copies the camera quaternion every tick, so its world-space
 * normal always points at the camera and the point lights of the diorama
 * (lanterns, neon, headlights) shade it like any other mesh. The material is a
 * MeshStandardMaterial with map / normalMap / roughnessMap and alphaTest 0.5.
 */
export class Billboard {
  readonly root = new THREE.Group();
  readonly sprite: THREE.Mesh<THREE.PlaneGeometry, THREE.MeshStandardMaterial>;
  readonly shadow: THREE.Mesh;

  private readonly spriteHeight: number;
  /** Ground-relative Y of the sprite centre when standing. */
  private baseY: number;
  protected sheet: SheetManifest | null = null;
  private sheetFrame = -1;
  private _mirror = false;

  constructor(opts: BillboardOptions = {}) {
    const width = opts.width ?? 1.0;
    const height = opts.height ?? 1.8;
    this.spriteHeight = height;

    const material = new THREE.MeshStandardMaterial({
      map: opts.texture ?? createPlaceholderTexture(),
      normalMap: opts.normalMap ?? null,
      roughnessMap: opts.roughnessMap ?? null,
      transparent: true,
      alphaTest: 0.5,
      side: THREE.DoubleSide,
      roughness: 0.85,
      metalness: 0,
    });
    if (opts.normalMap) material.normalScale.set(1, 1);
    this.sprite = new THREE.Mesh(new THREE.PlaneGeometry(width, height), material);
    this.baseY = height / 2;
    this.sprite.position.y = this.baseY;
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
    if (opts.normalMapUrl) this.loadMap(opts.normalMapUrl, "normalMap");
    if (opts.roughnessMapUrl) this.loadMap(opts.roughnessMapUrl, "roughnessMap");
  }

  /** Load a linear data texture (normal / roughness) onto the lit material. Failures are silent. */
  loadMap(url: string, slot: "normalMap" | "roughnessMap"): void {
    new THREE.TextureLoader().load(
      url,
      (tex) => {
        tex.colorSpace = THREE.NoColorSpace;
        const mat = this.sprite.material;
        mat[slot]?.dispose();
        mat[slot] = tex;
        mat.needsUpdate = true;
      },
      undefined,
      () => undefined
    );
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
        if (this.sheet) {
          tex.dispose(); // the animated atlas has already taken over
          return;
        }
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

  /**
   * Switch to frame-animation mode: `texture` is an atlas laid out per `manifest`.
   * The plane is resized so the standing figure is `spriteHeight` tall and the
   * feet sit on the root's ground plane; frames are then chosen with showFrame().
   */
  setSheet(texture: THREE.Texture, manifest: SheetManifest): void {
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.generateMipmaps = false; // no bleeding between neighbouring cells
    texture.minFilter = THREE.LinearFilter;
    texture.magFilter = THREE.LinearFilter;
    texture.wrapS = texture.wrapT = THREE.ClampToEdgeWrapping;
    texture.repeat.set(1 / manifest.cols, 1 / manifest.rows);
    this.sheet = manifest;
    const cellH = this.spriteHeight / manifest.standFraction;
    const cellW = (cellH * manifest.cellW) / manifest.cellH;
    this.sprite.geometry.dispose();
    this.sprite.geometry = new THREE.PlaneGeometry(cellW, cellH);
    // Children (HP bars, reticle) were laid out for a sprite centred at height/2: keep them where they were.
    const shift = this.baseY - cellH * (manifest.groundFraction - 0.5);
    this.sprite.children.forEach((c) => (c.position.y += shift));
    this.baseY = cellH * (manifest.groundFraction - 0.5);
    this.sprite.position.y = this.baseY;
    const mat = this.sprite.material;
    mat.map?.dispose();
    mat.map = texture;
    mat.transparent = true;
    mat.alphaTest = 0.5;
    mat.needsUpdate = true;
    this.sheetFrame = -1;
    this.showFrame(0);
  }

  /**
   * Flip the atlas horizontally via UVs (the sheet art faces right). Unlike scale.x this leaves
   * children such as HP bars unmirrored.
   */
  set mirror(value: boolean) {
    if (value === this._mirror) return;
    this._mirror = value;
    const f = this.sheetFrame;
    this.sheetFrame = -1;
    if (f >= 0) this.showFrame(f);
  }

  get mirror(): boolean {
    return this._mirror;
  }

  /** Show atlas cell `index` (row-major). No-op until setSheet() has run. */
  showFrame(index: number): void {
    const m = this.sheet;
    const tex = this.sprite.material.map;
    if (!m || !tex || index === this.sheetFrame) return;
    this.sheetFrame = index;
    const col = index % m.cols;
    const row = Math.floor(index / m.cols);
    tex.repeat.x = (this._mirror ? -1 : 1) / m.cols;
    tex.offset.set((this._mirror ? col + 1 : col) / m.cols, 1 - (row + 1) / m.rows);
  }

  /** Atlas frame for a named clip at `progress` (0..1), or -1 when there is no such clip. */
  protected clipFrame(name: string, progress: number): number {
    const c = this.sheet?.clips[name];
    if (!c) return -1;
    return c.start + Math.min(c.count - 1, Math.max(0, Math.floor(progress * c.count)));
  }

  /** Looping clip frame at an accumulated clock measured in frames (honours ping-pong clips). */
  protected loopClipFrame(name: string, clock: number): number {
    const c = this.sheet?.clips[name];
    if (!c) return -1;
    const n = c.count;
    if (c.pingpong) {
      const period = Math.max(1, 2 * n - 2);
      const k = Math.floor(clock) % period;
      return c.start + (k < n ? k : period - k);
    }
    return c.start + (Math.floor(clock) % n);
  }

  /** Fetch `<base>.json` + the atlas image it names (next to it) and switch to frame animation. */
  loadSheet(base: string): void {
    const dir = base.slice(0, base.lastIndexOf("/") + 1);
    fetch(`${base}.json`)
      .then((r) => (r.ok ? (r.json() as Promise<SheetManifest>) : Promise.reject(new Error(String(r.status)))))
      .then(
        (manifest) =>
          new Promise<void>((resolve, reject) =>
            new THREE.TextureLoader().load(
              `${dir}${manifest.image}`,
              (tex) => {
                this.setSheet(tex, manifest);
                resolve();
              },
              undefined,
              reject
            )
          )
      )
      .catch(() => console.info(`[Billboard] ${base} sheet not found — static sprite`));
  }

  get position(): THREE.Vector3 {
    return this.root.position;
  }

  /** 0 = standing, 1 = lying on the ground (knockdown). */
  private downed = 0;
  private readonly rollQuat = new THREE.Quaternion();
  private static readonly AXIS_Z = new THREE.Vector3(0, 0, 1);

  /** Knock the sprite flat (1) or stand it back up (0). Applied on the next faceCamera(). */
  setDowned(amount: number): void {
    this.downed = THREE.MathUtils.clamp(amount, 0, 1);
    this.sprite.position.y = THREE.MathUtils.lerp(this.baseY, 0.3, this.downed);
  }

  /** Face the camera. Call every frame inside the rAF tick. */
  faceCamera(camera: THREE.Camera): void {
    this.sprite.quaternion.copy(camera.quaternion);
    if (this.downed > 0) {
      // Roll about the view axis so the sprite lies on its side.
      this.rollQuat.setFromAxisAngle(Billboard.AXIS_Z, (this.downed * Math.PI) / 2);
      this.sprite.quaternion.multiply(this.rollQuat);
    }
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
