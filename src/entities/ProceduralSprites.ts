import * as THREE from "three";

/**
 * Local fallbacks used when public/assets/sprites/*.png are missing
 * (e.g. fetch-assets hit a rate limit). Both draw on a transparent canvas
 * so alphaTest cuts them out cleanly.
 */

const W = 256;
const H = 460; // ~1.0 : 1.8 billboard aspect

function canvas(): [HTMLCanvasElement, CanvasRenderingContext2D] {
  const c = document.createElement("canvas");
  c.width = W;
  c.height = H;
  return [c, c.getContext("2d")!];
}

function finish(c: HTMLCanvasElement): THREE.CanvasTexture {
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

function ink(ctx: CanvasRenderingContext2D): void {
  ctx.strokeStyle = "#0b0d14";
  ctx.lineWidth = 4;
  ctx.lineJoin = "round";
  ctx.stroke();
}

/** Renzo: dark hair, denim vest, folded knife. */
export function createRenzoTexture(): THREE.CanvasTexture {
  const [c, ctx] = canvas();
  const cx = W / 2;

  // legs
  for (const dx of [-30, 6]) {
    ctx.fillStyle = "#222a3d";
    ctx.beginPath();
    ctx.roundRect(cx + dx, 290, 26, 140, 6);
    ctx.fill();
    ink(ctx);
    ctx.fillStyle = "#14161f";
    ctx.beginPath();
    ctx.roundRect(cx + dx - 4, 425, 34, 22, 6);
    ctx.fill();
    ink(ctx);
  }
  // shirt / torso
  ctx.fillStyle = "#2a2f3a";
  ctx.beginPath();
  ctx.roundRect(cx - 50, 130, 100, 170, 14);
  ctx.fill();
  ink(ctx);
  // denim vest panels
  ctx.fillStyle = "#3f6a9e";
  for (const sx of [-1, 1]) {
    ctx.beginPath();
    ctx.moveTo(cx + sx * 8, 134);
    ctx.lineTo(cx + sx * 52, 134);
    ctx.lineTo(cx + sx * 50, 290);
    ctx.lineTo(cx + sx * 12, 290);
    ctx.closePath();
    ctx.fill();
    ink(ctx);
    ctx.strokeStyle = "#8fb4dc"; // stitching
    ctx.lineWidth = 2;
    ctx.setLineDash([6, 5]);
    ctx.beginPath();
    ctx.moveTo(cx + sx * 14, 150);
    ctx.lineTo(cx + sx * 16, 280);
    ctx.stroke();
    ctx.setLineDash([]);
  }
  // arms
  ctx.fillStyle = "#c58f63";
  for (const sx of [-1, 1]) {
    ctx.beginPath();
    ctx.roundRect(cx + sx * 66 - 12, 140, 24, 120, 10);
    ctx.fill();
    ink(ctx);
  }
  // folded knife in right hand
  ctx.fillStyle = "#6b4a2b";
  ctx.beginPath();
  ctx.roundRect(cx + 56, 250, 14, 44, 4);
  ctx.fill();
  ink(ctx);
  ctx.fillStyle = "#cfd6e4";
  ctx.beginPath();
  ctx.roundRect(cx + 58, 236, 8, 22, 2);
  ctx.fill();
  ink(ctx);
  // head
  ctx.fillStyle = "#c58f63";
  ctx.beginPath();
  ctx.ellipse(cx, 84, 40, 46, 0, 0, Math.PI * 2);
  ctx.fill();
  ink(ctx);
  // messy dark hair
  ctx.fillStyle = "#14101a";
  ctx.beginPath();
  ctx.moveTo(cx - 46, 90);
  ctx.quadraticCurveTo(cx - 54, 20, cx - 10, 24);
  ctx.lineTo(cx - 20, 4);
  ctx.lineTo(cx + 2, 22);
  ctx.lineTo(cx + 18, 2);
  ctx.lineTo(cx + 22, 26);
  ctx.quadraticCurveTo(cx + 56, 24, cx + 46, 90);
  ctx.lineTo(cx + 34, 62);
  ctx.quadraticCurveTo(cx, 50, cx - 34, 66);
  ctx.closePath();
  ctx.fill();
  ink(ctx);
  // eyes
  ctx.fillStyle = "#0b0d14";
  ctx.fillRect(cx - 22, 82, 10, 8);
  ctx.fillRect(cx + 12, 82, 10, 8);
  return finish(c);
}

/** Corrupted Aswang: hunched shadow ghoul, red eyes, jagged claws. */
export function createAswangTexture(): THREE.CanvasTexture {
  const [c, ctx] = canvas();
  const cx = W / 2;

  // ragged smoky body
  const body = ctx.createLinearGradient(0, 100, 0, H);
  body.addColorStop(0, "#3a1630");
  body.addColorStop(1, "#120712");
  ctx.fillStyle = body;
  ctx.beginPath();
  ctx.moveTo(cx - 20, 90);
  ctx.quadraticCurveTo(cx - 100, 170, cx - 84, 300);
  for (let i = 0; i <= 9; i++) {
    // jagged tattered hem
    const x = cx - 84 + (i * 168) / 9;
    ctx.lineTo(x, 430 + (i % 2 ? 24 : -8));
  }
  ctx.quadraticCurveTo(cx + 100, 170, cx + 20, 90);
  ctx.closePath();
  ctx.fill();
  ink(ctx);

  // long arms with jagged claws
  for (const sx of [-1, 1]) {
    ctx.fillStyle = "#24101f";
    ctx.beginPath();
    ctx.moveTo(cx + sx * 56, 140);
    ctx.quadraticCurveTo(cx + sx * 116, 220, cx + sx * 96, 330);
    ctx.lineTo(cx + sx * 70, 320);
    ctx.quadraticCurveTo(cx + sx * 84, 230, cx + sx * 40, 170);
    ctx.closePath();
    ctx.fill();
    ink(ctx);
    ctx.fillStyle = "#e8dfe6";
    for (let k = 0; k < 4; k++) {
      const x0 = cx + sx * (68 + k * 11);
      ctx.beginPath();
      ctx.moveTo(x0 - 5, 328);
      ctx.lineTo(x0 + sx * 3, 388 + (k % 2) * 10);
      ctx.lineTo(x0 + 6, 328);
      ctx.closePath();
      ctx.fill();
      ink(ctx);
    }
  }

  // head
  ctx.fillStyle = "#1d0d1a";
  ctx.beginPath();
  ctx.ellipse(cx, 70, 46, 54, 0, 0, Math.PI * 2);
  ctx.fill();
  ink(ctx);
  // horn-like wisps
  ctx.beginPath();
  ctx.moveTo(cx - 30, 30);
  ctx.lineTo(cx - 48, -2 + 6);
  ctx.lineTo(cx - 14, 22);
  ctx.moveTo(cx + 30, 30);
  ctx.lineTo(cx + 48, 4);
  ctx.lineTo(cx + 14, 22);
  ctx.fill();
  // glowing red eyes
  ctx.shadowColor = "#ff2a44";
  ctx.shadowBlur = 18;
  ctx.fillStyle = "#ff4a5e";
  ctx.beginPath();
  ctx.moveTo(cx - 28, 62);
  ctx.lineTo(cx - 8, 70);
  ctx.lineTo(cx - 28, 76);
  ctx.closePath();
  ctx.moveTo(cx + 28, 62);
  ctx.lineTo(cx + 8, 70);
  ctx.lineTo(cx + 28, 76);
  ctx.closePath();
  ctx.fill();
  ctx.shadowBlur = 0;
  // fanged maw
  ctx.fillStyle = "#e8dfe6";
  for (let i = -2; i <= 2; i++) {
    ctx.beginPath();
    ctx.moveTo(cx + i * 10 - 4, 98);
    ctx.lineTo(cx + i * 10, 112);
    ctx.lineTo(cx + i * 10 + 4, 98);
    ctx.fill();
  }
  return finish(c);
}
