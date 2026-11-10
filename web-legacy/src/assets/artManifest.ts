/**
 * Art manifest: the single source of truth for every image the story needs.
 *
 * PLUG AND PLAY: the game asks for art by `id`. If a file exists at
 * `public/assets/<dir>/<name>.(webp|png|jpg)` it is used; otherwise a labelled placeholder is drawn.
 * To ship art: generate it to the spec below, save it at that path, commit. No code change.
 *
 * This file is pure data (no Vite/DOM imports) so scripts/asset-report.ts can read it in Node.
 * `brief` is the generation prompt seed for Merlin. Style for everything: see docs/ASSET_PIPELINE.md.
 */

export type ArtKind = "panel" | "portrait" | "background";

export interface ArtEntry {
  id: string;
  kind: ArtKind;
  /** Folder under public/assets. */
  dir: "comics" | "portraits" | "world";
  /** File name without extension. */
  name: string;
  /** What to draw: the prompt seed. */
  brief: string;
  /** Where in the story it appears (for the reader / Merlin's ordering). */
  scene: string;
}

/** Target pixel sizes per kind (what to generate at). */
export const ART_SPECS: Record<ArtKind, { width: number; height: number; formats: string; note: string }> = {
  panel: { width: 1600, height: 900, formats: "webp (preferred), png, jpg", note: "16:9. Cropped by a slanted mask: keep the subject centered, safe margin ~12%. Bottom 28% is covered by the dialogue box." },
  portrait: { width: 512, height: 512, formats: "png (transparent bg) or webp", note: "Square bust, face centered, shown at 72px: bold readable silhouette, strong ink lines." },
  background: { width: 1920, height: 1080, formats: "webp, jpg", note: "16:9 full-bleed, no characters in the lower third." },
};

const P = (id: string, scene: string, brief: string, name = id): ArtEntry => ({ id, kind: "panel", dir: "comics", name, brief, scene });
const PORTRAIT = (id: string, brief: string): ArtEntry => ({ id: `portrait_${id}`, kind: "portrait", dir: "portraits", name: id, brief, scene: "Dialogue box (all scenes)" });

export const ART_MANIFEST: ArtEntry[] = [
  // ---- Portraits ---------------------------------------------------------
  PORTRAIT("renzo", "Renzo Reyes, 22, Quiapo courier and watchmaker's apprentice. Lean, tired eyes, rain-damp hair, courier jacket, a loupe pushed up on his forehead. Guarded, cynical half-smile."),
  PORTRAIT("lola", "Lola Rosa Reyes, ~70s, Quiapo herbalist. Silver hair in a bun, shawl over a housedress, reading glasses on a cord. Warm face that gives nothing away."),
  PORTRAIT("dante", "Dante, Tondo ex-mechanic, heavyset, oil-stained coveralls, short beard, a copper-wired battery harness strap over one shoulder. Pragmatic, weary."),
  PORTRAIT("runner", "A teenage lender's runner in a dripping rain poncho, hood up, face half shadowed. Anonymous, quick."),
  PORTRAIT("mang_domeng", "Mang Domeng, elderly Quiapo vendor, sun-creased face, faded cap, candle stall apron. Tired kindness."),
  PORTRAIT("sacristan", "The church sacristan, thin, cassock sleeves, wire glasses, nervous eyes. Knows more than he says."),

  // ---- Episode 1 · Morning: the shop -------------------------------------
  P("ep1_01_quiapo_dawn", "Cold open / Morning", "Establishing shot of Quiapo at 6 AM in the rain: Quiapo Church facade with its twin towers, wet streets, candle and herb vendors setting up under tarps, jeepney lights. Neutral greys and browns, warm gold lit windows; teal only on a neon sign."),
  P("ep1_02_workbench_notice", "Morning · the shop", "Close on a cluttered watchmaker's bench: an antique pocket watch with a loupe resting on it, a lender's final notice (Honda Beat, delinquent) under a pair of tweezers, a stator coil in a cardboard box. Renzo's hands, rain on the window behind."),
  P("ep1_02b_stopped_clocks", "Morning · the shop", "The Reyes watch-repair shop wall: nine old clocks of different sizes, every one stopped at exactly 4:17, dust on their glass; Renzo's silhouette at the bench below, a herb-drying rack beside them. Warm gold lamp, rain on the window."),
  P("ep1_03_lola_packing", "Morning · the shop", "Lola Rosa wrapping jars of coconut oil in newspaper behind the counter; crates and half-filled sacks stacked behind her; dried herbs hanging. She is not looking at the camera. Shop interior, warm gold lamp, rain outside."),
  P("ep1_03b_tin_slip", "Morning · the watch (QTE: CATCH)", "Dynamic close-up: Lola Rosa's shaking hands losing a square of black cloth, a pocket watch of pale carved wood tumbling out of it mid-air, Renzo's hand lunging in from the frame edge. Motion lines, wide eyes, urgent."),
  P("ep1_03c_watch_warm", "Morning · the watch", "Renzo's cupped hands holding the balete-wood pocket watch in black cloth, a faint warm amber glow rising from it; Lola Rosa's worried face out of focus behind. Quiet, intimate."),
  P("ep1_04_runner_parcel", "Morning · the runner", "Shop doorway: a rain-poncho runner's silhouette leaving, a taped brown parcel and a folded note left on the counter in the foreground."),
  P("ep1_05_corkboard", "Morning · the board", "The cooperative corkboard: three job cards pinned under a rubber stamp and a ledger notebook hanging on string. Dim shop light, shallow focus."),
  P("ep1_06_honda_ride", "Morning · step out", "Renzo in helmet and gloves kick-starting a battered Honda Beat scooter in a rainy Quiapo street, visor beaded with rain, church towers behind. Dynamic low angle."),

  P("ep1_06b_ride_ticking", "Morning · the ride", "Renzo riding the Honda Beat through rainy Quiapo, a small warm glow at his jacket pocket; the church bell tower behind him with a clock whose hands are visibly wrong. Motion blur, low angle."),

  // ---- Episode 1 · The Envelope (Scene P.1) ------------------------------
  P("ep1_07_mang_domeng", "The Envelope", "Renzo handing a small package to Mang Domeng at his candle stall behind the church, wet sidewalk, vendors setting up. Two-shot, friendly but tired."),
  P("ep1_08_church_undercroft", "The Envelope", "The Quiapo Church undercroft: low vaulted stone, candle racks, a sacristan and Renzo exchanging a taped parcel and a lender's envelope. Warm gold candlelight, deep ink shadows."),
  P("ep1_08b_candles_lean", "The Envelope (QTE: STEADY)", "Undercroft candle racks: every flame bent sideways in the same direction, toward Renzo's jacket pocket; the sacristan frozen mid-gesture, Renzo pressing a hand flat over a faint glow in his pocket. Low vaulted stone, gold candlelight, ink shadows."),
  P("ep1_09_watch_backward", "The Envelope", "Extreme close-up of the antique pocket watch in Renzo's palm: its hands turning counter-clockwise, gears of carved petrified balete wood. A thin teal glow from the crown only."),

  // ---- Episode 1 · Lola Rosa's Silence (Scene P.2) -----------------------
  P("ep1_10_lola_tea", "Lola Rosa's Silence", "Lola Rosa pouring herbal tea, deflecting; Renzo across the counter holding the watch; crates and half-filled bags clearly visible behind her. Their eyes do not meet."),
  P("ep1_11_lola_pressed", "Lola Rosa's Silence", "Close two-shot, Renzo leaning in pressing Lola about the watch; Lola's hands stop on the teapot, jaw set. Tension, warm lamp light on one side, cold rain light on the other."),

  // ---- Episode 1 · Dusk: the Aswang (field scene cut-ins) ----------------
  P("ep1_12_alley_delivery", "Dusk · the alley", "Renzo alone in a rain-slicked dead-end Quiapo alley behind Evangelista Street, monobloc chairs and tin overhangs, flickering streetlight, a fake invoice in his hand."),
  P("ep1_13_aswang_fire_escape", "Dusk · ambush", "A gaunt oil-and-smoke Aswang crouched on a rusted fire escape high above, hollow red eyes, a corporate telemetry tag clamped to its ear. Rain streaks, ink-black silhouette."),
  P("ep1_14_renzo_shock", "Dusk · ambush", "Renzo's face in shock, lamps dying behind him, claw shadow falling across him. Heavy ink, halftone shading."),
  P("ep1_15_renzo_cornered", "Dusk · ambush", "Renzo backed against a brick wall, balisong held low and shaking, frightened and defiant.", "renzo_cornered"),
  P("ep1_16_dante_wheel", "Dusk · the gate ram", "Dante at the wheel of the delivery van, headlights blazing down the alley.", "dante_panel1_wheel"),
  P("ep1_17_dante_approach", "Dusk · the gate ram", "The van charging down the alley toward the chained gate (wide strip panel).", "dante_panel2_approach"),
  P("ep1_18_dante_krash", "Dusk · the gate ram", "The van smashing through the chained gate, KRASH, debris and sparks (wide strip panel).", "dante_panel3_krash"),
  P("ep1_19_gate_brace", "Dusk · the gate ram (QTE)", "Renzo on the ground, headlights flooding the alley, arm raised against the glare. Urgent."),

  // ---- Episode 1 · Aftermath: the Tondo safehouse (Scene 1.1) ------------
  P("ep1_20_tondo_arrival", "Aftermath · safehouse", "Delivery van sliding to a halt inside a cavernous Tondo chop shop, steam hissing from the radiator, fluorescent tubes, diesel generators, rain on zinc siding. Renzo tumbling out of the passenger door."),
  P("ep1_21_dante_gin", "Aftermath · safehouse", "Dante dropping a first-aid kit and a bottle of gin onto a workbench; Renzo gasping on a crate, clutching his balisong. Fluorescent light, grease and steel."),
  P("ep1_22_watch_gears", "Aftermath · safehouse", "Under a magnifying lamp: the watch opened, gears of petrified balete wood and cold-cast iron spinning backward with no mainspring. Dante's thick finger pointing."),
  P("ep1_23_aevum_chatter", "Aftermath · cliffhanger", "A battered scanner on Dante's bench crackling, its small screen showing a map of Quiapo with red markers; Renzo's stricken face reflected in it."),
  P("ep1_24_workshop_raid", "Aftermath · cliffhanger", "Lola Rosa's ransacked workshop seen from the street: Aevum chevron-marked black vans, masked extraction team carrying crates, Lola led out between two guards, rain. Distant, cold, ink and teal chevron accent."),
  P("ep1_25_watch_future", "Aftermath · cliffhanger", "The pocket watch face glowing, its hands pointing to a time and a name scratched into the glass that Renzo should not know. Extreme close-up, one teal glow."),
];

export const ART_BY_ID: Record<string, ArtEntry> = Object.fromEntries(ART_MANIFEST.map((e) => [e.id, e]));
export const ART_EXTENSIONS = ["webp", "png", "jpg"] as const;
