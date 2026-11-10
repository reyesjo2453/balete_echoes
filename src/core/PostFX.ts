import * as THREE from "three";
import { EffectComposer } from "three/examples/jsm/postprocessing/EffectComposer.js";
import { RenderPass } from "three/examples/jsm/postprocessing/RenderPass.js";
import { ShaderPass } from "three/examples/jsm/postprocessing/ShaderPass.js";
import { UnrealBloomPass } from "three/examples/jsm/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/examples/jsm/postprocessing/OutputPass.js";

/**
 * Comic-ink finish for the 3D world, so the lit environment and the hand-inked character sprites read
 * as one picture instead of "game world with stickers on it":
 *  - depth-based ink outlines on silhouettes and wall/floor corners
 *  - a cool-shadow / warm-light grade with a touch of extra contrast
 *  - a faint halftone in the deepest shadows (print texture), vignette and film grain
 *  - soft bloom on lamps, neon and the watch glow
 * `?fx=0` turns it off, `?fx=lite` keeps ink and grade but drops bloom (for slow GPUs).
 */
const InkGradeShader = {
  uniforms: {
    tDiffuse: { value: null as THREE.Texture | null },
    tDepth: { value: null as THREE.Texture | null },
    texel: { value: new THREE.Vector2(1, 1) },
    cameraNear: { value: 0.1 },
    cameraFar: { value: 200 },
    time: { value: 0 },
    aspect: { value: 1 },
    ink: { value: 0.9 },
  },
  vertexShader: /* glsl */ `
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }`,
  fragmentShader: /* glsl */ `
    uniform sampler2D tDiffuse;
    uniform sampler2D tDepth;
    uniform vec2 texel;
    uniform float cameraNear;
    uniform float cameraFar;
    uniform float time;
    uniform float aspect;
    uniform float ink;
    varying vec2 vUv;

    float viewDist(vec2 uv) {
      float d = texture2D(tDepth, uv).x;
      float z = d * 2.0 - 1.0;
      return (2.0 * cameraNear * cameraFar) / (cameraFar + cameraNear - z * (cameraFar - cameraNear));
    }
    float hash(vec2 p) {
      return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
    }

    void main() {
      vec4 base = texture2D(tDiffuse, vUv);
      vec3 col = base.rgb;

      // --- ink outlines from view-space depth (relative, so near and far get the same line weight)
      vec2 o = texel * 1.25;
      float d0 = viewDist(vUv);
      float dx = abs(viewDist(vUv + vec2(o.x, 0.0)) - viewDist(vUv - vec2(o.x, 0.0)));
      float dy = abs(viewDist(vUv + vec2(0.0, o.y)) - viewDist(vUv - vec2(0.0, o.y)));
      float edge = max(dx, dy) / max(d0, 0.001);
      float line = smoothstep(0.02, 0.07, edge);
      line *= 1.0 - smoothstep(26.0, 46.0, d0); // thin far detail (wires, distant windows) stays clean
      col = mix(col, vec3(0.012, 0.01, 0.02), line * ink);

      // --- grade: cool violet shadows, warm highlights, a little more punch
      float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
      vec3 shadowTint = vec3(0.92, 0.95, 1.08);
      vec3 lightTint = vec3(1.08, 1.0, 0.9);
      col *= mix(shadowTint, lightTint, smoothstep(0.02, 0.9, lum));
            float sat = 1.12;
      float l2 = dot(col, vec3(0.2126, 0.7152, 0.0722));
      col = mix(vec3(l2), col, sat);

      // --- halftone dots in the deep shadows (print texture)
      vec2 px = vUv / texel;
      vec2 cell = fract(px / 5.0) - 0.5;
      float dots = smoothstep(0.34, 0.26, length(cell));
      float shadowMask = 1.0 - smoothstep(0.02, 0.2, l2);
      col *= 1.0 - dots * shadowMask * 0.14;

      // --- vignette and grain
      vec2 q = vUv - 0.5;
      q.x *= aspect;
      float vig = smoothstep(0.95, 0.25, length(q));
      col *= mix(0.8, 1.0, vig);
      col += (hash(px + time) - 0.5) * 0.018;

      gl_FragColor = vec4(max(col, 0.0), base.a);
    }`,
};

export type FxMode = "full" | "lite" | "off";

export function fxModeFromUrl(): FxMode {
  const v = new URLSearchParams(location.search).get("fx");
  return v === "0" || v === "off" ? "off" : v === "lite" ? "lite" : "full";
}

export class PostFX {
  readonly composer: EffectComposer;
  private readonly ink: ShaderPass;
  private readonly bloom: UnrealBloomPass | null;
  private time = 0;

  constructor(
    private readonly renderer: THREE.WebGLRenderer,
    scene: THREE.Scene,
    private readonly camera: THREE.PerspectiveCamera,
    mode: Exclude<FxMode, "off">
  ) {
    const size = renderer.getDrawingBufferSize(new THREE.Vector2());
    const target = new THREE.WebGLRenderTarget(size.x, size.y, {
      type: THREE.HalfFloatType,
      samples: 4,
      depthTexture: new THREE.DepthTexture(size.x, size.y),
    });
    this.composer = new EffectComposer(renderer, target);
    this.composer.addPass(new RenderPass(scene, camera));

    this.ink = new ShaderPass(InkGradeShader);
    const render = this.ink.render.bind(this.ink);
    // The scene's depth lives in the buffer the RenderPass just wrote; point the shader at it each frame.
    this.ink.render = (r, writeBuffer, readBuffer, dt, mask) => {
      this.ink.uniforms.tDepth.value = readBuffer.depthTexture;
      render(r, writeBuffer, readBuffer, dt, mask);
    };
    this.composer.addPass(this.ink);

    if (mode === "full") {
      this.bloom = new UnrealBloomPass(new THREE.Vector2(size.x / 2, size.y / 2), 0.42, 0.55, 0.88);
      this.composer.addPass(this.bloom);
    } else {
      this.bloom = null;
    }
    this.composer.addPass(new OutputPass());
  }

  setSize(w: number, h: number, dpr: number): void {
    this.composer.setPixelRatio(dpr);
    this.composer.setSize(w, h);
    const px = this.renderer.getDrawingBufferSize(new THREE.Vector2());
    this.ink.uniforms.texel.value.set(1 / px.x, 1 / px.y);
    this.ink.uniforms.aspect.value = w / h;
    this.bloom?.setSize(px.x / 2, px.y / 2);
  }

  render(dt: number): void {
    this.time = (this.time + dt) % 1000;
    this.ink.uniforms.time.value = this.time;
    this.ink.uniforms.cameraNear.value = this.camera.near;
    this.ink.uniforms.cameraFar.value = this.camera.far;
    this.composer.render(dt);
  }
}
