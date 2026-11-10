"""Builds godot/data/episode1_extra.json and episode1_flow.json (the expanded Episode 1).

Run:  python3 tools/build_episode1_extra.py
Scenes are lists of steps (kind say/think/narr, optional panel/portrait/qte/choice, `if`/`unless` flags and `fx`
effects). Each beat in the flow has a goal; the CI checks that every scene beat has a goal and a choice or an
action beat, and prints an estimated play time.
"""
import json, os, copy

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "godot", "data")

PORT = {"renzo": "portrait_renzo", "lola": "portrait_lola", "dante": "portrait_dante",
        "domeng": "portrait_mang_domeng", "sacristan": "portrait_sacristan", "runner": "portrait_runner"}
NAME = {"renzo": "Renzo", "lola": "Lola Rosa", "dante": "Dante", "domeng": "Mang Domeng",
        "sacristan": "Sacristan", "cora": "Aling Cora", "efren": "Kuya Efren", "valdez": "R. Valdez",
        "baker": "Baker's apprentice", "agent": "Aevum guard"}


def say(who, text, **k):
    d = {"kind": "say", "speaker": NAME[who], "text": text}
    if who in PORT:
        d["portrait"] = PORT[who]
    d.update(k)
    return d


def think(text, **k):
    d = {"kind": "think", "speaker": "Renzo", "portrait": PORT["renzo"], "text": text}
    d.update(k)
    return d


def narr(text, **k):
    d = {"kind": "narr", "speaker": "", "text": text}
    d.update(k)
    return d


def choice(cid, prompt, options, effects, seconds=12, default=0, **k):
    d = think(prompt, choice={"id": cid, "options": options, "seconds": seconds, "default": default, "effects": effects})
    d.update(k)
    return d


S = {}

# ------------------------------------------------------------------------------------------------ ACT 1
S["bench"] = [
    narr("The shop is quiet for eleven minutes before the cooperative's board opens. Renzo spends them where he always does: at the bench.", layout="banner", panel="ep1_02_workbench_notice"),
    think("Three things on this bench do not belong. I only have time to chase two."),
    choice("bench1", "What do I look at first?", ["Valdez's notice", "The stopped clocks' note", "Lola's crates"],
           [{"flags": ["bench_notice"]}, {"flags": ["bench_clocks"]}, {"flags": ["bench_crates"]}]),
    narr("Asian Housing & Credit Corp. Under the red FINAL NOTICE stamp, in smaller type: 'Collections Officer: R. Valdez. Tow unit dispatched 12:00 noon. Seizure of leased premises to follow.'", **{"if": "bench_notice"}),
    think("Leased premises. Not the bike. The shop.", **{"if": "bench_notice"}),
    think("Valdez isn't after a Honda. The Honda is just the door.", **{"if": "bench_notice"}),
    narr("The pendulum clock's case is still open from this morning. Under Lola's note, in pencil so faint it is almost not there: 'A.R. 4:17, 3 Hunyo 1998. Hindi na sila tumigil.' They never stopped.", **{"if": "bench_clocks"}),
    think("A.R. Andres Reyes. Lolo. 'They never stopped.' Who never stopped?", **{"if": "bench_clocks"}),
    narr("One crate lid is loose. Newspaper, jars, a flour sack, and under them a bus pass to Vigan, dated tomorrow morning, with one name on it. Not Renzo's.", **{"if": "bench_crates"}),
    think("She bought one seat. For herself, or for the watch.", **{"if": "bench_crates"}),
    choice("bench2", "Keep digging, or go downstairs to Lola?", ["Keep digging (10 minutes)", "Go downstairs now"],
           [{"flags": ["bench_dug"], "spend": 10, "loob": 1}, {"flags": ["bench_left"]}]),
    think("Put it together. Valdez wants the shop. Lolo's note says something never stopped. Lola is packing for Vigan.", **{"if": "bench_dug"}),
    think("Whatever 'they' are, she has been outrunning them for twenty-six years, and she has been doing it alone.", **{"if": "bench_dug"}),
    narr("Downstairs, a kettle begins to whistle.", flash=False),
]

S["lola_tea"] = [
    say("lola", "Sit. The board will not open faster because you are standing.", layout="banner", panel="ep1_10_lola_tea"),
    narr("Tanglad and chamomile, in the same chipped cup Renzo has used since he was nine."),
    say("renzo", "You've been quiet all week, 'La."),
    say("lola", "I have been counting. It is not the same as quiet."),
    think("She counts when she's afraid. Jars. Crates. Days."),
    say("lola", "Your Lolo used to say a shop is a clock. Every part must agree about what time it is."),
    say("renzo", "Is that why you stopped them all? So they would agree?"),
    say("lola", "That is a clever thing to notice, anak."),
    choice("tea", "She's offering me one question. Maybe.", ["Ask about Lolo", "Ask about the crates", "Say nothing and drink your tea"],
           [{"flags": ["tea_lolo"], "loob": 0}, {"flags": ["tea_crates"], "loob": 1}, {"flags": ["tea_quiet"], "trust": 0}], seconds=14, default=2),
    say("lola", "He was a watchmaker the way some men are fishermen. Patient, and a little afraid of the sea.", **{"if": "tea_lolo"}),
    say("lola", "The night of the flood in '98 he went out at four in the morning, and he took the old watch. He came back at dawn with the water at his knees and said only: 'Hindi na ito titigil.' It will not stop.", **{"if": "tea_lolo"}),
    think("'They never stopped.' 'It will not stop.' The same words, twenty-six years apart.", **{"if": "tea_lolo"}),
    say("lola", "Packing is not leaving.", **{"if": "tea_crates"}),
    say("renzo", "A bus pass to Vigan is leaving.", **{"if": "tea_crates"}),
    say("lola", "...You read my things.", **{"if": "tea_crates"}),
    say("renzo", "They were on the bench.", **{"if": "tea_crates"}),
    say("lola", "Then you have found what I did not hide well enough. One seat, apo. Yours is not yet bought. I wanted to see who would come first: the lenders, or the truth.", **{"if": "tea_crates"}),
    think("She is testing me. Or protecting me. With Lola there is no difference.", **{"if": "tea_crates"}),
    say("lola", "You are your Lolo's grandson. You know when to leave a gear alone.", **{"if": "tea_quiet"}),
    narr("The tea is the only warm thing in the shop. For one minute neither of them needs anything else.", **{"if": "tea_quiet"}),
    think("I will find out what she is hiding. Just not on this cup of tea.", **{"if": "tea_quiet"}),
    say("lola", "Go. The board is open. Take what you can carry, and nothing you cannot."),
]

S["job_avenida"] = [
    narr("Avenida Rizal. Cloth stalls shoulder to shoulder, bolts stacked like sandbags against the rising gutters.", layout="banner", panel="ep1_01_quiapo_dawn"),
    say("cora", "Reyes! Thank God. Forty bolts of katsa for Divisoria, and the lorry driver has gone to wait out the rain somewhere dry and stupid."),
    say("renzo", "Forty bolts on a Honda Beat?"),
    say("cora", "Four trips. I will pay for four. Eight hundred for the lot, and I will call that fair."),
    choice("avenida", "Eight hundred is fair. Is fair enough?", ["Take P800 and go", "Haggle: ask P1,000 (takes longer)", "Carry it free; she will owe you"],
           [{"money": 800, "spend": 45}, {"money": 1000, "spend": 60, "loob": 1, "banner": "Haggled: P1,000, but it cost 15 extra minutes"}, {"spend": 45, "flags": ["cora_owes"], "banner": "Aling Cora owes you a favor"}], seconds=10),
    narr("Four trips. The rain soaks the katsa and the katsa soaks Renzo. On the last stack a bolt of black cloth slides loose and unrolls across the wet pavement: heavy, close-woven, the exact weave that wraps Lola's watch."),
    say("cora", "Eh, that one is not for sale. Old stock. Your Lola orders a bolt every year on the same date, and has for forty years. She has never once said what for."),
    think("Every year. On the same date.", fx={"flags": ["cora_cloth"]}),
    say("cora", "Four trips. Done. Go, go, before it floods the stall."),
]

S["job_pandacan"] = [
    narr("Pandacan. The depot sits behind a fish-processing plant that stopped processing sometime in the nineties. Its cold room still hums.", layout="banner", panel="ep1_20_tondo_arrival"),
    say("efren", "You're the Reyes boy. Compressor head's in the back. And do not open the walk-in. It is not on the inventory."),
    think("People only warn you about a door once they have opened it."),
    narr("The compressor hums on a note that is almost a word."),
    choice("pandacan", "The walk-in door is warm. Not cold. Warm.", ["Open the walk-in door", "Take the part and leave"],
           [{"flags": ["walkin"], "spend": 20, "loob": 1, "injury": 6, "banner": "Frostbitten fingers: -6 HP at the next fight"}, {"flags": ["walkin_left"]}], seconds=10, default=1),
    narr("Frost writes itself across the inside of the door as he pushes: not words. Numbers. 4:17. 4:17. 4:17, in nine different handwritings.", **{"if": "walkin"}),
    narr("The room is empty except for a chair and a stopped wall clock. Its glass is fogged from the inside.", **{"if": "walkin"}),
    say("efren", "I told you. Every Quiapo watchmaker who ever fixed that clock ended up sitting in that chair. I just keep the ice.", **{"if": "walkin"}),
    think("He is not joking, and I am not going to ask how long he has been keeping it.", **{"if": "walkin"}),
    say("efren", "Good. Smart boys live to be old men who complain about the weather.", **{"if": "walkin_left"}),
    narr("Ninety minutes, a compressor head and fifteen hundred pesos later, the Honda coughs back into the rain.", fx={"money": 1500, "spend": 90}),
]

S["church_arrival"] = [
    narr("The courtyard of Quiapo Church at noon: devotees pressed between candle stalls and mango sellers, the rain doing nothing to thin them.", layout="banner", panel="ep1_07_mang_domeng"),
    think("The parcel is taped shut, no name, and pays more than any parcel should. I am carrying it to the one place in Manila no one would think to hide anything."),
]

S["dusk_choice"] = [
    narr("Dusk. The Avenida is a brown river, and behind Renzo the church bells ring six, a heartbeat late. Ahead, two roads lead to Evangelista Street.", layout="banner", panel="ep1_12_alley_delivery"),
    think("The lit way is the long way: Carriedo, the overpass, the checkpoint where Valdez's cousins drink. Forty minutes of lamps."),
    think("The short way is the alley behind the bakeries. Ten minutes. No lamps."),
    think("Dante said stay on lit streets. Dante is a stranger on a phone."),
    choice("dusk", "Which road?", ["Take the shortcut through the alley", "Take the lit road, as Dante said"],
           [{"flags": ["shortcut"], "spend": 10, "banner": "The shortcut saves half an hour"}, {"flags": ["lit_road"], "spend": 40, "trust": 1, "banner": "Dante would approve of the lit road"}], seconds=14),
    narr("Carriedo is closed. A bus has stalled in the flood, and an Aevum checkpoint is turning every rider back.", **{"if": "lit_road"}),
    think("Aevum Filipinas. Private security. Why are they checking couriers' pockets?", **{"if": "lit_road"}),
    narr("The pocket watch ticks once, loud as a dropped coin, against his ribs. The nearest guard's head turns.", **{"if": "lit_road"}),
    think("Not here. Not that. Turn the bike around.", **{"if": "lit_road"}),
]

S["act1_hook"] = [
    narr("The alley behind Evangelista Street swallows the Honda's headlight.", layout="banner", panel="ep1_12_alley_delivery"),
    think("No lamps. No witnesses. Dante said stay on lit streets. Dante is not the one with a noon deadline.", **{"if": "shortcut"}),
    think("Every other road is closed. Dante said stay on lit streets. He didn't say what to do when the lit streets stop.", **{"if": "lit_road"}),
    narr("Renzo takes the shortcut.", flash=True),
]

# ------------------------------------------------------------------------------------------------ ACT 2
S["alley_intro"] = [
    narr("Quiapo, dusk. The watch ticks against Renzo's palm, backward and patient: one last delivery, down the alley behind Evangelista Street.", layout="banner", panel="ep1_12_alley_delivery"),
    think("The invoice says Gat. Dizon, Bodega 9. The ink is too fresh and the signature is traced. A fake. Great."),
    think("Lola has never let anyone else touch this watch, and tonight she's sending it to a stranger at the end of an alley. That is not easy money. That is a goodbye."),
]

S["alley_search"] = [
    narr("Monobloc chairs stacked behind a bakery, tin overhangs sweating rain, one streetlight that flickers like it is thinking about quitting.", layout="banner", panel="ep1_12_alley_delivery"),
    think("The invoice says Bodega 9 has a blue stripe on its door."),
    narr("Three doors have blue on them. Two of them are lying."),
    choice("alley1", "Which door?", ["The bakery's back door (smells of bread)", "The door with the dented shutter", "The door with the fresh paint (still wet)"],
           [{"flags": ["door_bakery"]}, {"flags": ["door_shutter"]}, {"flags": ["door_paint"], "loob": 1}], seconds=12),
    narr("A baker's apprentice opens, flour to the elbows, and shakes his head fast.", **{"if": "door_bakery"}),
    say("baker", "No Dizon here, sir. No blue door. Please, the alley after six is not for us. Last week the bins were torn open from the inside.", **{"if": "door_bakery"}),
    think("From the inside.", **{"if": "door_bakery"}),
    narr("The shutter dents inward under his knuckles, cracked from the other side a long time ago by something that wanted out.", **{"if": "door_shutter"}),
    think("Nothing answers. Something listens.", **{"if": "door_shutter"}),
    narr("The stripe is wet because someone wanted it to look fresh. Behind it hangs a padlock with a corporate seal: a chevron inside a circle.", **{"if": "door_paint"}),
    think("Aevum's chevron. On a lock in Quiapo.", **{"if": "door_paint"}),
    narr("A smear of black oil runs along the wall from the fire escape, under the streetlight, to Renzo's boots. It is still warm."),
    think("Warm oil in cold rain."),
    narr("The watch ticks backward faster. The oil trail points up."),
    choice("alley2", "The watch is racing. The oil points up.", ["Follow the trail up the fire escape", "Wait by the door with the watch in your fist", "Call out: 'Gat. Dizon?'"],
           [{"flags": ["climbed"], "loob": 1}, {"flags": ["wary"]}, {"flags": ["called_out"], "banner": "Your voice echoes. Something above answers."}], seconds=10, default=1),
    narr("Halfway up the iron stairs he sees it: a shape folded into the corner of the landing, too many joints, two red eyes opening in the dark.", **{"if": "climbed"}),
    think("Back down. Back down. Back down.", **{"if": "climbed"}),
    think("Whatever comes, it comes at me, not at my back.", **{"if": "wary"}),
    narr("'Renzo?' says a voice from the fire escape, in Lola's own cadence. The lamps die one by one.", **{"if": "called_out"}),
]

S["alley_ambush"] = [
    narr("Rusted iron screams overhead. Something heavy lands in the dark.", layout="right-split", panel="ep1_13_aswang_fire_escape", flash=True, shake=True, sfx="KRAAASH!"),
    say("renzo", "Diyos ko... the lamps, they all went out. And that thing... it was on the fire escape the whole time.", layout="left-split", panel="ep1_14_renzo_shock", shake=True),
    think("All I've got is a balisong... Walang atrasan. Walang atrasan. Say it like you mean it, Renzo.", layout="left-split", panel="ep1_15_renzo_cornered", shake=True),
]

S["after_fight_alley"] = [
    narr("The smoke is gone. It leaves one thing on the asphalt: a clamp of black alloy no bigger than a thumb, still blinking.", layout="banner", panel="ep1_14_renzo_shock"),
    think("A telemetry tag. Clamped to its ear. Nobody tags a monster they haven't been watching."),
    choice("tag", "The tag is blinking green.", ["Take it (evidence, but it may be tracking you)", "Crush it under your heel"],
           [{"flags": ["has_tag"], "loob": 1}, {"flags": ["tag_crushed"]}]),
    think("It pings once against my palm. A green light. I may have just told someone exactly where I am.", **{"if": "has_tag"}),
    narr("The tag dies with a small, offended chirp.", **{"if": "tag_crushed"}),
    think("Whoever was listening just lost the signal. They'll want to know why.", **{"if": "tag_crushed"}),
    narr("The watch is burning through the cloth. Its hands run backward through a minute that already happened."),
    think("How long was I out there? Four minutes? Forty?"),
]

S["gate_ram"] = [
    narr("Headlights. An engine screaming straight down the alley. The chained gate behind Renzo is the only way out, and it is about to stop being a gate.", layout="banner", panel="ep1_19_gate_brace", shake=True, sfx="SKREEEE!",
         qte={"id": "gate_brace", "prompt": "BRACE!", "seconds": 1.8, "level": "free", "lesson": ""}),
    narr("The gate comes apart.", layout="banner", panel="ep1_18_dante_krash", flash=True, shake=True, sfx="KRASH!"),
    say("dante", "RENZO! Get in the van! Lola's seal is broken. That thing isn't supposed to be out of the Veil!"),
    say("renzo", "Dante?! You... you crashed through the gate. Of course you did."),
    say("dante", "Door's open. Decide fast. I cannot make small talk with Aevum two streets behind me."),
    choice("van", "A van with a stranger, or the Honda in the flood?", ["Get in the van", "Run for it on the Honda"],
           [{"trust": 1, "flags": ["in_van"]}, {"trust": -1, "flags": ["ran_honda"], "banner": "Dante follows, furious"}], seconds=8),
    narr("The Honda stalls in the flood two blocks on. The van rolls up alongside, wipers going.", **{"if": "ran_honda"}),
    say("dante", "Told you.", **{"if": "ran_honda"}),
]

S["van_talk"] = [
    narr("The van smells of diesel, gin and wet dog. Dante drives like the road owes him money.", layout="banner", panel="ep1_16_dante_wheel"),
    say("dante", "Name's Dante. I fixed your grandfather's bicycle in 1996 and he never paid me. He paid me in watches, and I never fixed those either."),
    say("renzo", "You knew Lolo."),
    say("dante", "Knew him. Drank with him. He was a bad drinker and a worse liar, and the best watchmaker in Manila."),
    choice("van1", "Three questions. One ride.", ["What was that thing?", "What does Lola's seal do?", "Why should I trust you?"],
           [{"flags": ["q_thing"]}, {"flags": ["q_seal"], "loob": 1}, {"flags": ["q_trust"]}]),
    say("dante", "Aswang. A real one. Old, patient, not hungry for anything you would call food. And someone fine-tuned it to find you.", **{"if": "q_thing"}),
    think("Fine-tuned.", **{"if": "q_thing"}),
    say("dante", "Your Lola keeps a door shut. Not a door door. A door in the city. The watch is the lock. Every time it ticks backward, the lock holds.", **{"if": "q_seal"}),
    say("renzo", "And when it ticks forward?", **{"if": "q_seal"}),
    say("dante", "Then the door opens.", **{"if": "q_seal"}),
    narr("A long beat. The wipers. The rain.", **{"if": "q_seal"}),
    say("dante", "It has not ticked forward in twenty-six years.", **{"if": "q_seal"}),
    say("dante", "You shouldn't. That is the first smart thing you have said all night.", **{"if": "q_trust"}),
    say("dante", "But I lit the lamp when your Lolo went out that night, and I am the one who kept the river off your Lola's doorstep since. I am not asking you to trust me. I am asking you to stay in the van.", **{"if": "q_trust"}),
    narr("Rain drums the roof. Somewhere behind them a siren with no flashing light goes quiet."),
    say("dante", "Hands. Let me see the watch."),
    choice("van2", "He's asking for the one thing I was told never to open.", ["Show him the watch", "Keep it in your pocket"],
           [{"trust": 1, "flags": ["watch_shown"]}, {"trust": -1, "loob": 1, "flags": ["watch_hidden"]}], seconds=9, default=1),
    say("dante", "Balete wood and cold iron. She gave it to you.", **{"if": "watch_shown"}),
    narr("He does not touch it. He looks at it the way you look at an old photograph.", **{"if": "watch_shown"}),
    say("dante", "Fine. Keep it. But if it starts to sing, you will show me.", **{"if": "watch_hidden"}),
    say("dante", "So. Where do we go?"),
    choice("van_big", "Dante's workshop, or back to Lola?", ["Tondo: Dante's workshop (safe, away from Quiapo)", "Back to Quiapo: Lola is alone"],
           [{"flags": ["tondo"], "trust": 1}, {"flags": ["wants_quiapo"], "loob": 1, "trust": -1}], seconds=15),
    say("dante", "Not yet. If Aevum is in Quiapo they are already inside the shop, and walking in tonight gets you both killed. Tondo. Then we plan.", **{"if": "wants_quiapo"}),
    think("He is right. I hate that he is right.", **{"if": "wants_quiapo"}),
    say("dante", "Good call. Tondo it is.", **{"if": "tondo"}),
]

S["after_fight"] = [
    narr("The van is quiet. Renzo takes the watch out. It is spinning backward at three times its pace, and the rain on the windshield stops falling, and begins to run upward.", layout="banner", panel="ep1_09_watch_backward", flash=True),
    say("dante", "...Kid. I saw that. The rain fell upward for three seconds, and your pocket was glowing. You rewound something."),
    say("renzo", "It does that. It has been doing that all day."),
    say("dante", "No. It does not. Hold on to that thing, Renzo. It has just done what it was built to do, and the people who built it are very much alive."),
    narr("END OF ACT 2: THE ALLEY."),
]

# ------------------------------------------------------------------------------------------------ ACT 3
S["safehouse_arrival"] = [
    narr("Tondo. A chop shop under a zinc roof, rain on the sheets like gravel. The van stops, and the shop's one working fluorescent tube remembers to turn on.", layout="banner", panel="ep1_20_tondo_arrival", shake=True),
    say("dante", "Sit on the crate. Not that one, that one is a bomb. Joke. Mostly.", layout="left-split", panel="ep1_21_dante_gin"),
    say("renzo", "My hands will not stop."),
    say("dante", "They stop when you give them something to do. Hold this."),
    narr("A torque wrench, heavier than it looks. It does help."),
    choice("safe1", "Dante is holding a bottle of gin and a first-aid kit.", ["Let Dante clean the cuts", "Do it yourself", "Ask about Lola first"],
           [{"trust": 1, "flags": ["gin"]}, {"flags": ["selfcare"]}, {"loob": 1, "flags": ["asked_lola"]}], seconds=12),
    say("dante", "Don't pour it on the cuts unless you want to pass out. Drink it. Then I pour it. The claws carry corpse-rot.", **{"if": "gin"}),
    think("It tastes like a car battery. It helps. I hate that it helps.", **{"if": "gin"}),
    say("dante", "Pride. Your Lolo had it too. Use the clean side of the cloth, not the rag.", **{"if": "selfcare"}),
    say("dante", "Lola is alive. Alive and loud, if I know her. We will find out where she is. First you need to be a person who can walk through a door.", **{"if": "asked_lola"}),
    narr("Dante spreads a map of Quiapo across the hood of a motorcycle. Red crosses. Black vans. Chevrons in circles."),
    say("dante", "Before I explain anything: open the cloth. Lola told you the invoice was in the cloth."),
]

S["envelope_open"] = [
    narr("The watch lies on the bench between them. The black cloth it came wrapped in is still folded in Renzo's pocket.", layout="banner", panel="ep1_22_watch_gears"),
    think("Do not open it on the way. I have gotten as far as 'the way' is going to let me."),
    narr("Between the weave and the lining: a traced invoice for Gat. Dizon, Bodega 9, signed in a hand that is not a hand. And a thicker envelope, wax-sealed with a chevron inside a circle."),
    say("dante", "That is not the church's seal. That is Aevum's."),
    think("The sacristan's envelope. The one he slid across the stone this morning. I put it in my pocket and never opened it."),
    choice("env1", "A wax seal with Aevum's chevron.", ["Open the sealed envelope", "Hand it to Dante unopened"],
           [{"flags": ["opened_env"], "loob": 1}, {"flags": ["gave_env"], "trust": 1}], seconds=12),
    narr("A lease notice on Aevum letterhead: 'Lot 14, Carriedo Street (Reyes Watch Repair & Herbs) is subject to acquisition under Resolution 417. Occupant: Rosa Reyes. Basis: custodianship of Item 4-17-A.'", **{"if": "opened_env"}),
    think("Item 4-17-A. Four seventeen.", **{"if": "opened_env"}),
    say("dante", "That is you. That is the watch. That is what this whole city has been counting toward.", **{"if": "opened_env"}),
    narr("Dante breaks the seal with his thumbnail, reads, and goes the color of old plaster.", **{"if": "gave_env"}),
    say("dante", "Item 4-17-A. Custodianship. They are not after Lola, Renzo. They are after what she is holding.", **{"if": "gave_env"}),
    narr("Folded behind the notice: a small, creased photograph. Lola at thirty, holding a baby who is not Renzo's father. On the back, in Lolo's hand: 'Siya ang susunod.' She is the next."),
    say("renzo", "Whose baby?"),
    say("dante", "I do not know. I swear on every wrench in this shop, I do not know."),
    think("He is telling the truth. That is what frightens me."),
    narr("At the far end of the bench, the scanner clears its throat in static."),
]

S["hound_intro"] = [
    narr("The shop lights die at once. On the skylight, one by one, four metal feet touch the zinc.", layout="banner", panel="ep1_23_aevum_chatter", shake=True),
    say("dante", "You kept the tag?!", **{"if": "has_tag"}),
    say("dante", "They found us anyway. Aevum does not give up a signal; it only changes the dog.", **{"unless": "has_tag"}),
    narr("The skylight shatters. Something with a red lens drops through it and lands on the bench, scattering maps, wrenches and the watch."),
    say("dante", "Hound! Behind me, kid, I have to hold the breaker or the whole block goes dark and every van in Tondo hears it!"),
    think("He cannot leave the breaker. It's me. It's just me and the watch."),
    narr("The watch, in Renzo's fist, begins to count backward before he asks it to."),
]

S["hound_after"] = [
    narr("The hound's lens cracks, spits sparks, and goes dark. The safehouse lights stutter back on.", layout="banner", panel="ep1_21_dante_gin"),
    say("dante", "I felt that. The whole shop went cold for a second, and then everything the hound did to us unwound itself. That is the watch?"),
    say("renzo", "That is the watch."),
    say("dante", "Then it is awake, and so is everyone who has been waiting twenty-six years for it to be."),
    think("He says it like a diagnosis."),
]

S["act3_big"] = [
    say("dante", "Quiapo is two choices. Now, with a wrench, a watch and a lot of nerve. Or an hour with me, a plan, and a very bad map.", layout="banner", panel="ep1_23_aevum_chatter"),
    choice("act3", "Lola, or a plan?", ["Go to Quiapo now", "Plan with Dante first (an hour)"],
           [{"flags": ["rush"], "loob": 1, "trust": -1}, {"flags": ["plan"], "trust": 1, "spend": 60}], seconds=15),
    say("dante", "Then take this. A taser. It is what I have. Don't let the watch tell you what to do.", **{"if": "rush"}),
    say("dante", "Good. Their transport leaves for Taguig at midnight. We catch the van at the Bonifacio crossing, with the watch and a plan.", **{"if": "plan"}),
    narr("The watch jumps in Renzo's hand."),
]


# ------------------------------------------------------------------------------------------------ MORE ACT 1
S["domeng_stall"] = [
    narr("Mang Domeng's candle stall, behind the church. Wax drips in the rain faster than he can sell it.", layout="banner", panel="ep1_07_mang_domeng"),
    say("domeng", "Renzo! You're soaked. Come, come under the tarp. The saints can spare a minute."),
    say("renzo", "I can't stay, Mang Domeng. I have a parcel for the undercroft by noon."),
    say("domeng", "Then a minute, only a minute. Forty years I have lit candles for people who wanted a different life. You know what they all ask for?"),
    choice("domeng1", "He is waiting for me to guess.", ["Money", "Safety", "More time"],
           [{"flags": ["domeng_money"]}, {"flags": ["domeng_safety"]}, {"flags": ["domeng_time"], "loob": 1}], seconds=10, default=2),
    say("domeng", "Money, everyone says. But no. Money is what they ask for out loud.", **{"if": "domeng_money"}),
    say("domeng", "Safety, yes. That is what the old ones ask for. The young ones are braver. Or dumber.", **{"if": "domeng_safety"}),
    say("domeng", "Time. Yes. You have your Lolo's face when you say it. He asked for it every week, until the week he stopped asking.", **{"if": "domeng_time"}),
    say("domeng", "Your Lola paid for forty candles last Thursday. In advance. She has never done that."),
    think("Forty candles. In advance. Someone who plans to be gone."),
    say("domeng", "Take one. For the road. It is only a candle, but sometimes that is a lot."),
    narr("A thin white candle, still warm from the mold. Renzo tucks it into the strap of his helmet.", fx={"flags": ["has_candle"]}),
]

S["tow_confrontation"] = [
    narr("Noon. The bells ring twelve, a heartbeat late, and a tow truck with no plates backs up to the shop's curb.", layout="banner", panel="ep1_06_honda_ride", shake=True),
    narr("Two men in matching rain jackets: Valdez's cousins. One of them is already hooking the Honda's front wheel.", flash=False),
    say("valdez", "Reyes. Eleven hundred pesos short on the third notice, and a bike that was never yours to begin with. I would call it a courtesy, but I don't."),
    say("renzo", "I paid what I could. I will have the rest tomorrow."),
    say("valdez", "Tomorrow is a word for people who can afford it."),
    choice("tow", "They have the Honda hooked. I have a balisong and a watch.", ["Fight for the bike", "Pay what you have and beg", "Let it go"],
           [{"flags": ["fight_goons"], "loob": 1, "trust": 0}, {"money": -300, "utang": 1, "flags": ["begged"], "banner": "P300 and your pride. +1 utang"}, {"flags": ["let_go_bike"], "utang": 2, "banner": "The Honda is gone. +2 utang"}], seconds=12, default=2),
    narr("Renzo steps off the curb before the thought finishes.", **{"if": "fight_goons"}),
    say("valdez", "Ay, ay. A hero. Boys, teach him what a notice means.", **{"if": "fight_goons"}),
    say("valdez", "The courtesy of a rule is that I do not enjoy it. Take the money and be quiet.", **{"if": "begged"}),
    narr("The tow truck pulls away with the Honda's taillight blinking through the rain.", **{"unless": "fight_goons"}),
    think("Another debt. Another number on the book. Lola will count it before I say a word.", **{"unless": "fight_goons"}),
]

S["tow_after"] = [
    narr("The cousins limp away, one holding the other up. The Honda hangs half off its hook, and the tow truck's engine idles, undecided.", layout="banner", panel="ep1_06_honda_ride"),
    say("valdez", "...You are more trouble than the shop is worth, Reyes. Keep the bike. This once. The notice stays."),
    think("This once. He means it. He also means the next time won't be a courtesy."),
    narr("Renzo unhooks the wheel himself, hands shaking, knuckles split.", fx={"flags": ["kept_honda"], "utang": -1, "banner": "You kept the Honda. -1 utang"}),
]

# ------------------------------------------------------------------------------------------------ MORE ACT 2
S["van_chase_intro"] = [
    narr("The van tears out of the alley with a crack of splintered chain. Behind them, headlights without a plate, doing sixty in a thirty zone.", layout="banner", panel="ep1_17_dante_approach", shake=True),
    say("dante", "Aevum! Two vans! Kid, I drive, you navigate. Left, always left. The flood is on our side tonight."),
    think("The Avenida is a river. We are not driving on it. We are driving through it."),
    say("dante", "Tell me when the lanes open. Steer us through the traffic. If I hit a jeepney, your Lolo comes back to haunt us both."),
]

S["bodega_nine"] = [
    narr("Bodega 9's door is not locked. It is not even closed. The blue stripe has been painted over with a thin coat of grey, and the bodega behind it breathes out cold.", layout="banner", panel="ep1_08_church_undercroft"),
    think("Gat. Dizon. Nobody comes to a door like this to sign for a parcel."),
    narr("A single bulb burns over a workbench. On it, a row of stopped clocks and a ledger. At the bench, in a chair that fits him too well, sits a man in a good suit. He has been dead for a while."),
    think("Dizon. Whoever delivered this watch to him wouldn't have been bringing it for a signature."),
    choice("bodega", "The dead man's hand is closed around something.", ["Open his hand", "Read the ledger", "Back out and call it in"],
           [{"flags": ["dizon_hand"], "loob": 1}, {"flags": ["dizon_ledger"]}, {"flags": ["dizon_left"], "trust": 0}], seconds=12, default=1),
    narr("In his palm: a brass key stamped with a number, 4-17, and a tiny watchmaker's screwdriver, worn bright.", **{"if": "dizon_hand"}),
    think("A watchmaker's screwdriver. Dizon was one of us.", **{"if": "dizon_hand"}),
    narr("The ledger lists names and dates, back to 1898. Every entry ends the same way: 'Delivered. Awaiting the heir.' The last line is in fresh ink: 'Reyes, R. Tonight.'", **{"if": "dizon_ledger"}),
    think("Heir. He was waiting for me. He was waiting for me, and something killed him for it.", **{"if": "dizon_ledger"}),
    think("I'm not going to be the next name in this ledger. Not like this.", **{"if": "dizon_left"}),
    narr("Behind Renzo, the alley's last streetlight goes out."),
]

# ------------------------------------------------------------------------------------------------ MORE ACT 3
S["lola_message"] = [
    narr("Dante's scanner coughs, and a voice that is not Aevum's comes through the static: an old woman, calm as a tea kettle.", layout="banner", panel="ep1_24_workshop_raid"),
    say("lola", "Renzo. If you are hearing this, the hound found you, or the watch did. Either way, you are breathing, and that is enough."),
    say("lola", "I recorded this on Dante's old tape. Do not be angry with him. I made him promise to wait until you were in his van."),
    say("renzo", "You knew he would find me."),
    say("dante", "I knew she would call it. I just did not think it would be this soon."),
    say("lola", "Ask me to apologise, and I will not. Ask me why, and I will tell you when I can look at you. There is a place on the Pasig where the river tastes of rust. Go there when this is over."),
    choice("lola_msg", "Her voice is calm. That is what makes it hard.", ["Say it out loud: 'I'm coming, 'La.'", "Say nothing. Listen to her breathe.", "Ask Dante to stop the tape"],
           [{"flags": ["msg_vow"], "loob": 1}, {"flags": ["msg_listen"], "trust": 1}, {"flags": ["msg_stop"], "trust": -1}], seconds=12),
    say("lola", "Good. Keep the watch close. It does not lie. It only counts.", **{"if": "msg_vow"}),
    narr("In the static behind her, a door opens and a man says her name.", **{"if": "msg_listen"}),
    narr("Dante stops it, wordless. Rain on the zinc. The tape's last two seconds hang in the air like a held breath.", **{"if": "msg_stop"}),
    say("lola", "Tell Renzo I put the third drawer on the left back in order. He will understand when he is older. No. When he is ready.", **{"unless": "msg_stop"}),
]

S["agent_offer"] = [
    narr("The scanner clears its throat again. This time the voice is smooth, practised, and very polite.", layout="banner", panel="ep1_23_aevum_chatter"),
    say("agent", "Mr. Reyes. I apologise for the hound. It was a clumsy introduction. My name is Tolentino, Aevum Filipinas, Custodianship division."),
    say("renzo", "You took my grandmother."),
    say("agent", "We invited her. She declined. Eleven times. We are good at patience; we are less good at being told no."),
    say("agent", "Give us the watch. We will return Mrs. Reyes to her shop, forgive the lease, and settle the Valdez debt. Tonight."),
    think("Everything I have been counting toward since six this morning, offered in one sentence."),
    choice("agent", "The deal is real. That is what is wrong with it.", ["Refuse flatly", "Stall: ask for proof she is alive", "Ask what the watch actually does"],
           [{"flags": ["agent_refuse"], "loob": 1, "trust": 1}, {"flags": ["agent_stall"], "spend": 15}, {"flags": ["agent_asked"], "loob": 0}], seconds=15, default=1),
    say("agent", "A pity. We will not ask a third time.", **{"if": "agent_refuse"}),
    say("agent", "Proof. Of course. Mrs. Reyes, would you say something?", **{"if": "agent_stall"}),
    say("lola", "Do not give them the watch.", **{"if": "agent_stall"}),
    say("agent", "She is stubborn. That is a family trait.", **{"if": "agent_stall"}),
    say("agent", "It does what it was built to do: it keeps a door shut. We would like to open it. There is a great deal of power on the other side, Mr. Reyes, and a great deal of money.", **{"if": "agent_asked"}),
    say("dante", "He's reading from a pamphlet. Hang up.", **{"if": "agent_asked"}),
    narr("The line goes to static, and then, softly, to a ticking."),
]


S["dante_story"] = [
    narr("Dante pours two cups of something that is not tea and hands one over without asking.", layout="banner", panel="ep1_21_dante_gin"),
    say("dante", "You want the night of the flood? The real one, not the one your Lola tells?"),
    choice("dstory", "He's offering the real one.", ["Yes. All of it", "Not tonight", "Only what matters to Lola"],
           [{"flags": ["ds_all"], "trust": 1}, {"flags": ["ds_not"]}, {"flags": ["ds_lola"], "loob": 1}], seconds=10),
    say("dante", "June third, 1998. The river rose at three. By four it was in your Lolo's shop, up past the counter. I was carrying jars to the second floor when I saw him.", **{"unless": "ds_not"}),
    say("dante", "He was standing in the middle of the flood with the watch in both hands. Calm. Like a man at a christening.", **{"unless": "ds_not"}),
    say("dante", "The hands went backward. And the water went with them. Down the stairs, out the door, back into the street, like a rug being pulled by a very polite giant.", **{"unless": "ds_not"}),
    say("renzo", "That's what it does.", **{"unless": "ds_not"}),
    say("dante", "That is what it did. And it took four minutes and seventeen seconds, Renzo, and your Lolo aged ten years in them. I counted.", **{"unless": "ds_not"}),
    think("4:17. Not a time of day. A length of time. Four minutes and seventeen seconds.", **{"unless": "ds_not"}),
    say("dante", "He never touched it again. Never told her why. I never told her either. The day she found out I knew, she handed me the van keys and said: 'when the boy needs you.'", **{"if": "ds_all"}),
    say("dante", "Lola will want to tell you the rest. She should be the one.", **{"if": "ds_lola"}),
    say("dante", "Fair enough. Some stories wait for better light.", **{"if": "ds_not"}),
    narr("He drinks, and the shop's one working tube hums over the silence between them."),
]

S["tiyanak_intro"] = [
    narr("Dante locks the safehouse door and kills the lamp. Outside, somewhere in the drainage ditch, a baby is crying.", layout="banner", panel="ep1_20_tondo_arrival"),
    say("dante", "Don't. Don't follow it. We are in Tondo, kid. A baby crying in a ditch at night is not a baby."),
    think("It sounds exactly like a baby. That is the problem."),
    choice("tiyanak", "The crying comes in short, wet waves.", ["Follow the sound", "Throw a stone at the ditch", "Stay inside and wait"],
           [{"flags": ["tiy_follow"], "loob": 1}, {"flags": ["tiy_stone"]}, {"flags": ["tiy_wait"], "trust": 1}], seconds=10, default=2),
    narr("The sound leads to a drain cover warm as skin. The crying stops when he steps on it.", **{"if": "tiy_follow"}),
    narr("The stone clanks down the ditch. The crying pauses, considers, and begins again, closer.", **{"if": "tiy_stone"}),
    narr("It does not stop. It comes in under the shutter, a wet little scrape.", **{"if": "tiy_wait"}),
    say("dante", "Tiyanak. A baby that was never born, or never named. It learns your sister's voice and wears it. Do not listen to the words.", **{"unless": "tiy_follow"}),
    think("It has Lola's voice. It's saying, 'Anak, help me.'"),
]

S["tiyanak_after"] = [
    narr("Dante exhales, finally, and sets down the wrench he had not realised he was holding.", layout="banner", panel="ep1_21_dante_gin"),
    say("dante", "That is the third one this month. Something is feeding them, or something is calling them. I would like not to know which."),
    think("It had Lola's voice. It said 'Anak.' I'm going to hear that for a long time."),
]


S["baker_return"] = [
    narr("The baker's apprentice peeks out from behind the half-open door, flour and fear in equal measure, a paper bag held out in front of him like a shield.", layout="banner", panel="ep1_12_alley_delivery"),
    say("baker", "Sir? Sir, is it gone? I saw the light. I saw the smoke. I saw you."),
    say("renzo", "It's gone. What's your name?"),
    say("baker", "Paolo. I... I brought bread. It's what we have. The bins are empty; the thing tore them open last week and the owner blames me."),
    choice("paolo", "He is shaking, and he came back anyway.", ["Take the bread and thank him", "Give him Mang Domeng's candle", "Tell him to go home and lock the door"],
           [{"flags": ["paolo_bread"], "trust": 0}, {"flags": ["paolo_candle"], "loob": 0, "banner": "You gave away the candle. Someone needed it more"}, {"flags": ["paolo_home"], "trust": 0}], seconds=10, default=0),
    say("baker", "It's still warm! Pandesal, three hours old. Please eat.", **{"if": "paolo_bread"}),
    think("It is the best thing I have eaten all day, and I have eaten nothing all day.", **{"if": "paolo_bread"}),
    say("baker", "A candle? From Mang Domeng? ...Thank you. My mother lights one every night. We ran out on Tuesday.", **{"if": "paolo_candle"}),
    say("baker", "Yes, sir. Lock it. Three locks. I'll ask the owner for a fourth.", **{"if": "paolo_home"}),
    narr("Paolo disappears behind the door. The bolts slide home, one, two, three. Four."),
]

S["dante_tips"] = [
    narr("The van slows at a red light that has not changed in a decade. Dante drums the wheel.", layout="banner", panel="ep1_16_dante_wheel"),
    say("dante", "That thing nearly had you. You were late on the first one. I saw. You flinched."),
    say("renzo", "It was fast."),
    say("dante", "Everything is fast when you stare at the claws. Look at the circle. Tap when it glows."),
    choice("tips", "A lesson from a mechanic who hasn't been in a fight in twenty years.", ["Ask for the lesson", "Say you've got it", "Ask why he knows"],
           [{"flags": ["tips_lesson"]}, {"flags": ["tips_skip"]}, {"flags": ["tips_why"], "trust": 1}], seconds=10),
    say("dante", "Three rules. One: you cannot dodge what you are watching, so watch the ring. Two: guard before the big ones, and the numbers on the claw card tell you which are big. Three: a perfect parry is worth ten heals. It charges the watch.", **{"if": "tips_lesson"}),
    say("dante", "Good. Then you can teach me.", **{"if": "tips_skip"}),
    say("dante", "Because I used to run bodyguard for a man who would not stop buying cursed furniture. Do not ask what was in the chair.", **{"if": "tips_why"}),
    narr("The light turns green. Neither of them says anything for a block."),
]

# Act 3 keeps the original briefing and raid lines (from the Episode 1 script) between the new scenes.
epi = json.load(open(os.path.join(DATA, "episode1.json"), encoding="utf8"))
tondo = copy.deepcopy(epi["scenes"]["tondo_safehouse"])
S["aevum_raid"] = tondo[2:]  # from "What was that thing?" to "Lola."

json.dump({"_note": "Generated by tools/build_episode1_extra.py. Edit the generator, not this file.", "scenes": S}, open(os.path.join(DATA, "episode1_extra.json"), "w"), indent=1, ensure_ascii=False)

# ------------------------------------------------------------------------------------------------ FLOW
def sc(id, goal, **k):
    d = {"type": "scene", "id": id, "goal": goal}
    d.update(k)
    return d


FLOW = {"acts": [
    {"number": 1, "title": "4:17", "beats": [
        {"type": "previously"},
        {"type": "act_card"},
        sc("stakes", "Learn what is at stake: the Honda, the shop, noon.", action="note"),
        sc("shop_morning", "Learn the watch exists, and catch it when it falls (first timing-ring lesson)."),
        sc("bench", "Find out what Lola is hiding by choosing what to investigate."),
        sc("lola_tea", "Get Lola to open up, or let her keep her silence."),
        sc("board_intro", "Understand the day's jobs and the debt.", action="note"),
        {"type": "board", "goal": "Choose the day's work: time against money against risk."},
        sc("step_out", "Start the Honda (second timing-ring lesson)."),
        {"type": "run", "id": "morning", "goal": "Ride to the jobs through the rain.", "seconds": 22, "spawn": [1.1, 1.8], "route": "QUIAPO  >  THE JOBS", "hazards": ["pothole", "puddle"]},
        sc("job_avenida", "Deliver forty bolts of katsa and decide how hard to haggle.", **{"if": "job_avenida"}),
        sc("job_pandacan", "Collect the compressor part and decide whether to open the walk-in.", **{"if": "job_pandacan"}),
        {"type": "run", "id": "church", "goal": "Reach the church before the noon flood.", "seconds": 20, "spawn": [0.9, 1.5], "route": "THE JOBS  >  QUIAPO CHURCH", "hazards": ["pothole", "puddle", "jeepney"]},
        sc("church_arrival", "Arrive at the church with the parcel.", action="note"),
        sc("domeng_stall", "Learn what Mang Domeng knows by answering him honestly."),
        sc("envelope", "Deliver the parcel without letting the sacristan hear the watch."),
        {"type": "settle", "goal": "Noon: pay the Honda debt, or lose the bike."},
        sc("tow_confrontation", "Decide how to meet Valdez's tow truck.", **{"if": "honda_towed"}),
        {"type": "fight", "enemy": "collector_goon", "episode": 1, "goal": "Fight Valdez's cousins for the bike.", "if": "fight_goons"},
        sc("tow_after", "Keep the bike, and see what it cost.", action="note", **{"if": "fight_goons"}),
        {"type": "run", "id": "noon", "goal": "Ride home from the church.", "seconds": 20, "spawn": [0.9, 1.5], "route": "QUIAPO CHURCH  >  THE SHOP", "hazards": ["pothole", "puddle", "jeepney"]},
        sc("lola_silence", "Decide whether to press Lola about the watch."),
        sc("lola_pressed", "Hear what pressing Lola costs.", action="note", **{"if": "pressed_lola"}),
        sc("lola_let_go", "Let it go and see what that costs.", action="note", **{"unless": "pressed_lola"}),
        sc("dante_call", "Take a stranger's warning about lit streets.", action="note"),
        sc("dusk_choice", "Choose the road to Bodega 9: the shortcut or the lit way."),
        sc("act1_hook", "Take the shortcut into the alley.", action="note"),
    ]},
    {"number": 2, "title": "The Alley", "beats": [
        {"type": "act_card"},
        sc("alley_intro", "Reach Bodega 9 and read the invoice.", action="note"),
        sc("alley_search", "Find the right door and decide how to meet what is waiting."),
        sc("alley_ambush", "Survive the ambush.", action="fight"),
        {"type": "fight", "enemy": "aswang", "episode": 1, "goal": "Survive the Aswang (parry tutorial, the watch awakens)."},
        sc("after_fight_alley", "Decide what to do with the telemetry tag."),
        sc("baker_return", "Decide what to do with a stranger's thanks."),
        sc("bodega_nine", "Find out what happened to Dizon, and what you want to know."),
        sc("gate_ram", "Brace for the gate ram, then choose the van or the Honda."),
        sc("van_chase_intro", "Steer the van through the flood.", action="fight"),
        {"type": "run", "id": "van", "goal": "Steer the van through the flood with Aevum behind you.", "seconds": 30, "spawn": [0.7, 1.2], "route": "THE ALLEY  >  TONDO", "hazards": ["jeepney", "puddle", "pothole"]},
        sc("van_talk", "Learn what Dante knows, and decide whether to trust him."),
        sc("dante_tips", "Take a lesson from Dante about the ring, or say you have got it."),
        sc("after_fight", "Dante sees the rewind.", action="note"),
    ]},
    {"number": 3, "title": "The Envelope", "beats": [
        {"type": "act_card"},
        sc("safehouse_arrival", "Steady your hands and choose how to be helped."),
        sc("dante_story", "Hear Dante's night of the flood, or decide you are not ready."),
        sc("envelope_open", "Open the sealed envelope, or hand it over."),
        sc("aevum_raid", "Hear what Aevum is, and what has happened to Lola.", action="note"),
        sc("lola_message", "Hear Lola's message, and answer it."),
        sc("hound_intro", "The Aevum hound breaks in.", action="fight"),
        {"type": "fight", "enemy": "aevum_hound", "episode": 1, "goal": "Hold off the hound with the awakened watch."},
        sc("hound_after", "Absorb what the watch did.", action="note"),
        sc("agent_offer", "Answer Aevum's offer for the watch."),
        sc("tiyanak_intro", "Decide how to meet the crying in the ditch.", action="fight"),
        {"type": "fight", "enemy": "tiyanak", "episode": 1, "goal": "Survive the tiyanak with the awakened watch."},
        sc("tiyanak_after", "Absorb what Tondo is becoming.", action="note"),
        sc("act3_big", "Choose: Lola now, or a plan."),
        sc("cliffhanger", "The watch stops on a time that has not happened yet.", action="note"),
        {"type": "end"},
    ]},
]}
json.dump(FLOW, open(os.path.join(DATA, "episode1_flow.json"), "w"), indent=1)
print("scenes:", len(S), "steps:", sum(len(v) for v in S.values()))
