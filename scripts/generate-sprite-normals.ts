/**
 * Bakes tangent-space normal maps and roughness maps for the 2.5D sprites (GDD section 5.B).
 *
 *   npm run generate-sprite-normals
 *
 * For every diffuse in `public/assets/sprites` (sheets and idle PNGs) this writes, next to it:
 *   <name>_n.<ext>  OpenGL-style tangent-space normals derived from a blurred luminance height field
 *   <name>_r.<ext>  roughness (green channel): bright / wet-looking pixels are glossy, dark cloth is matte
 * Atlases keep the exact pixel layout of the diffuse, so the same per-frame UV transform applies to all three.
 */
import sharp from "sharp";
import { readdirSync } from "node:fs";
import { join, parse } from "node:path";

const DIR = "public/assets/sprites";
const STRENGTH = 2.2;
const BLUR_RADIUS = 2;

async function bake(file: string): Promise<void> {
  const { dir, name, ext } = parse(file);
  const { data, info } = await sharp(file).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const w = info.width;
  const h = info.height;

  // Height = luminance * alpha, box-blurred (separable) so the normals read as soft form, not pixel noise.
  const height = new Float32Array(w * h);
  for (let i = 0; i < w * h; i++) {
    const lum = (0.2126 * data[i * 4] + 0.7152 * data[i * 4 + 1] + 0.0722 * data[i * 4 + 2]) / 255;
    height[i] = lum * (data[i * 4 + 3] / 255);
  }
  const blurred = boxBlur(boxBlur(height, w, h, BLUR_RADIUS, true), w, h, BLUR_RADIUS, false);
  const at = (x: number, y: number): number => blurred[Math.min(h - 1, Math.max(0, y)) * w + Math.min(w - 1, Math.max(0, x))];

  const normals = Buffer.alloc(w * h * 3);
  const rough = Buffer.alloc(w * h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const i = y * w + x;
      const a = data[i * 4 + 3];
      let nx = 0;
      let ny = 0;
      if (a > 8) {
        // Sobel. Image rows grow downward but +V is up, so the green slope is dh/drow (OpenGL convention).
        const dx = at(x + 1, y - 1) + 2 * at(x + 1, y) + at(x + 1, y + 1) - at(x - 1, y - 1) - 2 * at(x - 1, y) - at(x - 1, y + 1);
        const dy = at(x - 1, y + 1) + 2 * at(x, y + 1) + at(x + 1, y + 1) - at(x - 1, y - 1) - 2 * at(x, y - 1) - at(x + 1, y - 1);
        nx = -dx * STRENGTH;
        ny = dy * STRENGTH;
      }
      const len = Math.hypot(nx, ny, 1);
      normals[i * 3] = Math.round(((nx / len) * 0.5 + 0.5) * 255);
      normals[i * 3 + 1] = Math.round(((ny / len) * 0.5 + 0.5) * 255);
      normals[i * 3 + 2] = Math.round(((1 / len) * 0.5 + 0.5) * 255);
      // Matte cloth in the shadows (0.9) to a wet sheen on the highlights (~0.35).
      const lum = height[i] / Math.max(a / 255, 1e-3);
      rough[i] = Math.round(Math.min(1, Math.max(0.2, 0.9 - 0.55 * lum * lum)) * 255);
    }
  }

  const opts = ext === ".webp" ? { lossless: true } : {};
  const nPath = join(dir, `${name}_n${ext}`);
  const rPath = join(dir, `${name}_r${ext}`);
  await sharp(normals, { raw: { width: w, height: h, channels: 3 } }).toFormat(ext === ".webp" ? "webp" : "png", opts).toFile(nPath);
  await sharp(rough, { raw: { width: w, height: h, channels: 1 } }).toFormat(ext === ".webp" ? "webp" : "png", opts).toFile(rPath);
  console.log(`${file} -> ${nPath}, ${rPath}`);
}

function boxBlur(src: Float32Array, w: number, h: number, r: number, horizontal: boolean): Float32Array {
  const out = new Float32Array(src.length);
  const n = 2 * r + 1;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let sum = 0;
      for (let k = -r; k <= r; k++) {
        const xx = horizontal ? Math.min(w - 1, Math.max(0, x + k)) : x;
        const yy = horizontal ? y : Math.min(h - 1, Math.max(0, y + k));
        sum += src[yy * w + xx];
      }
      out[y * w + x] = sum / n;
    }
  }
  return out;
}

const sources = readdirSync(DIR).filter((f) => /\.(png|webp)$/.test(f) && !/_[nr]\.(png|webp)$/.test(f));
for (const f of sources) await bake(join(DIR, f));
