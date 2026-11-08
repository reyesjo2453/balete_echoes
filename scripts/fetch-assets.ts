/**
 * Fetch character sprites from fal.ai (flux/dev -> rembg) into public/assets/sprites.
 *
 *   FAL_KEY=... npm run fetch-assets            # fetch missing sprites
 *   FAL_KEY=... npm run fetch-assets -- --force # regenerate everything
 *
 * Never fails the build: on a missing key, rate limit or network error the
 * sprite is skipped and the game falls back to procedural canvas textures
 * (see src/entities/ProceduralSprites.ts). No dependencies; Node 22+.
 */
import { mkdir, writeFile, access } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const FAL_KEY = process.env.FAL_KEY;
const FORCE = process.argv.includes("--force");
const MAX_RETRIES = 3;

interface SpriteJob {
  file: string;
  prompt: string;
}

const STYLE = "anime JRPG character art, full body, centered, plain flat background, clean cel shading";

const JOBS: SpriteJob[] = [
  {
    file: "public/assets/sprites/renzo_idle.png",
    prompt:
      `Renzo, young Filipino courier, Act I, dark messy hair, worn denim vest over a dark shirt, ` +
      `folded pocket knife in hand, standing idle pose, ${STYLE}`,
  },
  {
    file: "public/assets/sprites/aswang_idle.png",
    prompt:
      `Corrupted Aswang, feral shadow ghoul, hunched body of smoky darkness, glowing red eyes, ` +
      `long jagged claws, tattered silhouette, standing idle pose, ${STYLE}`,
  },
];

class FalError extends Error {
  readonly retryable: boolean;
  constructor(message: string, retryable: boolean) {
    super(message);
    this.retryable = retryable;
  }
}

async function fal<T>(model: string, body: unknown): Promise<T> {
  for (let attempt = 0; ; attempt++) {
    try {
      const res = await fetch(`https://fal.run/${model}`, {
        method: "POST",
        headers: { Authorization: `Key ${FAL_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      if (!res.ok) {
        const retryable = res.status === 429 || res.status >= 500;
        throw new FalError(`${model} -> ${res.status} ${(await res.text()).slice(0, 200)}`, retryable);
      }
      return (await res.json()) as T;
    } catch (err) {
      const retryable = err instanceof FalError ? err.retryable : true; // network errors retry
      if (!retryable || attempt >= MAX_RETRIES) throw err;
      const wait = 2000 * 2 ** attempt;
      console.warn(`  retry ${attempt + 1}/${MAX_RETRIES} in ${wait}ms (${(err as Error).message})`);
      await new Promise((r) => setTimeout(r, wait));
    }
  }
}

async function generate(job: SpriteJob): Promise<Buffer> {
  const gen = await fal<{ images: Array<{ url: string }> }>("fal-ai/flux/dev", {
    prompt: job.prompt,
    image_size: { width: 512, height: 512 },
    num_images: 1,
    enable_safety_checker: true,
  });
  const src = gen.images?.[0]?.url;
  if (!src) throw new Error("flux/dev returned no image");

  const cut = await fal<{ image: { url: string } }>("fal-ai/imageutils/rembg", { image_url: src });
  const out = cut.image?.url;
  if (!out) throw new Error("rembg returned no image");

  const png = await fetch(out);
  if (!png.ok) throw new Error(`download failed: ${png.status}`);
  return Buffer.from(await png.arrayBuffer());
}

const exists = (p: string) => access(p).then(() => true, () => false);

async function main(): Promise<void> {
  if (!FAL_KEY) {
    console.warn("[fetch-assets] FAL_KEY not set — skipping. Procedural fallback textures will be used.");
    return;
  }
  for (const job of JOBS) {
    const dest = resolve(ROOT, job.file);
    if (!FORCE && (await exists(dest))) {
      console.log(`[fetch-assets] ${job.file} exists (use --force to regenerate)`);
      continue;
    }
    console.log(`[fetch-assets] generating ${job.file} ...`);
    try {
      const data = await generate(job);
      await mkdir(dirname(dest), { recursive: true });
      await writeFile(dest, data);
      console.log(`  saved ${data.length} bytes`);
    } catch (err) {
      console.warn(`  failed: ${(err as Error).message}\n  -> falling back to procedural texture at runtime`);
    }
  }
}

main().catch((err) => {
  console.warn("[fetch-assets] unexpected error:", err);
}); // always exit 0
