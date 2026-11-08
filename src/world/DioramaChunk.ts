import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";

/** Full-size modular street chunk edge length in metres. */
export const CHUNK_SIZE = 40;

export interface PropPlacement {
  url: string;
  position: [number, number, number];
  rotationY?: number;
  scale?: number;
}

/** Light anchor points shared with Lighting.addQuiapoLights(). */
export const QUIAPO_STALL_LIGHT = new THREE.Vector3(-7.4, 2.3, -2);
export const QUIAPO_NEON_LIGHT = new THREE.Vector3(0, 2.8, -9.2);

/**
 * A modular 40x40m street diorama: ground slab plus GLB props loaded from
 * /assets/models. `createTestPlane` mounts the 20x20m baseline asphalt pad.
 */
export class DioramaChunk {
  readonly root = new THREE.Group();
  private static loader = new GLTFLoader();
  private static cache = new Map<string, Promise<THREE.Group>>();

  constructor(readonly origin = new THREE.Vector3(), size = CHUNK_SIZE) {
    this.root.name = "DioramaChunk";
    this.root.position.copy(origin);
    this.root.add(createAsphalt(size));
  }

  /** Baseline test pad: 20m x 20m dark gray asphalt. */
  static createTestPlane(): DioramaChunk {
    return new DioramaChunk(new THREE.Vector3(), 20);
  }

  /**
   * 20x20m Quiapo block: sari-sari store (left, -X), overhead wires and a
   * street lamp (right, +X), wet puddles on the centre road, neon back wall.
   */
  static createQuiapoBlock(): DioramaChunk {
    const chunk = new DioramaChunk(new THREE.Vector3(), 20);
    chunk.root.add(
      createRoadDetails(),
      createSariSariStore(),
      createStreetLampAndWires(),
      createPuddles(),
      createBackWall()
    );
    chunk.root.traverse((o) => {
      if (o instanceof THREE.Mesh && o.name !== "Asphalt") o.castShadow = o.userData.noShadow ? false : true;
      if (o instanceof THREE.Mesh) o.receiveShadow = true;
    });
    return chunk;
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
        position: [-8.4, 0, -2],
        rotationY: Math.PI / 2, // open front toward the street (+X)
        fit: { dimension: "footprint", size: 4.4 },
        replace: (o) => o.name === "SariSariStore",
      }),
      this.swapModel(`${base}street_lamp.glb`, {
        position: [8, 0, 4],
        fit: { dimension: "height", size: 5.4 },
        replace: (o) => o.userData.replaceable === true,
      }),
    ]);
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

function createAsphalt(size: number): THREE.Mesh {
  const geometry = new THREE.PlaneGeometry(size, size);
  geometry.rotateX(-Math.PI / 2);
  const roughnessMap = createRoughnessTexture(size);
  const material = new THREE.MeshStandardMaterial({
    color: 0x2b2d31,
    roughness: 0.92,
    metalness: 0.0,
    roughnessMap,
  });
  const mesh = new THREE.Mesh(geometry, material);
  mesh.name = "Asphalt";
  mesh.receiveShadow = true;
  return mesh;
}

/** Procedural grain so the moonlight breaks up across the asphalt. */
function createRoughnessTexture(size: number): THREE.CanvasTexture {
  const res = 256;
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = res;
  const ctx = canvas.getContext("2d")!;
  const img = ctx.createImageData(res, res);
  for (let i = 0; i < img.data.length; i += 4) {
    const v = 190 + Math.random() * 65; // mostly rough, a few slick puddle specks
    img.data[i] = img.data[i + 1] = img.data[i + 2] = v;
    img.data[i + 3] = 255;
  }
  ctx.putImageData(img, 0, 0);
  const tex = new THREE.CanvasTexture(canvas);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(size / 4, size / 4);
  return tex;
}

// ---------------------------------------------------------------------------
// Quiapo block pieces
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

/** Sidewalk curbs and dashed centre-line marking. */
function createRoadDetails(): THREE.Group {
  const g = new THREE.Group();
  g.name = "RoadDetails";
  const walk = mat(0x4a4a50, 0.95);
  g.add(box(4.2, 0.12, 20, walk, -7.9, 0.06, 0)); // left sidewalk (x -10 .. -5.8)
  g.add(box(2.6, 0.12, 20, walk, 8.7, 0.06, 0)); // right sidewalk (x 7.4 .. 10)
  const paint = mat(0xc9b458, 0.7);
  for (let z = -9; z <= 9; z += 2.6) {
    const dash = box(0.18, 0.01, 1.2, paint, 0.6, 0.012, z);
    dash.userData.noShadow = true;
    g.add(dash);
  }
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

/** Left-side store: back + side walls, wooden counter, shelves, tin roof overhang. */
function createSariSariStore(): THREE.Group {
  const g = new THREE.Group();
  g.name = "SariSariStore";
  const cx = -8.4;
  const cz = -2;
  const wallMat = mat(0x7a6a52, 0.9);
  const wood = mat(0x6b4426, 0.85);
  const darkWood = mat(0x3f2814, 0.9);

  // Back + side walls (open toward +X).
  g.add(box(0.25, 2.8, 4.4, wallMat, cx - 1.3, 1.4, cz));
  g.add(box(2.7, 2.8, 0.2, wallMat, cx, 1.4, cz - 2.1));
  g.add(box(2.7, 2.8, 0.2, wallMat, cx, 1.4, cz + 2.1));

  // Wooden counter with a plank top, plus posts that carry the roof.
  g.add(box(0.7, 1.0, 3.6, wood, cx + 1.2, 0.5, cz));
  g.add(box(0.95, 0.07, 3.8, darkWood, cx + 1.2, 1.03, cz));
  for (const dz of [-1.95, 1.95]) g.add(box(0.14, 2.8, 0.14, darkWood, cx + 2.1, 1.4, cz + dz));

  // Shelves with colourful goods.
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

  // Corrugated tin roof, tilted down toward the street, overhanging past the counter.
  const roofGeo = createCorrugatedGeometry(3.6, 4.8, 9, 0.05);
  roofGeo.rotateX(-Math.PI / 2); // lay flat; ridges run along Z
  const roof = new THREE.Mesh(roofGeo, mat(0x8d949c, 0.45, 0.75, { side: THREE.DoubleSide }));
  roof.position.set(cx + 0.7, 2.95, cz);
  roof.rotation.z = -0.1; // slope toward +X (street)
  g.add(roof);
  // Roof edge trim.
  g.add(box(0.06, 0.1, 4.8, mat(0x5a5f66, 0.5, 0.7), cx + 2.5, 2.78, cz));

  // Hanging bulb (visual; the amber light sits at QUIAPO_STALL_LIGHT).
  const bulb = new THREE.Mesh(
    new THREE.SphereGeometry(0.09, 12, 12),
    new THREE.MeshStandardMaterial({ color: 0xffd28a, emissive: 0xffa64d, emissiveIntensity: 3 })
  );
  bulb.position.copy(QUIAPO_STALL_LIGHT).sub(new THREE.Vector3(g.position.x, 0, 0));
  bulb.userData.noShadow = true;
  g.add(bulb);

  // Signboard.
  const sign = box(0.05, 0.45, 2.2, mat(0xb82e2e, 0.6), cx + 2.15, 2.5, cz);
  g.add(sign);
  return g;
}

function wire(points: THREE.Vector3[], sag: number): THREE.Mesh {
  const mid = points[0].clone().lerp(points[1], 0.5);
  mid.y -= sag;
  const curve = new THREE.QuadraticBezierCurve3(points[0], mid, points[1]);
  const m = new THREE.Mesh(new THREE.TubeGeometry(curve, 24, 0.012, 4), mat(0x0a0a0c, 0.6));
  m.userData.noShadow = true;
  return m;
}

/** Right-side pole with crossarm, curved lamp arm + head, and sagging overhead wires. */
function createStreetLampAndWires(): THREE.Group {
  const g = new THREE.Group();
  g.name = "StreetLamp";
  const metal = mat(0x2c3036, 0.5, 0.7);
  const px = 8;
  const pz = 4;

  // Parts tagged `replaceable` are swapped out when street_lamp.glb loads.
  const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.11, 5.2, 10), metal);
  pole.position.set(px, 2.6, pz);
  pole.userData.replaceable = true;
  g.add(pole);
  const lampBase = box(0.5, 0.5, 0.5, metal, px, 0.25, pz);
  lampBase.userData.replaceable = true;
  g.add(lampBase);

  // Curved lamp arm reaching toward the road (-X).
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
  g.add(arm);
  const head = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.3, 0.2, 12), metal);
  head.position.set(px - 1.8, 4.85, pz);
  head.userData.replaceable = true;
  g.add(head);
  const lamp = new THREE.Mesh(
    new THREE.SphereGeometry(0.15, 12, 8, 0, Math.PI * 2, Math.PI / 2, Math.PI / 2),
    new THREE.MeshStandardMaterial({ color: 0xffe2b0, emissive: 0xffa64d, emissiveIntensity: 3 })
  );
  lamp.position.set(px - 1.8, 4.75, pz);
  lamp.userData.noShadow = true;
  lamp.userData.replaceable = true;
  g.add(lamp);

  // Crossarm with insulators for the wires.
  g.add(box(0.1, 0.1, 1.6, mat(0x4a3220, 0.9), px, 4.4, pz));
  const crossEnds = [new THREE.Vector3(px, 4.45, pz - 0.7), new THREE.Vector3(px, 4.45, pz + 0.7)];

  // Overhead armature: wires from the crossarm across the road to the store roof, and along the street.
  const storeEdge = [new THREE.Vector3(-6.0, 3.0, -2.9), new THREE.Vector3(-6.0, 3.0, -1.1)];
  g.add(wire([crossEnds[0], storeEdge[0]], 0.6));
  g.add(wire([crossEnds[1], storeEdge[1]], 0.6));
  // Second pole in the back corner so wires run along the street too.
  const pole2 = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.09, 4.6, 8), metal);
  pole2.position.set(8, 2.3, -8);
  g.add(pole2);
  g.add(wire([new THREE.Vector3(px, 4.45, pz - 0.7), new THREE.Vector3(8, 4.3, -8)], 0.4));
  g.add(wire([new THREE.Vector3(px, 4.2, pz + 0.7), new THREE.Vector3(8, 4.1, -8)], 0.5));
  g.add(wire([new THREE.Vector3(-6.0, 3.0, -2.5), new THREE.Vector3(8, 4.3, -8)], 0.9));
  return g;
}

/** Glossy rain puddles: circular planes, roughness 0.05, faint blue specular. */
function createPuddles(): THREE.Group {
  const g = new THREE.Group();
  g.name = "Puddles";
  const spots: Array<[number, number, number, number]> = [
    // x, z, radius, stretch
    [-0.8, -3.2, 1.3, 1.4],
    [1.6, 1.4, 0.9, 1.1],
    [-1.8, 3.6, 1.1, 1.6],
    [2.4, -5.8, 1.5, 1.2],
    [0.3, 6.4, 0.7, 1.0],
    [-3.2, -0.4, 0.6, 1.3],
  ];
  const puddleMat = new THREE.MeshPhysicalMaterial({
    color: 0x06090f,
    roughness: 0.05,
    metalness: 0.0,
    specularColor: new THREE.Color(0x6f9bff),
    specularIntensity: 1,
    transparent: true,
    opacity: 0.88,
    polygonOffset: true,
    polygonOffsetFactor: -2,
  });
  for (const [x, z, r, stretch] of spots) {
    const geo = new THREE.CircleGeometry(r, 32);
    geo.rotateX(-Math.PI / 2);
    const p = new THREE.Mesh(geo, puddleMat);
    p.position.set(x, 0.015, z);
    p.scale.z = stretch;
    p.rotation.y = x * 1.7;
    p.userData.noShadow = true;
    g.add(p);
  }
  return g;
}

/** Far boundary wall with a glowing magenta neon sign. */
function createBackWall(): THREE.Group {
  const g = new THREE.Group();
  g.name = "BackWall";
  g.add(box(20, 4.5, 0.3, mat(0x23252c, 0.95), 0, 2.25, -10.1));
  const neonMat = new THREE.MeshStandardMaterial({
    color: 0xff4fd8,
    emissive: 0xff2bd0,
    emissiveIntensity: 2.5,
  });
  const frame = [
    box(3.0, 0.06, 0.06, neonMat, 0, 3.4, -9.9),
    box(3.0, 0.06, 0.06, neonMat, 0, 2.6, -9.9),
    box(0.06, 0.8, 0.06, neonMat, -1.5, 3.0, -9.9),
    box(0.06, 0.8, 0.06, neonMat, 1.5, 3.0, -9.9),
  ];
  frame.forEach((m) => {
    m.userData.noShadow = true;
    g.add(m);
  });
  return g;
}
