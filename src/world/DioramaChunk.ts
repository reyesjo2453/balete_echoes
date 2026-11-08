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
