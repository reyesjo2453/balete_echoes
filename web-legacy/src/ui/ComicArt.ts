/**
 * Procedural SVG comic art used when a step has no panel image on disk.
 * Each entry is a self-contained data URI.
 */
const svg = (body: string): string =>
  `url("data:image/svg+xml;utf8,${encodeURIComponent(
    `<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 800 450' preserveAspectRatio='xMidYMid slice'>${body}</svg>`
  )}")`;

const WOOD = `
  <defs>
    <linearGradient id='w' x1='0' y1='0' x2='0' y2='1'>
      <stop offset='0' stop-color='#5a3a22'/><stop offset='1' stop-color='#2c1a0e'/>
    </linearGradient>
  </defs>
  <rect width='800' height='450' fill='url(#w)'/>
  ${Array.from({ length: 14 }, (_, i) => `<path d='M0 ${20 + i * 32} Q 200 ${10 + i * 32} 400 ${24 + i * 32} T 800 ${18 + i * 32}' stroke='#1c0f07' stroke-opacity='.45' stroke-width='2' fill='none'/>`).join("")}`;

export const COMIC_ART: Record<string, string> = {
  /** Broken wax seal on the counter. */
  seal: svg(`${WOOD}
    <circle cx='400' cy='225' r='88' fill='#8a1c1c'/>
    <circle cx='400' cy='225' r='88' fill='none' stroke='#c24040' stroke-width='6'/>
    <path d='M340 170 L400 230 L350 290 M460 170 L415 225 L465 285' stroke='#1a0808' stroke-width='9' fill='none' stroke-linecap='round'/>
    <ellipse cx='520' cy='310' rx='60' ry='14' fill='#6b1414' opacity='.7'/>`),
  /** Claw marks gouged into wood. */
  claws: svg(`${WOOD}
    ${[0, 1, 2, 3].map((i) => `<path d='M${200 + i * 105} 40 Q ${260 + i * 105} 220 ${210 + i * 105} 410' stroke='#120905' stroke-width='16' fill='none' stroke-linecap='round'/><path d='M${205 + i * 105} 60 Q ${262 + i * 105} 220 ${216 + i * 105} 395' stroke='#d9a76a' stroke-width='3' fill='none' opacity='.8'/>`).join("")}`),
  /** Shadow silhouette in a rainy alley. */
  silhouette: svg(`
    <defs><radialGradient id='g' cx='.5' cy='.45' r='.7'><stop offset='0' stop-color='#6a1b5c'/><stop offset='1' stop-color='#07040c'/></radialGradient></defs>
    <rect width='800' height='450' fill='url(#g)'/>
    ${Array.from({ length: 40 }, (_, i) => `<line x1='${(i * 83) % 800}' y1='${(i * 47) % 300}' x2='${((i * 83) % 800) - 18}' y2='${((i * 47) % 300) + 60}' stroke='#9fb4ff' stroke-opacity='.35' stroke-width='2'/>`).join("")}
    <path d='M400 70 C 350 70 340 130 360 160 L 300 300 L 330 420 L 370 420 L 385 320 L 415 320 L 430 420 L 470 420 L 500 300 L 440 160 C 460 130 450 70 400 70Z' fill='#030208'/>
    <path d='M360 280 L 250 360 M440 280 L 560 350' stroke='#030208' stroke-width='18' stroke-linecap='round'/>
    <circle cx='385' cy='110' r='7' fill='#ff3b3b'/><circle cx='418' cy='110' r='7' fill='#ff3b3b'/>`),
  /** Folding blade drawn. */
  blade: svg(`
    <defs><linearGradient id='b' x1='0' y1='0' x2='1' y2='1'><stop offset='0' stop-color='#10162b'/><stop offset='1' stop-color='#2a1f4a'/></linearGradient></defs>
    <rect width='800' height='450' fill='url(#b)'/>
    <g stroke='#fff' stroke-opacity='.18' stroke-width='3'>${Array.from({ length: 24 }, (_, i) => `<line x1='400' y1='225' x2='${400 + Math.cos(i * 0.26) * 900}' y2='${225 + Math.sin(i * 0.26) * 900}'/>`).join("")}</g>
    <path d='M170 360 L 620 90 L 640 110 L 200 390 Z' fill='#d8e2f5'/>
    <path d='M170 360 L 620 90 L 626 100 L 190 380Z' fill='#ffffff'/>
    <rect x='120' y='360' width='110' height='30' rx='8' transform='rotate(-32 175 375)' fill='#4a2e17'/>`),
};
