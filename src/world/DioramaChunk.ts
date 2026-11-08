import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";

/** Full-size modular street chunk edge length in metres. */
export const CHUNK_SIZE = 40;

/** Quiapo alley: 8m wide (X), 28m long (Z), bounded by 12m tenement walls. */
export const ALLEY_WIDTH = 8;
export const ALLEY_LENGTH = 28;
export const ALLEY_WALL_HEIGHT = 12;
const HALF_W = ALLEY_WIDTH / 2;
const HALF_L = ALLEY_LENGTH / 2;
const WALL_THICK = 0.3;
/** Walkable half-extents (leaves a margin at the walls; the camera sits behind +Z). */
export const ALLEY_BOUNDS_X = HALF_W - 0.6;
export const ALLEY_BOUNDS_Z_MAX = 10.5;
export const ALLEY_BOUNDS_Z_MIN = -(HALF_L - 1.4);
/** Gate at the +Z mouth: low enough that the 45-degree camera sees over it. */
export const GATE_Z = HALF_L - 0.4;
const GATE_WALL_HEIGHT = 3.0;
const GATE_OPENING = 3.6;

export interface PropPlacement {
  url: string;
  position: [number, number, number];
  rotationY?: number;
  scale?: number;
}

/** Light anchor points shared with Lighting.addQuiapoLights(). */
export const QUIAPO_STALL_LIGHT = new THREE.Vector3(-1.4, 2.3, -11.2);
export const QUIAPO_NEON_LIGHT = new THREE.Vector3(3.1, 4.4, -4.5);
/** Street lamp light anchors (the lamp at index 0 is the one replaced by street_lamp.glb). */
export const QUIAPO_LAMP_LIGHTS = [new THREE.Vector3(1.5, 4.8, 7), new THREE.Vector3(2.3, 5.6, -1)];
/** Fire-escape platform Renzo's attacker drops from. */
export const FIRE_ESCAPE_DROP = new THREE.Vector3(-3.3, 6.05, -2.3);
export const STALL_POSITION = new THREE.Vector3(-2.4, 0, -11.2);

export interface AlleyGate {
  left: THREE.Group;
  right: THREE.Group;
}

/**
 * A modular street diorama. `createQuiapoAlley` builds the enclosed night
 * alley (GDD 5.A, Option B); there is deliberately no open flat-plane variant.
 */
/** Generated delivery-van model (loaded by DioramaChunk.loadQuiapoModels); createDeliveryVan() uses it when ready. */
let vanSource: THREE.Group | null = null;

export class DioramaChunk {
  readonly root = new THREE.Group();
  /** Gate leaves (pivot groups) the delivery van bursts through. Alley only. */
  gate: AlleyGate | null = null;
  private static loader = new GLTFLoader();
  private static cache = new Map<string, Promise<THREE.Group>>();
  private readonly streetBulbs: THREE.Mesh[] = [];
  private neonMaterial: THREE.MeshStandardMaterial | null = null;

  constructor(readonly origin = new THREE.Vector3(), size = CHUNK_SIZE, length = size) {
    this.root.name = "DioramaChunk";
    this.root.position.copy(origin);
    this.root.add(createAsphalt(size, length));
  }

  /**
   * Enclosed night alley (Option B): 8m x 28m, 12m tenement walls with lit and
   * dark windows, iron window grilles (rehas), rusted AC compressors, PVC
   * drainage pipes, a modular fire escape on the left, corrugated overhangs,
   * overhead high-voltage wire bundles, a sari-sari stall at the far end and a
   * (closed) delivery gate at the mouth. Wet asphalt with 0.04-roughness puddles.
   */
  static createQuiapoAlley(): DioramaChunk {
    const chunk = new DioramaChunk(new THREE.Vector3(), ALLEY_WIDTH, ALLEY_LENGTH);
    const lamps = createStreetLamps();
    lamps.traverse((o) => {
      if (o instanceof THREE.Mesh && o.userData.streetBulb) chunk.streetBulbs.push(o);
    });
    const gate = createGate();
    chunk.gate = gate.leaves;
    chunk.root.add(
      createTenementWalls(),
      createWallFixtures(),
      createFireEscape(),
      createOverhangs(),
      createWireBundles(),
      createStall(STALL_POSITION.x, STALL_POSITION.z),
      lamps,
      createNeonSign(),
      createPuddles(),
      createClutter(),
      gate.group
    );
    chunk.root.traverse((o) => {
      if (o instanceof THREE.Mesh && o.userData.neonTube) chunk.neonMaterial = o.material as THREE.MeshStandardMaterial;
    });
    chunk.root.traverse((o) => {
      if (o instanceof THREE.Mesh && o.name !== "Asphalt") o.castShadow = o.userData.noShadow ? false : true;
      if (o instanceof THREE.Mesh) o.receiveShadow = true;
    });
    return chunk;
  }

  /** Mirror the neon point light's flicker (0..~1.2) onto the glowing tubes. */
  setNeonLevel(level: number): void {
    if (this.neonMaterial) this.neonMaterial.emissiveIntensity = 2.2 * level;
  }

  /** Blackout: the street-lamp bulbs lose their glow (lights are switched in Lighting). */
  setStreetlights(on: boolean): void {
    for (const b of this.streetBulbs) {
      const m = b.material as THREE.MeshStandardMaterial;
      m.emissiveIntensity = on ? 3 : 0;
      m.color.set(on ? 0xffe2b0 : 0x1a1a1a);
    }
  }

  /**
   * Swap the procedural sari-sari store and street-lamp pole for the generated
   * GLB props. Each swap is independent: if a file is missing or fails to
   * parse, the procedural version simply stays.
   */
  async loadQuiapoModels(): Promise<void> {
    const base = `${import.meta.env.BASE_URL}assets/models/`;
    await Promise.allSettled([
      this.swapModel(`${base}sari_sari_stall.glb`, {
        position: [STALL_POSITION.x - 0.3, 0, STALL_POSITION.z],
        rotationY: Math.PI / 2, // open front toward the alley centre (+X)
        fit: { dimension: "footprint", size: 4.2 },
        replace: (o) => o.name === "SariSariStore",
      }),
      this.swapModel(`${base}street_lamp.glb`, {
        position: [3.3, 0, 7],
        fit: { dimension: "height", size: 5.4 },
        replace: (o) => o.userData.replaceable === true && o.name !== "Clutter",
      }),
      DioramaChunk.load(`${base}delivery_van.glb`).then((g) => {
        vanSource = g;
      }),
      this.addDressing(base),
    ]);
  }

  /** Street dressing from generated models; the procedural clutter is removed once any of them has loaded. */
  private async addDressing(base: string): Promise<void> {
    const items: Array<{ url: string; position: [number, number, number]; rotationY: number; height?: number; length?: number }> = [
      { url: "crates_barrels.glb", position: [-3.0, 0, 6.6], rotationY: 0.5, height: 1.5 },
      { url: "crates_barrels.glb", position: [3.0, 0, -12.4], rotationY: 2.1, height: 1.4 },
      { url: "trash_pile.glb", position: [3.0, 0, -7.0], rotationY: 0.3, height: 1.3 },
      { url: "tricycle.glb", position: [2.7, 0, -9.6], rotationY: Math.PI, length: 2.3 },
    ];
    const results = await Promise.allSettled(
      items.map(async (it) => {
        const source = await DioramaChunk.load(`${base}${it.url}`);
        const obj = source.clone(true);
        obj.rotation.y = it.rotationY;
        obj.updateMatrixWorld(true);
        const size = new THREE.Box3().setFromObject(obj).getSize(new THREE.Vector3());
        const k = it.height ? it.height / size.y : (it.length ?? 1) / Math.max(size.x, size.z);
        obj.scale.setScalar(k);
        obj.position.set(it.position[0], 0, it.position[2]);
        obj.updateMatrixWorld(true);
        obj.position.y -= new THREE.Box3().setFromObject(obj).min.y;
        obj.name = it.url;
        this.root.add(obj);
      })
    );
    if (results.some((r) => r.status === "fulfilled")) {
      this.root.getObjectByName("Clutter")?.removeFromParent();
    }
  }

  private async swapModel(
    url: string,
    opts: {
      position: [number, number, number];
      rotationY?: number;
      fit: { dimension: "footprint" | "height"; size: number };
      replace: (o: THREE.Object3D) => boolean;
    }
  ): Promise<void> {
    const source = await DioramaChunk.load(url);
    const obj = source.clone(true);
    obj.rotation.y = opts.rotationY ?? 0;
    // Generated meshes arrive normalised to a unit cube: scale to scene metres, stand on the ground.
    obj.updateMatrixWorld(true);
    const size = new THREE.Box3().setFromObject(obj).getSize(new THREE.Vector3());
    const extent = opts.fit.dimension === "height" ? size.y : Math.max(size.x, size.z);
    if (extent <= 0) throw new Error(`${url}: empty model`);
    obj.scale.setScalar(opts.fit.size / extent);
    obj.position.set(...opts.position);
    obj.updateMatrixWorld(true);
    obj.position.y -= new THREE.Box3().setFromObject(obj).min.y;
    obj.name = url.split("/").pop() ?? "Prop";

    // Only now (load succeeded) remove the placeholder geometry.
    const doomed: THREE.Object3D[] = [];
    this.root.traverse((o) => {
      if (opts.replace(o)) doomed.push(o);
    });
    doomed.forEach((o) => o.removeFromParent());
    this.root.add(obj);
  }

  async loadProps(props: PropPlacement[]): Promise<void> {
    await Promise.all(
      props.map(async (p) => {
        const source = await DioramaChunk.load(p.url);
        const obj = source.clone(true);
        obj.position.set(...p.position);
        obj.rotation.y = p.rotationY ?? 0;
        obj.scale.setScalar(p.scale ?? 1);
        this.root.add(obj);
      })
    );
  }

  dispose(): void {
    this.root.traverse((o) => {
      if (o instanceof THREE.Mesh) {
        o.geometry.dispose();
        const mats = Array.isArray(o.material) ? o.material : [o.material];
        mats.forEach((m) => m.dispose());
      }
    });
    this.root.removeFromParent();
  }

  private static load(url: string): Promise<THREE.Group> {
    let p = DioramaChunk.cache.get(url);
    if (!p) {
      p = DioramaChunk.loader.loadAsync(url).then((gltf) => {
        gltf.scene.traverse((o) => {
          if (o instanceof THREE.Mesh) {
            o.castShadow = true;
            o.receiveShadow = true;
          }
        });
        return gltf.scene;
      });
      DioramaChunk.cache.set(url, p);
    }
    return p;
  }
}

// ---------------------------------------------------------------------------
// Ground
// ---------------------------------------------------------------------------

/** Puddle roughness (spec: 0.04) and the base asphalt roughness it is mixed with. */
export const PUDDLE_ROUGHNESS = 0.04;
const ASPHALT_ROUGHNESS = 0.75;

/**
 * Wet asphalt: a dark diffuse base whose roughness map is mostly matte
 * (0.75) with glossy puddle blobs at 0.04, so lamp and neon light mirrors in
 * the standing water. The material roughness is 1 so the map is used as-is.
 */
function createAsphalt(width: number, length: number): THREE.Mesh {
  const geometry = new THREE.PlaneGeometry(width, length);
  geometry.rotateX(-Math.PI / 2);
  // The painted asphalt tiles every 4m; the roughness map (puddles) spans the whole ground once.
  const tile: [number, number] = [Math.max(1, width / 4), Math.max(1, length / 4)];
  const material = new THREE.MeshStandardMaterial({
    color: 0xd2dbe6,
    map: envTexture("asphalt.webp", true, tile),
    normalMap: envTexture("asphalt_n.webp", false, tile),
    normalScale: new THREE.Vector2(0.9, 0.9),
    roughness: 1,
    metalness: 0.05,
    roughnessMap: createWetRoughnessTexture(width, length),
  });
  const mesh = new THREE.Mesh(geometry, material);
  mesh.name = "Asphalt";
  mesh.receiveShadow = true;
  return mesh;
}

/** Deterministic PRNG so the puddle layout is stable between runs. */
function rng(seed: number): () => number {
  let a = seed;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ---------------------------------------------------------------------------
// Generated environment art (see scripts/fetch-environment.ts)
// ---------------------------------------------------------------------------

const ENV_BASE = (): string => `${import.meta.env.BASE_URL}assets/env/`;
const envCache = new Map<string, THREE.Texture>();

/**
 * Shared texture from public/assets/env. Missing files fail silently and the material keeps its
 * flat colour, so the alley still renders without the generated art.
 */
function envTexture(file: string, srgb: boolean, repeat?: [number, number], offset?: [number, number]): THREE.Texture {
  const key = `${file}|${repeat?.join(",") ?? ""}|${offset?.join(",") ?? ""}`;
  let tex = envCache.get(key);
  if (!tex) {
    tex = new THREE.TextureLoader().load(`${ENV_BASE()}${file}`, undefined, undefined, () => undefined);
    tex.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
    tex.anisotropy = 8;
    tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
    if (repeat) tex.repeat.set(...repeat);
    if (offset) tex.offset.set(...offset);
    envCache.set(key, tex);
  }
  return tex;
}

function createWetRoughnessTexture(width: number, length: number): THREE.CanvasTexture {
  const ppm = 48; // pixels per metre
  const w = Math.round(width * ppm);
  const h = Math.round(length * ppm);
  const canvas = document.createElement("canvas");
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext("2d")!;
  const v = (r: number) => Math.round(r * 255);
  // Matte asphalt grain.
  const img = ctx.createImageData(w, h);
  const rand = rng(7);
  const base = v(ASPHALT_ROUGHNESS);
  for (let i = 0; i < img.data.length; i += 4) {
    const n = base + (rand() - 0.5) * 50;
    img.data[i] = img.data[i + 1] = img.data[i + 2] = n;
    img.data[i + 3] = 255;
  }
  ctx.putImageData(img, 0, 0);
  // Glossy puddles: soft-edged blobs at PUDDLE_ROUGHNESS.
  const puddle = v(PUDDLE_ROUGHNESS);
  for (let i = 0; i < 34; i++) {
    const x = rand() * w;
    const y = rand() * h;
    const r = (0.35 + rand() * 1.1) * ppm;
    const g = ctx.createRadialGradient(x, y, r * 0.35, x, y, r);
    g.addColorStop(0, `rgb(${puddle},${puddle},${puddle})`);
    g.addColorStop(1, `rgba(${puddle},${puddle},${puddle},0)`);
    ctx.fillStyle = g;
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(1, 0.55 + rand() * 0.9);
    ctx.translate(-x, -y);
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.NoColorSpace;
  tex.anisotropy = 4;
  return tex;
}

// ---------------------------------------------------------------------------
// Alley pieces
// ---------------------------------------------------------------------------

const mat = (color: number, roughness = 0.8, metalness = 0, extra: THREE.MeshStandardMaterialParameters = {}) =>
  new THREE.MeshStandardMaterial({ color, roughness, metalness, ...extra });

function box(
  w: number,
  h: number,
  d: number,
  material: THREE.Material,
  x: number,
  y: number,
  z: number
): THREE.Mesh {
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material);
  m.position.set(x, y, z);
  return m;
}

/** Painted facade panel: albedo, relief normal map and an emissive map holding only the lit windows. */
function facadeMaterial(name: string): THREE.MeshStandardMaterial {
  // The generated art includes a strip of sky above and street below the building: crop both.
  const repeat: [number, number] = [1, 0.79];
  const offset: [number, number] = [0, 0.07];
  return new THREE.MeshStandardMaterial({
    color: 0xffffff,
    map: envTexture(`${name}.webp`, true, repeat, offset),
    normalMap: envTexture(`${name}_n.webp`, false, repeat, offset),
    normalScale: new THREE.Vector2(0.8, 0.8),
    emissive: 0xffffff,
    emissiveMap: envTexture(`${name}_e.webp`, true, repeat, offset),
    emissiveIntensity: 1.7,
    roughness: 0.92,
    metalness: 0,
  });
}

/** Tenement walls (12m) on both sides and the dead end, clad in generated facade paintings. */
function createTenementWalls(): THREE.Group {
  const g = new THREE.Group();
  g.name = "TenementWalls";
  const backing = mat(0x1d2128, 0.95);
  const wallX = HALF_W + WALL_THICK / 2;
  g.add(box(WALL_THICK, ALLEY_WALL_HEIGHT, ALLEY_LENGTH, backing, -wallX, ALLEY_WALL_HEIGHT / 2, 0));
  g.add(box(WALL_THICK, ALLEY_WALL_HEIGHT, ALLEY_LENGTH, backing, wallX, ALLEY_WALL_HEIGHT / 2, 0));
  g.add(box(ALLEY_WIDTH + WALL_THICK * 2, ALLEY_WALL_HEIGHT, WALL_THICK, backing, 0, ALLEY_WALL_HEIGHT / 2, -HALF_L - WALL_THICK / 2));

  // Three panels per side, each a different building; the painted aspect (0.58 : 1 crop) fits 9.3m x 12m.
  const panels = 3;
  const panelW = ALLEY_LENGTH / panels;
  const sides: Array<{ x: number; rot: number; names: string[] }> = [
    { x: -(HALF_W - 0.03), rot: Math.PI / 2, names: ["facade_a", "facade_c", "facade_b"] },
    { x: HALF_W - 0.03, rot: -Math.PI / 2, names: ["facade_d", "facade_b", "facade_c"] },
  ];
  for (const side of sides) {
    side.names.forEach((name, i) => {
      const panel = new THREE.Mesh(new THREE.PlaneGeometry(panelW, ALLEY_WALL_HEIGHT), facadeMaterial(name));
      panel.name = `Facade_${name}`;
      panel.position.set(side.x, ALLEY_WALL_HEIGHT / 2, -HALF_L + panelW * (i + 0.5));
      panel.rotation.y = side.rot;
      g.add(panel);
    });
  }
  const end = new THREE.Mesh(new THREE.PlaneGeometry(ALLEY_WIDTH, ALLEY_WALL_HEIGHT), facadeMaterial("facade_a"));
  end.position.set(0, ALLEY_WALL_HEIGHT / 2, -HALF_L - 0.02);
  g.add(end);
  return g;
}

/**
 * Wall fixtures that sell the tenement density: iron window grilles (rehas), rusted air-conditioning
 * compressors and PVC drainage pipes. Placed clear of the fire escape (left wall, z -8.6..0.4), the
 * neon sign and lamp B (right wall) so nothing intersects.
 */
function createWallFixtures(): THREE.Group {
  const g = new THREE.Group();
  g.name = "WallFixtures";
  const iron = mat(0x1a1c20, 0.55, 0.75);
  const rust = mat(0x6b4a38, 0.85, 0.45);
  const rustDark = mat(0x3d2a20, 0.9, 0.4);
  const pvc = mat(0xb9b4a4, 0.55, 0);

  /** Window grille: frame, vertical bars and two cross rails, bolted proud of the wall. */
  const reja = (side: -1 | 1, z: number, y: number, w = 1.3, h = 1.5): void => {
    const x = side * (HALF_W - 0.1);
    g.add(box(0.06, 0.07, w, iron, x, y + h / 2, z), box(0.06, 0.07, w, iron, x, y - h / 2, z));
    g.add(box(0.06, h, 0.07, iron, x, y, z - w / 2), box(0.06, h, 0.07, iron, x, y, z + w / 2));
    for (let dz = -w / 2 + 0.16; dz < w / 2; dz += 0.16) g.add(box(0.04, h, 0.03, iron, x, y, z + dz));
    for (const dy of [-h / 6, h / 6]) g.add(box(0.04, 0.04, w, iron, x, y + dy, z));
  };

  /** Rusted AC compressor: housing, fan grille disc and a bracket arm back to the wall. */
  const compressor = (side: -1 | 1, z: number, y: number): void => {
    const x = side * (HALF_W - 0.28);
    g.add(box(0.5, 0.55, 0.85, rust, x, y, z));
    const fan = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.2, 0.03, 16), rustDark);
    fan.rotation.z = Math.PI / 2;
    fan.position.set(x - side * 0.26, y, z);
    g.add(fan);
    for (const dz of [-0.3, 0.3]) g.add(box(0.5, 0.05, 0.05, iron, x, y - 0.34, z + dz));
    g.add(box(0.05, 0.05, 0.5, iron, x + side * 0.02, y - 0.3, z)); // drip tray stub
  };

  /** PVC drainage pipe: a vertical run with clamp rings and a kicked-out elbow at the bottom. */
  const pipe = (side: -1 | 1, z: number, top: number): void => {
    const x = side * (HALF_W - 0.09);
    const run = new THREE.Mesh(new THREE.CylinderGeometry(0.055, 0.055, top - 0.35, 10), pvc);
    run.position.set(x, 0.35 + (top - 0.35) / 2, z);
    g.add(run);
    for (let y = 1.2; y < top; y += 2.3) {
      const clamp = new THREE.Mesh(new THREE.CylinderGeometry(0.075, 0.075, 0.07, 10), iron);
      clamp.position.set(x, y, z);
      g.add(clamp);
    }
    const elbow = new THREE.Mesh(new THREE.CylinderGeometry(0.055, 0.055, 0.42, 10), pvc);
    elbow.rotation.z = Math.PI / 2;
    elbow.position.set(x - side * 0.2, 0.3, z);
    g.add(elbow);
  };

  // Left wall (the fire escape owns z -8.6..0.4 up to y 10).
  reja(-1, 6.2, 2.2);
  reja(-1, 3.4, 5.4, 1.2, 1.4);
  reja(-1, -11.8, 2.2);
  compressor(-1, 5.2, 4.6);
  compressor(-1, 9.6, 6.8);
  pipe(-1, 7.0, 10.8);
  pipe(-1, -10.2, 9.5);
  // Right wall (neon sign z -6..-3, lamp B z -1).
  reja(1, 1.6, 2.2, 1.2);
  reja(1, -9.6, 5.6, 1.3, 1.5);
  reja(1, 8.0, 5.0);
  compressor(1, 7.0, 7.4);
  compressor(1, -1.8, 8.2);
  compressor(1, -12.0, 4.4);
  pipe(1, 6.1, 11);
  pipe(1, -6.9, 10);
  return g;
}

/** Modular fire escape bolted to the left wall: grated platforms, railings and steep stair flights. */
function createFireEscape(): THREE.Group {
  const g = new THREE.Group();
  g.name = "FireEscape";
  const iron = mat(0x1b1d21, 0.6, 0.75);
  const rust = mat(0x4a2e1f, 0.8, 0.5);
  const x0 = -HALF_W; // wall face
  const depth = 1.4;

  const platform = (zMin: number, zMax: number, y: number): void => {
    const len = zMax - zMin;
    const zc = (zMin + zMax) / 2;
    g.add(box(depth, 0.08, len, iron, x0 + depth / 2, y, zc)); // grating
    g.add(box(0.05, 1.0, len, iron, x0 + depth, y + 0.5, zc)); // outer rail
    for (const z of [zMin, zMax]) g.add(box(depth, 1.0, 0.05, iron, x0 + depth / 2, y + 0.5, z)); // end rails
    g.add(box(0.07, 0.07, len, rust, x0 + depth, y + 1.0, zc)); // top rail
    // Diagonal brace down to the wall.
    for (const z of [zMin + 0.2, zMax - 0.2]) {
      const brace = box(0.05, 1.5, 0.05, iron, x0 + depth * 0.5, y - 0.6, z);
      brace.rotation.z = 0.75;
      g.add(brace);
    }
  };

  /** Steep flight rising from (zFrom, yFrom) to (zTo, yTo) at the wall. */
  const flight = (zFrom: number, zTo: number, yFrom: number, yTo: number): void => {
    const steps = 10;
    for (let i = 0; i <= steps; i++) {
      const k = i / steps;
      g.add(box(0.8, 0.05, 0.28, iron, x0 + 0.55, THREE.MathUtils.lerp(yFrom, yTo, k), THREE.MathUtils.lerp(zFrom, zTo, k)));
    }
    const len = Math.hypot(zTo - zFrom, yTo - yFrom);
    for (const dx of [0.2, 0.9]) {
      const stringer = box(0.05, 0.1, len, iron, x0 + dx, (yFrom + yTo) / 2 + 0.4, (zFrom + zTo) / 2);
      stringer.rotation.x = -Math.atan2(yTo - yFrom, zTo - zFrom); // tilt along the flight
      g.add(stringer);
    }
  };

  platform(-8.6, -5.6, 3);
  flight(-5.6, -3.8, 3, 6);
  platform(-3.8, -0.8, 6); // the drop platform (FIRE_ESCAPE_DROP)
  flight(-0.8, -2.6, 6, 9);
  platform(-2.6, 0.4, 9);
  // Hanging drop ladder at the lowest platform.
  for (let y = 0.4; y < 3; y += 0.35) g.add(box(0.5, 0.04, 0.04, iron, x0 + 0.7, y, -8.4));
  return g;
}

function createCorrugatedGeometry(w: number, d: number, waves: number, amp: number): THREE.BufferGeometry {
  const geo = new THREE.PlaneGeometry(w, d, waves * 8, 1);
  const pos = geo.attributes.position as THREE.BufferAttribute;
  for (let i = 0; i < pos.count; i++) {
    pos.setZ(i, Math.sin((pos.getX(i) / w) * waves * Math.PI * 2) * amp);
  }
  geo.computeVertexNormals();
  return geo;
}

/** Corrugated metal overhangs jutting from the walls above doorways, sloped away from the wall. */
function createOverhangs(): THREE.Group {
  const g = new THREE.Group();
  g.name = "Overhangs";
  const tin = mat(0x8f8a88, 0.6, 0.4, {
    side: THREE.DoubleSide,
    map: envTexture("metal.webp", true, [2, 1]),
    normalMap: envTexture("metal_n.webp", false, [2, 1]),
  });
  const trim = mat(0x40454b, 0.55, 0.7);
  const add = (side: -1 | 1, z: number, y: number, len: number, reach: number): void => {
    const geo = createCorrugatedGeometry(reach, len, Math.round(reach / 0.18), 0.04);
    geo.rotateX(-Math.PI / 2); // flat, ridges along Z
    const sheet = new THREE.Mesh(geo, tin);
    // Wall-attached edge high, outer edge lower.
    sheet.position.set(side * (HALF_W - reach / 2), y, z);
    sheet.rotation.z = side * 0.16;
    g.add(sheet);
    g.add(box(0.06, 0.1, len, trim, side * (HALF_W - reach), y - 0.28, z));
    g.add(box(0.05, 0.05, 0.05, trim, side * (HALF_W - 0.02), y, z)); // bracket stub
    for (const dz of [-len / 2 + 0.1, len / 2 - 0.1]) {
      const strut = box(0.05, 0.9, 0.05, trim, side * (HALF_W - reach * 0.5), y - 0.4, z + dz);
      strut.rotation.z = side * -0.9;
      g.add(strut);
    }
  };
  add(1, 4, 2.9, 3.2, 1.6);
  add(1, -8.5, 2.9, 2.8, 1.5);
  add(-1, 9, 2.9, 3.6, 1.7);
  add(-1, -13, 3.1, 2.4, 1.2);
  add(1, 11, 2.9, 2.6, 1.4);
  return g;
}

function wire(a: THREE.Vector3, b: THREE.Vector3, sag: number, material: THREE.Material): THREE.Mesh {
  const mid = a.clone().lerp(b, 0.5);
  mid.y -= sag;
  const curve = new THREE.QuadraticBezierCurve3(a, mid, b);
  const m = new THREE.Mesh(new THREE.TubeGeometry(curve, 20, 0.018, 4), material);
  m.userData.noShadow = true;
  return m;
}

/** Overhead cross-street wire bundles: strands strung wall to wall with insulator clamps. */
function createWireBundles(): THREE.Group {
  const g = new THREE.Group();
  g.name = "WireBundles";
  const cable = mat(0x050506, 0.6);
  const clamp = mat(0x2a2218, 0.8);
  const rand = rng(99);
  for (const z of [11, 5.5, 0, -5.5, -10.5]) {
    const y = 8.4 + rand() * 1.6;
    for (let i = 0; i < 5; i++) {
      const dz = (i - 2) * 0.14 + (rand() - 0.5) * 0.08;
      const dy = (rand() - 0.5) * 0.4;
      g.add(
        wire(
          new THREE.Vector3(-HALF_W, y + dy, z + dz),
          new THREE.Vector3(HALF_W, y + dy + (rand() - 0.5) * 0.3, z + dz),
          0.45 + rand() * 0.4,
          cable
        )
      );
    }
    // Clamp blocks where the bundle meets each wall.
    for (const side of [-1, 1]) g.add(box(0.14, 0.3, 0.8, clamp, side * (HALF_W - 0.1), y, z));
  }
  // A drooping service line along the alley.
  g.add(wire(new THREE.Vector3(HALF_W - 0.2, 7.2, 12), new THREE.Vector3(HALF_W - 0.2, 7.6, -12), 0.9, cable));
  return g;
}

/** Flickering neon sign bolted to the right wall; its point light is added in Lighting. */
function createNeonSign(): THREE.Group {
  const g = new THREE.Group();
  g.name = "NeonSign";
  const x = HALF_W - 0.12;
  const z = QUIAPO_NEON_LIGHT.z;
  const y = QUIAPO_NEON_LIGHT.y;
  g.add(box(0.1, 1.9, 3.0, mat(0x0c0f14, 0.6, 0.4), x, y, z)); // backing board
  const neon = new THREE.MeshStandardMaterial({ color: 0xff5a4a, emissive: 0xff2d3a, emissiveIntensity: 2.2 });
  const parts = [
    box(0.06, 0.07, 2.6, neon, x - 0.08, y + 0.75, z),
    box(0.06, 0.07, 2.6, neon, x - 0.08, y - 0.75, z),
    box(0.06, 1.5, 0.07, neon, x - 0.08, y, z - 1.3),
    box(0.06, 1.5, 0.07, neon, x - 0.08, y, z + 1.3),
    box(0.06, 0.07, 1.4, neon, x - 0.08, y, z), // "bar" stroke
  ];
  parts.forEach((p) => {
    p.userData.noShadow = true;
    p.userData.neonTube = true;
    g.add(p);
  });
  return g;
}

/** Sari-sari store at the dead end: back + side walls, counter, shelves, tin roof, amber bulb. */
function createStall(cx: number, cz: number): THREE.Group {
  const g = new THREE.Group();
  g.name = "SariSariStore";
  const wallMat = mat(0x5e5040, 0.9);
  const wood = mat(0x5a3a20, 0.85);
  const darkWood = mat(0x35220f, 0.9);

  // Back + side walls (open toward +X, the alley centre).
  g.add(box(0.25, 2.8, 4.4, wallMat, cx - 1.3, 1.4, cz));
  g.add(box(2.7, 2.8, 0.2, wallMat, cx, 1.4, cz - 2.1));
  g.add(box(2.7, 2.8, 0.2, wallMat, cx, 1.4, cz + 2.1));

  g.add(box(0.7, 1.0, 3.6, wood, cx + 1.2, 0.5, cz));
  g.add(box(0.95, 0.07, 3.8, darkWood, cx + 1.2, 1.03, cz));
  for (const dz of [-1.95, 1.95]) g.add(box(0.14, 2.8, 0.14, darkWood, cx + 2.1, 1.4, cz + dz));

  for (const y of [0.9, 1.5, 2.1]) g.add(box(0.4, 0.05, 3.6, wood, cx - 1.05, y, cz));
  const goodsColors = [0xd94a3a, 0xf0c040, 0x3a8fd9, 0x56b870, 0xe07ab0, 0xf08a30];
  let n = 0;
  for (const y of [0.9, 1.5, 2.1]) {
    for (let z = -1.6; z <= 1.6; z += 0.4) {
      const h = 0.18 + ((n * 7) % 5) * 0.03;
      const item = box(0.22, h, 0.26, mat(goodsColors[n % goodsColors.length], 0.6), cx - 1.05, y + 0.025 + h / 2, cz + z);
      item.userData.noShadow = true;
      g.add(item);
      n++;
    }
  }

  const roofGeo = createCorrugatedGeometry(3.6, 4.8, 9, 0.05);
  roofGeo.rotateX(-Math.PI / 2);
  const roof = new THREE.Mesh(
    roofGeo,
    mat(0x8f8a88, 0.6, 0.4, { side: THREE.DoubleSide, map: envTexture("metal.webp", true, [2, 1]), normalMap: envTexture("metal_n.webp", false, [2, 1]) })
  );
  roof.position.set(cx + 0.7, 2.95, cz);
  roof.rotation.z = -0.1;
  g.add(roof);
  g.add(box(0.06, 0.1, 4.8, mat(0x5a5f66, 0.5, 0.7), cx + 2.5, 2.78, cz));

  // Hanging bulb: the amber lantern light sits at QUIAPO_STALL_LIGHT.
  const bulb = new THREE.Mesh(
    new THREE.SphereGeometry(0.1, 12, 12),
    new THREE.MeshStandardMaterial({ color: 0xffb870, emissive: 0xff8822, emissiveIntensity: 3 })
  );
  bulb.position.copy(QUIAPO_STALL_LIGHT);
  bulb.userData.noShadow = true;
  g.add(bulb);

  g.add(box(0.05, 0.45, 2.2, mat(0xb82e2e, 0.6), cx + 2.15, 2.5, cz));
  return g;
}

/**
 * Two street lamps on the right wall. Lamp A (z=7) is a free-standing pole
 * tagged `replaceable` for street_lamp.glb; lamp B is wall-mounted. Bulbs are
 * tagged `streetBulb` so the blackout can kill their glow.
 */
function createStreetLamps(): THREE.Group {
  const g = new THREE.Group();
  g.name = "StreetLamps";
  const metal = mat(0x2c3036, 0.5, 0.7);
  const bulbMat = () => new THREE.MeshStandardMaterial({ color: 0xffe2b0, emissive: 0xffa64d, emissiveIntensity: 3 });

  const px = 3.3;
  const pz = 7;
  const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.11, 5.2, 10), metal);
  pole.position.set(px, 2.6, pz);
  pole.userData.replaceable = true;
  const base = box(0.5, 0.5, 0.5, metal, px, 0.25, pz);
  base.userData.replaceable = true;
  const arm = new THREE.Mesh(
    new THREE.TubeGeometry(
      new THREE.QuadraticBezierCurve3(
        new THREE.Vector3(px, 4.7, pz),
        new THREE.Vector3(px - 0.3, 5.4, pz),
        new THREE.Vector3(px - 1.8, 4.9, pz)
      ),
      16,
      0.045,
      6
    ),
    metal
  );
  arm.userData.replaceable = true;
  const head = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.3, 0.2, 12), metal);
  head.position.set(px - 1.8, 4.85, pz);
  head.userData.replaceable = true;
  const lamp = new THREE.Mesh(new THREE.SphereGeometry(0.15, 12, 8, 0, Math.PI * 2, Math.PI / 2, Math.PI / 2), bulbMat());
  lamp.position.set(px - 1.8, 4.75, pz);
  lamp.userData.noShadow = true;
  lamp.userData.replaceable = true;
  lamp.userData.streetBulb = true;
  g.add(pole, base, arm, head, lamp);

  // Wall-mounted lamp B.
  const bx = HALF_W - 0.05;
  const bz = -1;
  g.add(box(0.1, 0.1, 0.1, metal, bx, 5.6, bz));
  const arm2 = box(1.7, 0.07, 0.07, metal, bx - 0.8, 5.65, bz);
  g.add(arm2);
  const lamp2 = new THREE.Mesh(new THREE.SphereGeometry(0.15, 12, 8, 0, Math.PI * 2, Math.PI / 2, Math.PI / 2), bulbMat());
  lamp2.position.set(bx - 1.7, 5.55, bz);
  lamp2.userData.noShadow = true;
  lamp2.userData.streetBulb = true;
  g.add(lamp2);
  return g;
}

/** Shallow wet-look puddle decals with roughness 0.04; the ground roughness map carries the rest. */
function createPuddles(): THREE.Group {
  const g = new THREE.Group();
  g.name = "Puddles";
  const spots: Array<[number, number, number, number]> = [
    // x, z, radius, stretch
    [-0.8, -3.2, 1.2, 1.5],
    [1.4, 1.8, 0.9, 1.3],
    [-1.6, 5.4, 1.0, 1.7],
    [1.0, -7.5, 1.3, 1.2],
    [0.3, 9.0, 0.8, 1.0],
    [-2.4, 1.0, 0.6, 1.3],
  ];
  const puddleMat = new THREE.MeshStandardMaterial({
    color: 0x1c2733,
    roughness: PUDDLE_ROUGHNESS,
    metalness: 0.35,
    transparent: true,
    opacity: 0.55,
    polygonOffset: true,
    polygonOffsetFactor: -2,
  });
  for (const [x, z, r, stretch] of spots) {
    const geo = new THREE.CircleGeometry(r, 32);
    geo.rotateX(-Math.PI / 2);
    const p = new THREE.Mesh(geo, puddleMat);
    p.position.set(x, 0.012, z);
    p.scale.z = stretch;
    p.rotation.y = x * 1.7;
    p.userData.noShadow = true;
    g.add(p);
  }
  return g;
}

/** Crates, a dumpster and barrels to dress the dark corners. */
function createClutter(): THREE.Group {
  const g = new THREE.Group();
  g.name = "Clutter";
  g.userData.replaceable = true;
  const crate = mat(0x4b3a26, 0.9);
  const dumpster = mat(0x1f3a2a, 0.7, 0.4);
  g.add(box(1.2, 0.9, 0.9, crate, 2.9, 0.45, -9.5));
  g.add(box(0.9, 0.7, 0.9, crate, 3.1, 1.25, -9.4));
  g.add(box(1.0, 0.6, 1.0, crate, -3.0, 0.3, 4.4));
  g.add(box(1.7, 1.2, 1.0, dumpster, 3.0, 0.6, 9.2));
  const barrelMat = mat(0x3a2f24, 0.7, 0.5);
  for (const [x, z] of [[-3.3, -13], [3.4, -12.6], [3.2, 2.0]] as const) {
    const b = new THREE.Mesh(new THREE.CylinderGeometry(0.32, 0.32, 0.9, 12), barrelMat);
    b.position.set(x, 0.45, z);
    g.add(b);
  }
  return g;
}

/** Closed double gate across the alley mouth. Leaves are pivot groups hinged at the walls. */
function createGate(): { group: THREE.Group; leaves: AlleyGate } {
  const group = new THREE.Group();
  group.name = "Gate";
  const iron = mat(0x23262b, 0.55, 0.7);
  const wallMat = mat(0x2a272c, 0.95);
  const sideW = (ALLEY_WIDTH - GATE_OPENING) / 2;
  const sideX = GATE_OPENING / 2 + sideW / 2;
  group.add(box(sideW, GATE_WALL_HEIGHT, 0.4, wallMat, -sideX, GATE_WALL_HEIGHT / 2, GATE_Z));
  group.add(box(sideW, GATE_WALL_HEIGHT, 0.4, wallMat, sideX, GATE_WALL_HEIGHT / 2, GATE_Z));
  group.add(box(GATE_OPENING + 0.4, 0.5, 0.4, wallMat, 0, GATE_WALL_HEIGHT - 0.25, GATE_Z)); // lintel
  const makeLeaf = (hingeX: number, dir: 1 | -1): THREE.Group => {
    const pivot = new THREE.Group();
    pivot.position.set(hingeX, 0, GATE_Z);
    const w = GATE_OPENING / 2;
    const h = GATE_WALL_HEIGHT - 0.5;
    pivot.add(box(w, 0.1, 0.08, iron, dir * w / 2, 0.1, 0));
    pivot.add(box(w, 0.1, 0.08, iron, dir * w / 2, h - 0.05, 0));
    for (let x = 0.08; x < w; x += 0.2) pivot.add(box(0.05, h, 0.06, iron, dir * x, h / 2, 0));
    pivot.add(box(w, 0.08, 0.06, iron, dir * w / 2, h / 2, 0.02)); // cross brace
    return pivot;
  };
  const left = makeLeaf(-GATE_OPENING / 2, 1);
  const right = makeLeaf(GATE_OPENING / 2, -1);
  group.add(left, right);
  return { group, leaves: { left, right } };
}

// ---------------------------------------------------------------------------
// Delivery van
// ---------------------------------------------------------------------------

export interface DeliveryVan {
  root: THREE.Group;
  headlights: THREE.SpotLight[];
}

/** Dante's delivery van, facing -Z, with two headlight spot lights. Parked off-stage by the caller. */
export function createDeliveryVan(): DeliveryVan {
  const root = new THREE.Group();
  root.name = "DeliveryVan";
  const dark = mat(0x0d0f12, 0.4, 0.2);
  if (vanSource) {
    // Generated model: front is +Z at rest, so turn it to face -Z. It comes normalised to a unit cube;
    // stretch to a real panel van (2.1m wide, 2.4m tall, 5m long) standing on the ground.
    const model = vanSource.clone(true);
    model.rotation.y = Math.PI;
    model.scale.set(4.1, 3.7, 5.0);
    model.updateMatrixWorld(true);
    model.position.y = -new THREE.Box3().setFromObject(model).min.y;
    model.name = "DeliveryVanModel";
    root.add(model);
  } else {
    const body = mat(0x9a2a22, 0.5, 0.35);
    const chrome = mat(0x9aa0a8, 0.3, 0.9);
    root.add(box(2.0, 1.7, 3.6, body, 0, 1.1, 0.6)); // cargo box
    root.add(box(2.0, 1.2, 1.4, body, 0, 0.85, -1.9)); // hood/cab
    root.add(box(1.8, 0.7, 1.0, dark, 0, 1.55, -1.6)); // windscreen
    root.add(box(2.05, 0.18, 4.8, mat(0xe9e2d0, 0.6), 0, 0.62, -0.3)); // stripe
    root.add(box(2.1, 0.2, 0.2, chrome, 0, 0.45, -2.65)); // bumper
    const wheelGeo = new THREE.CylinderGeometry(0.38, 0.38, 0.28, 16);
    wheelGeo.rotateZ(Math.PI / 2);
    for (const [x, z] of [[-1.0, -1.5], [1.0, -1.5], [-1.0, 1.7], [1.0, 1.7]] as const) {
      const w = new THREE.Mesh(wheelGeo, dark);
      w.position.set(x, 0.38, z);
      root.add(w);
    }
  }
  const lampMat = new THREE.MeshStandardMaterial({ color: 0xfff3d0, emissive: 0xfff0c0, emissiveIntensity: 4 });
  const headlights: THREE.SpotLight[] = [];
  for (const x of [-0.7, 0.7]) {
    if (!vanSource) {
      // The generated model carries its own headlamps; the procedural van needs glowing lenses.
      const lens = new THREE.Mesh(new THREE.SphereGeometry(0.16, 12, 8), lampMat);
      lens.position.set(x, 0.85, -2.62);
      lens.userData.noShadow = true;
      root.add(lens);
    }
    const spot = new THREE.SpotLight(0xfff0cc, 60, 34, 0.5, 0.55, 1);
    spot.position.set(x, 0.85, -2.5);
    spot.target.position.set(x, 0.3, -12);
    spot.castShadow = false;
    root.add(spot, spot.target);
    headlights.push(spot);
  }
  root.traverse((o) => {
    if (o instanceof THREE.Mesh) o.castShadow = true;
  });
  return { root, headlights };
}
