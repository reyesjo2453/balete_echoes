"""Builds Episode 1, "Ang Lumang Orasan": godot/data/episode1.json (every scene) and episode1_flow.json (the beats).

Run:  python3 tools/build_episode1.py
This file is the script. Edit it, not the JSON. Canon lives in docs/STORY.md.

Scenes are lists of steps:
  say(who, text)   spoken aloud: dark bar, portrait, name tag
  think(text)      Teo's inner voice: violet bar (think_as(who, text) for anyone else)
  narr(text)       the story itself: yellow caption box, no portrait
Optional keys on any step: panel, layout, flash, shake, sfx, `if` / `unless` (flag names), fx (effects).
choice(id, prompt, options, effects, seconds=0): seconds 0 means untimed. Timed only when the scene is violent.
qte(...): a timing ring inside a story beat. `ok` and `miss` are effects; the flags <id>_ok / <id>_miss are set.

Effects: flags, loob (resolve), bond {who: n}, utang (borrowed time), injury (HP lost at the next fight),
remember {who, what} ("<who> will remember that"), banner.
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "godot", "data")

# Pixel dialogue portraits (godot/assets/portraits_px/<id>.png). Young Kardo and young Ising (1998) have none yet:
# the grown-up busts are 28 years too old.
PORT = {w: "portrait_" + w for w in [
    "teo", "ising", "kardo", "pido", "obet", "domeng", "nena", "berto", "isko", "rudy", "nonoy", "andoy",
    "tess", "celso", "guard", "benitez"]}
NAME = {
    "teo": "Teo", "ising": "Lola Ising", "pido": "Lolo Pido", "kardo": "Kardo", "young_kardo": "Kardo",
    "young_ising": "Ising", "obet": "Kapitan Obet", "domeng": "Mang Domeng", "nena": "Aling Nena",
    "berto": "Mang Berto", "junjun": "Jun-jun", "benitez": "Atty. Benitez", "ambo": "Mang Ambo",
    "villacorta": "Gregorio Villacorta", "celeste": "Celeste Villacorta", "boy": "Boy on the roof",
    "tape": "Lola Ising (tape)", "isko": "Mang Isko", "rudy": "Rudy", "nonoy": "Nonoy", "andoy": "Mang Andoy", "tess": "Aling Tess", "celso": "Tanod Celso", "guard": "Hiraya guard",
}


def say(who, text, **k):
    d = {"kind": "say", "speaker": NAME[who], "text": text}
    if who in PORT:
        d["portrait"] = PORT[who]
    if who == "tape":
        d["portrait"] = PORT["ising"]
    d.update(k)
    return d


def think(text, **k):
    return think_as("teo", text, **k)


def think_as(who, text, **k):
    d = {"kind": "think", "speaker": NAME[who], "text": text}
    if who in PORT:
        d["portrait"] = PORT[who]
    d.update(k)
    return d


def narr(text, **k):
    d = {"kind": "narr", "speaker": "", "text": text}
    d.update(k)
    return d


# How Teo (or whoever is choosing) says it. Shown as a small tag on each option, so the player knows the
# feeling behind the words before picking. Tones: angry, calm, cold, defiant, desperate, focused, gentle,
# guilty, quiet, scared, suspicious, warm, worried, resolute.
TONES = {
    "co_kardo": ["worried", "suspicious"],
    "ghost_nod": ["scared", "gentle"],
    "obet": ["desperate", "angry", "quiet"],
    "nonoy": ["gentle", "cold"],
    "cards": ["warm", "angry"],
    "berto": ["gentle", "scared"],
    "big1": ["focused", "worried", "gentle"],
    "door": ["calm", "defiant"],
    "route": ["focused", "gentle", "resolute"],
    "creek": ["defiant", "focused"],
    "ambo": ["gentle", "cold"],
    "tag": ["defiant", "angry"],
    "big2": ["desperate", "angry"],
    "kardo_q": ["suspicious", "quiet", "focused"],
    "morgue1": ["quiet", "angry"],
    "big_moral": ["gentle", "cold", "quiet"],
    "tape_reply": ["resolute", "quiet", "guilty"],
    "big3": ["defiant", "suspicious", "desperate"],
    "vial": ["gentle", "cold"],
    "obet_dawn": ["angry", "resolute", "cold"],
    "photo_q": ["angry", "calm"],
}


def choice(cid, prompt, options, effects, seconds=0, default=0, who="teo", tones=None, **k):
    c = {"id": cid, "options": options, "seconds": seconds, "default": default, "effects": effects}
    tones = tones or TONES.get(cid)
    if tones:
        assert len(tones) == len(options), cid
        c["tones"] = tones
    d = think_as(who, prompt, choice=c)
    d.update(k)
    return d


def qte(cid, text, prompt, seconds, level, lesson="", ok=None, miss=None, **k):
    d = narr(text, qte={"id": cid, "prompt": prompt, "seconds": seconds, "level": level, "lesson": lesson,
                        "ok": ok or {}, "miss": miss or {}})
    d.update(k)
    return d


def when(flag, step):
    step["if"] = flag
    return step


def unless(flag, step):
    step["unless"] = flag
    return step


def remember(who, what):
    return {"who": who, "what": what}


S = {}

# =============================================================================================== COLD OPEN, 1998
S["co_flood"] = [
    narr("Quiapo. 3 June 1998. 3:58 in the morning. The Pasig has climbed four streets inland, and it is still climbing.", layout="banner", panel="ep1_c01_flood_parlor"),
    narr("Punerarya Dimaculangan, Hidalgo Street. The water is waist-deep in the viewing room. Two coffins float, and one of them is knocking from the inside."),
    say("young_kardo", "Mang Pido! I cut the line at the post. You've got no power, but you've got no fire either. That's the best I can do."),
    say("pido", "It's enough, Kardo. Get up the stairs. Take Ising and the baby to the roof."),
    narr("On the landing, Ising holds a girl of three months against her shoulder. She does not move."),
    say("young_ising", "Pido. They're not knocking to get out. They're knocking to be let in."),
    narr("Faces rise in the brown water. Not the dead from the coffins. Older dead. Drowned dead, from every flood this street has ever had, pulled up by something open below the city."),
    say("pido", "Then I'll send them home. Kardo, the stairs. Now."),
    narr("Pido Dimaculangan, sundô of Quiapo, wraps a black panyo around his left wrist, draws the old sundang from under the counter, and steps down into the water."),
]

# The drowned do not stop: two fights, wounds carried, and the second one cannot be won.
S["co_wave"] = [
    narr("The drowned sink. The water does not. Where one face went down, the surface bulges, and two come up.", layout="banner", panel="ep1_c01_flood_parlor", shake=True),
    say("young_kardo", "Mang Pido! The back! They're coming in the back!"),
    narr("Through the kitchen. Through the drain in the floor. Through the gap under the front door. Pido counts eight. Then twelve.", panel="ep1_c01b_drain", move="push"),
    say("pido", "Ising. Whatever you hear, don't come down."),
    say("young_ising", "I wasn't going to."),
    narr("The water climbs the stairs. Third step. Fifth. Kardo is on the seventh with a broom held like a spear, and above him the baby is crying.", panel="ep1_c01c_stairs"),
    say("young_kardo", "If I die on these stairs, tell my Nanay I was wearing clean briefs! She asks every time I leave the house!"),
    say("pido", "Tell her yourself. One step higher."),
    think_as("pido", "Not the watch. Not yet. Not while I can still lift my arm."),
]

S["co_rewind"] = [
    narr("The water is at Pido's chest. The sundang is as heavy as a door. And still they rise.", layout="banner", panel="ep1_c01_flood_parlor", shake=True),
    say("young_kardo", "There's no end to them! Mang Pido, come up, there's no end!"),
    say("pido", "There's an end. It's just not mine to spend."),
    narr("He takes a pocket watch from his shirt. Balete-wood case, no maker's mark. He opens it, and turns the crown backward."),
    narr("The hands run backward. So does the river.", panel="ep1_c02_pido_rewind", flash=True, sfx="TIK."),
    narr("The water slides off the walls. It pours down the stairs it came up, out the door it came in by, back along Hidalgo Street toward the river, like a sheet pulled off a bed.", panel="ep1_c02b_recede", move="pull"),
    say("young_kardo", "...Isa. Dalawa. Tatlo...", panel="ep1_c02c_counting", move="push"),
    narr("Kardo counts out loud, because someone should. He counts to two hundred and fifty-seven. Four minutes and seventeen seconds."),
    narr("When it is over, the parlor is dry. The coffins sit where they should. And the man holding the watch is ten years older than the man who opened it.", panel="ep1_c02d_white"),
    say("young_ising", "Pido. Your hair."),
    say("pido", "It's only hair."),
    choice("co_kardo", "Ten years, gone in four minutes, and he calls it only hair. I can't stop looking at that watch.",
           ["\"What did that cost you?\"", "\"Where did the water go?\""],
           [{"flags": ["co_cost"]}, {"flags": ["co_where"]}], who="young_kardo"),
    when("co_cost", say("pido", "Ten years. It always costs years. The watch keeps the account.")),
    when("co_cost", say("young_kardo", "Whose account?")),
    when("co_cost", say("pido", "Ours. The family's. Every second we borrow, someone in this house pays back.")),
    when("co_where", say("pido", "Where it was owed.")),
    when("co_where", say("young_kardo", "That's not an answer.")),
    when("co_where", say("pido", "No. It's a debt.")),
]

S["co_downriver"] = [
    narr("Two kilometres downriver, in Santa Ana, the water that left Quiapo arrives all at once.", layout="banner", panel="ep1_c03_downriver", shake=True, sfx="WHUMP."),
    narr("A wall of it. Brown, fast, carrying a jeepney roof and a church pew. It takes the riverside houses in a single breath."),
    narr("On one roof that holds, a boy of seventeen in a school uniform is screaming into the dark."),
    say("boy", "TATAY! TATAAAY!"),
    narr("The ID card on his lanyard spins in the wind. VILLACORTA, GREGORIO. Fourth Year, Santa Ana High."),
    narr("Back in Quiapo, at dawn, the stopped clocks on the parlor wall all read 4:17. Nobody winds them again.", panel="ep1_02b_stopped_clocks", music="silence"),
    narr("And at the door, before the sun is fully up, someone knocks. Ising holds the baby a little closer, and does not answer it.", panel="ep1_c02e_street"),
]

# =============================================================================================== ACT 1: LAMAY
# --- Hidalgo Street (data/maps.json "hidalgo"): acted in the map. Positions are [x, z] in metres: x runs along
# the street, z from the shop fronts (0) out across the road toward the camera. The parlor door is at x 13.5.
S["hidalgo_arrive"] = [
    narr("Quiapo. Today. Hidalgo Street at twenty to eleven: five funeral parlors in one block.", layout="banner",
         act=[{"who": "teo", "at": [-0.4, 6.4]}, {"who": "teo", "walk": [3.0, 6.0]}, {"focus": [5.0, 5.0]}]),
    narr("Only one still has its lights on. Punerarya Dimaculangan's neon sign has two dead letters, so it reads PUNE  RYA DIMACU ANGAN. It has read that way since Teo was in grade school.",
         act=[{"focus": [13.5, 3.2]}]),
    think("Second night of Mang Berto's wake. Lola wants the urn full by eleven.", act=[{"focus": [5.0, 5.0]}, {"who": "teo", "face": "right"}]),
]

S["hid_balut"] = [
    narr("Mang Isko has sold balut on this corner for longer than Teo has been alive. His basket is still half full.", layout="banner"),
    say("isko", "Teo! Balut, penoy? For the wake, I'll give you the dead man's discount."),
    say("teo", "Is that cheaper or more expensive?"),
    say("isko", "Depends how he died."),
    narr("He laughs at his own joke, the way he has every night for thirty years."),
    say("isko", "My compadre Andoy had this corner before me. Dropped dead under that balete one fiesta, still holding his basket."),
    say("isko", "Some nights I still hear him. Baluuut. Same voice. I never answer. You never answer when one of them calls your name."),
    think("He's right. You don't answer. You pray, or you walk faster.", fx={"flags": ["heard_isko"]}),
]

S["hid_trike"] = [
    narr("Rudy's tricycle is parked where the hearses park in the daytime. He sleeps in the sidecar between fares.", layout="banner"),
    say("rudy", "Dimaculangan. Your Lola paid me to drive Aling Nena home tonight. Paid me in advance. Your Lola never pays in advance."),
    think("Lola only pays early when she's worried."),
    say("rudy", "Every parlor on this street has had free electricity since Hiraya put up their poles. Every one but yours."),
    say("teo", "Lola says nothing is free."),
    say("rudy", "Your Lola says a lot of things. ...She's usually right, though. Don't tell her I said that. She'll charge me interest."),
]

S["hid_kid"] = [
    narr("Nonoy is ten and should be asleep. He stands very still at the end of the street, staring at the balete.", layout="banner"),
    say("nonoy", "Kuya Teo. There's an old man under the tree. He keeps saying my name."),
    think("There's nobody under the tree. Nobody anyone but me can see."),
    choice("nonoy", "He's waiting for Nonoy to answer.", ["\"Go home, Nonoy. Don't answer him.\"", "\"There's no one there.\""],
           [{"flags": ["nonoy_warned"], "loob": 1}, {"flags": ["nonoy_lied"]}]),
    when("nonoy_warned", say("nonoy", "...Okay.")),
    when("nonoy_warned", narr("He runs, and he doesn't look back, which is exactly the right way to do it.")),
    when("nonoy_lied", say("nonoy", "Then why are you looking at him too?")),
    when("nonoy_lied", think("Ten years old and already better at this than the Titas.")),
]

S["hid_balete"] = [
    narr("The old man from under the balete is suddenly in Teo's way, close enough to touch, an empty basket on his arm.", layout="banner"),
    narr("His feet don't reach the ground. His undershirt is soaked through, though it hasn't rained in a week."),
    say("andoy", "Baluuut... penooooy..."),
    think("Mang Isko's compadre. All these years under a tree, still calling."),
    say("andoy", "Teo... Teodoro... answer me, iho. Just once. Just answer."),
    think("Don't answer. Pray."),
    narr("The old man's jaw opens wider than a jaw should.", shake=True),
]

S["hid_balete_after"] = [
    when("andoy_sent", narr("The old man holds his basket to his chest. For a moment he isn't drowned or grey, just tired, at the end of a long shift.", layout="banner")),
    when("andoy_sent", say("andoy", "Tell Isko the corner's his. It always was.")),
    when("andoy_sent", narr("Then there is nobody under the tree at all.")),
    unless("andoy_sent", narr("The old man comes apart like wet paper. Under the balete, something keeps calling, smaller now. Not sent home. Just scattered.", layout="banner")),
    unless("andoy_sent", think("That's not how Lola taught me. That's not how it's supposed to end.")),
]

S["lamay_open"] = [
    narr("Inside: the second night of a wake.", layout="banner", panel="ep1_30_wake_night"),
    narr("Inside: monobloc chairs, a coffee urn, a card table where the relatives play tong-its for the funeral fund, and a white coffin under the photo of a man in a jeepney driver's cap."),
    think("Ernesto Calma. Mang Berto. Fifty-eight. Drowned on España Boulevard on a night when it did not rain."),
    think("Twenty-two chairs. Fourteen cups. One urn, half full. Lola will ask me the numbers, so I count the numbers."),
    think("Three Titas have asked when I'm getting a girlfriend. One of them asked twice. Same Tita. Same night."),
    narr("And at the head of the coffin, reading the ribbons on his own flowers, stands Mang Berto."),
    think("Don't look. Don't look. It's the second night. They always stand around on the second night."),
    narr("The dead man turns his head. He has seen Teo see him."),
    choice("ghost_nod", "Mang Berto is looking straight at me.", ["Ignore him, like always", "Nod. Just once."],
           [{"flags": ["ignored_ghost"]}, {"flags": ["ghost_nod"], "loob": 1}]),
    when("ghost_nod", narr("Teo nods. The dead man's eyebrows go up, and then, slowly, he nods back.")),
    when("ghost_nod", think("Fourteen years of pretending, and I just blew it on a jeepney driver.")),
    when("ignored_ghost", narr("Teo refills the urn. The dead man keeps watching him do it.")),
    when("ignored_ghost", think("Fourteen years of pretending. I'm good at it. I'm very good at it.")),
]

S["debt_notice"] = [
    narr("At eleven, Teo carries the thermos out to the drivers. That's when Kapitan Obet comes up the street in a pressed barong, a sympathy envelope in one hand and a folder in the other.", layout="banner",
         act=[{"who": "obet", "at": [3.5, 5.8]}, {"who": "obet", "walk": [11.9, 3.5]}, {"focus": [10.5, 4.0]}]),
    say("obet", "Condolence, condolence. Teo, iho. Where's your Lola?", act=[{"who": "teo", "face": "left"}, {"focus": [12.6, 3.4]}]),
    say("teo", "Upstairs, Kap. It's a wake. Can it wait?"),
    say("obet", "Everything waits, iho. That's what interest is."),
    narr("The folder. The 5-6 loan Lola took to keep the doors open, with the building as collateral. One hundred eighty thousand pesos, after interest. Due Friday."),
    say("obet", "I'm not a monster. I have a buyer for you. Hiraya Energy, the green power people. They're buying old lots in Quiapo for cash. Your Lola pays me, keeps something, retires to the province. Everyone is happy."),
    think("Everyone but the people who need a funeral they can pay for in March."),
    say("ising", "Obet. You'll have a coffee, and you'll put that folder away. Nena can see you through the door.",
        act=[{"who": "ising", "at": [13.5, 2.1]}, {"who": "ising", "walk": [13.9, 3.0]}]),
    narr("Lola Ising has come out the door without a sound. Seventy-five, small, in a housedress and a cardigan. Kapitan Obet puts the folder away."),
    narr("He also takes two ensaymada from the tray on the way past. Some things even Lola Ising cannot stop."),
    choice("obet", "Kap is still smiling at me.", ["\"We'll pay you, Kap. Friday.\"", "\"Leave the wake.\"", "Say nothing. Pour his coffee."],
           [{"flags": ["obet_promise"], "remember": remember("Kapitan Obet", "you promised Friday")},
            {"flags": ["obet_out"], "loob": 1, "remember": remember("Kapitan Obet", "you threw him out of a wake")},
            {"flags": ["obet_quiet"], "bond": {"ising": 1}}]),
    when("obet_promise", say("obet", "Friday. I'll bring a pen.")),
    when("obet_out", say("obet", "...The young. So much feeling. Friday, Ising.")),
    when("obet_out", narr("He leaves. Inside, two of the tong-its players clap, very quietly.", act=[{"who": "obet", "walk": [2.0, 6.2]}])),
    when("obet_quiet", narr("Teo pours from the thermos. Lola touches his elbow on her way back in, which is as close as she comes to saying thank you.",
                            act=[{"who": "ising", "walk": [13.5, 2.0]}])),
    unless("obet_out", narr("Kapitan Obet drinks his coffee standing, the way people do when they want you to know they have somewhere better to be.")),
]

# --- The wake is the hub: talk to people in any order; two are needed before midnight.
S["hub_nena"] = [
    narr("Aling Nena sits nearest the coffin, rosary looped twice around her wrist.", layout="banner", panel="ep1_30_wake_night"),
    say("nena", "He came home that night soaked to the skin, Teo. Soaked. I said, it isn't raining, Berto. He said, I know."),
    say("teo", "Did he say where he'd been?"),
    say("nena", "The underpass by Evangelista. A child was crying in the water, he said, so he stopped the jeep. He went down to look. The water was warm, he said. Like a bath."),
    say("nena", "Two days later they found him on España. Dry street. Lungs full of river."),
    think("A child crying in the water. Warm water. I know what Lola would say about that, and I know she'd say it quietly."),
    narr("Over Aling Nena's shoulder, Mang Berto has stopped reading his ribbons. He is listening to his wife.", fx={"flags": ["clue_underpass"]}),
]

S["hub_coffin"] = [
    narr("Teo straightens the flowers, which is the only excuse anyone needs to stand by a coffin.", layout="banner", panel="ep1_30_wake_night"),
    narr("Mang Berto's mouth is sewn and waxed, Kardo's careful work. But a thin line of brown water has crept from the corner of his lips onto the white satin. It should not be there. Kardo does not make that kind of mistake."),
    think("Two days embalmed and he's still leaking river."),
    narr("Teo touches the stain. It is warm, and it smells of rust, the way the Pasig smells where the old factories used to empty into it."),
    think("Rust. Not mud. Rust."),
    narr("Across the coffin, the dead man looks down at the stain on his own pillow, and then at Teo, as if to say: you see it too.", fx={"flags": ["clue_rust"]}),
]

S["hub_domeng"] = [
    narr("Mang Domeng sells candles outside Quiapo Church by day and sits at every wake on Hidalgo Street by night, for the coffee.", layout="banner", panel="ep1_07_mang_domeng"),
    say("domeng", "Teo. Sit. You look like a man who's counted the chairs twice."),
    say("teo", "Three times."),
    say("domeng", "Your Lola came to my stall on Tuesday. Paid for forty days of candles. In advance."),
    say("teo", "Forty days?"),
    say("domeng", "A pasiyam, then a forty-day. That's what you buy for the dead, iho. I asked her who for. She said, someone who won't be here to buy them."),
    think("Nobody in this house is dying. Nobody I know about."),
    say("domeng", "I'm an old man and I sell wax. Don't listen to me. But listen to her, while she's talking.", fx={"flags": ["clue_candles"]}),
    narr("He presses a bundle of white candles into Teo's hands, the long-burning kind, wrapped in yesterday's Abante."),
    say("domeng", "For the road. A prayer without a candle is just talking, iho. On the house. This once."),
]

S["hub_cards"] = [
    narr("At the card table, Berto's son Jun-jun is losing at tong-its and arguing with his uncle about who gets the jeepney franchise.", layout="banner", panel="ep1_30_wake_night"),
    say("junjun", "He's not even buried and you want the route? Tito, I drove that route with him since I was fifteen!"),
    choice("cards", "Two more minutes and somebody throws a chair.", ["Deal yourself in and change the subject", "Tell them Mang Berto can hear them"],
           [{"flags": ["cards_dealt"], "bond": {"junjun": 1}}, {"flags": ["cards_truth"], "loob": 1}]),
    when("cards_dealt", say("teo", "Deal me in. Twenty pesos. And tell me about his last fare, Jun-jun. Was it a good one?")),
    when("cards_truth", say("teo", "He's right there. He can hear every word. Do you want that to be the last thing he hears?")),
    when("cards_truth", narr("Nobody laughs. At a wake on Hidalgo Street, nobody laughs at that.")),
    say("junjun", "...His last fare was weird. A man in a Hiraya Energy jacket. Paid in new bills, wanted the underpass by Evangelista, at midnight. Tatay said he smelled like a hospital."),
    think("Hiraya. Kapitan Obet's buyer. Twice in one night.", fx={"flags": ["clue_hiraya"]}),
]

S["berto_ghost"] = [
    narr("Past midnight. The tong-its game breaks up. Aling Nena sleeps in her chair. The neon outside buzzes like a fly against glass.", layout="banner", panel="ep1_31_berto_ghost"),
    narr("Mang Berto sits down in the empty chair next to Teo."),
    when("ghost_nod", say("berto", "You nodded. You're Pido's grandson, the one who sees. I was twelve at my father's wake, iho, and I watched your Lolo nod at an empty chair beside the coffin. Now I know who was sitting in it.")),
    when("ignored_ghost", say("berto", "Iho. You can stop pretending. I was twelve at my father's wake, and I watched your Lolo pretend not to see the empty chair beside the coffin. He was bad at it too. You have his face when you pretend.")),
    say("teo", "...You're supposed to go, Mang Berto. On the ninth night. That's how it works."),
    say("berto", "Nine nights? Iho, I drove España for thirty years. Nothing in this city arrives on schedule. Not even the dead."),
    say("berto", "And who tells Nena about the twelve thousand pesos in the jeepney seat cushion? The franchise fee. I was saving it. If I go, Jun-jun sells the jeep with the money inside it."),
    when("clue_underpass", say("teo", "What happened at the underpass?")),
    when("clue_underpass", say("berto", "There was a baby in the water. And then there wasn't a baby. There was something holding me under, and it was smiling.")),
    when("clue_rust", say("berto", "I still taste the river. Rust and rust and rust.")),
    narr("Water runs from his sleeves now, though he is sitting still. It pools on the tiles, brown and warm. His edges have begun to darken, like a photograph left in the sun."),
    think("Lola told me once, when I was small and she thought I wasn't listening: if they stay too long, they forget who they were. Then they only remember being hungry."),
    choice("berto", "He's starting to forget. I can see it happen.", ["\"I'll tell Nena about the cushion. I promise.\"", "\"It isn't my job, Mang Berto. I'm sorry.\""],
           [{"flags": ["promise_berto"], "bond": {"berto": 1}, "remember": remember("Mang Berto", "you made him a promise")},
            {"flags": ["refused_berto"]}]),
    when("promise_berto", say("berto", "Twelve thousand. In the cushion. Tell her I wasn't drinking it.")),
    when("refused_berto", say("berto", "Then whose job is it?")),
    when("refused_berto", think("I don't have an answer. Lola would. Lola always has an answer, and she never tells me.")),
]

S["lola_watch"] = [
    narr("Upstairs, Lola Ising is kneeling in front of the old aparador with a key Teo has never seen.", layout="banner", panel="ep1_03_lola_packing"),
    narr("Half the room is in boxes. Clothes in sacks. A bus ticket on the bed, to Vigan, for tomorrow morning. One seat."),
    say("teo", "'La. He's turning. Mang Berto. He's sitting downstairs and he's turning."),
    say("ising", "I know, apo. I heard the water. Hold out your hands."),
    narr("From the aparador she lifts something wrapped in black cloth. Through the cloth, it smokes. Her fingers redden where they touch it, and she sets her jaw against it."),
    say("ising", "It was your Lolo's. Then it was mine to keep, not to use. It has not wanted me for a long time."),
    qte("watch_catch", "Her hands shake. The cloth slides. The watch drops toward the floorboards.", "CATCH!", 2.2, "guided",
        "It's falling. Watch the big ring close on the white circle. When it glows green, press SPACE (A button) or TAP.",
        ok={"banner": "Caught."}, miss={"banner": "It hits the boards. A hairline crack across the crystal."}),
    when("watch_catch_ok", narr("He catches it a hand's width from the boards. It does not burn him. It is warm, like something asleep.")),
    when("watch_catch_miss", narr("It hits the boards with a crack that should have split the case. The case is fine. Across the crystal runs a hairline crack, thin as a hair. Teo picks it up. It does not burn him. It is warm, like something asleep.")),
    narr("Against his palm: tick.", flash=True, sfx="TIK."),
    narr("On the wall downstairs, all nine stopped clocks tick once, together, and stop again at 4:17.", panel="ep1_02b_stopped_clocks"),
    say("ising", "...So. It knows whose turn it is.", fx={"flags": ["bearer_teo"]}),
    say("teo", "'La, what is this?"),
    say("ising", "Later. You have a man downstairs who is forgetting his own name. Bring the oil from the altar, and the knife you think I don't know about."),
    say("teo", "...What knife?"),
    say("ising", "The balisong behind the patis, under the rice dispenser. Since you were fifteen. I dust it, apo."),
]

S["berto_turns"] = [
    narr("The viewing room is cold. The water on the tiles has spread to the walls. Aling Nena sleeps through all of it, and so do the cousins on the bench.", layout="banner", panel="ep1_31_berto_ghost", shake=True),
    narr("Mang Berto stands over his own coffin. He is not reading the ribbons any more. His jaw has come unhinged, a little, and keeps opening."),
    when("promise_berto", say("berto", "The cushion... the... what was in the cushion, iho? I had it a minute ago.")),
    when("refused_berto", say("berto", "Whose job... whose... I'm so hungry, iho.")),
    say("ising", "Teo! The oil!"),
    qte("oil", "Lola throws the bottle of langis from the stairs, end over end, across the room.", "CATCH!", 1.6, "assisted",
        ok={}, miss={"injury": 8, "banner": "It shatters. You coat the blade from the floor and cut your palm: -8 HP"}),
    when("oil_ok", narr("Coconut oil, blessed every Friday at the Quiapo altar. Teo runs it down the blade of his balisong, and the steel steams.")),
    when("oil_miss", narr("Glass on tile. Teo drags the blade through the spilled oil on the floor and opens his palm on a shard doing it. The steel steams anyway.")),
    say("ising", "You don't hurt them, apo. You hurt what's eating them. Cut the hunger out, and he'll remember."),
    think("A balisong and a bottle of oil. Walang atrasan, Teo. No backing out."),
    narr("Lola comes down the last three steps, rosary wound round her fist, and plants her slippers beside him."),
    say("ising", "And don't look at me like that. I've been doing this since before your father was born. Keep his hands busy. I'll keep the beat."),
    say("teo", "And if that's not enough?"),
    say("ising", "Then I call your Lolo. He never once said no to me in forty years. He won't start now."),
    think("My seventy-five-year-old Lola is backing me up in a fight with a ghost. In house slippers."),
]

S["hatid"] = [
    narr("The darkness tears off Mang Berto like a wet coat and drains away between the floor tiles. What is left is a tired man in a driver's cap.", layout="banner", panel="ep1_33_hatid_boat"),
    say("ising", "Now send him. His whole name, and that his fare is paid. Say it like you mean it."),
    say("teo", "Ernesto Calma. Your fare is paid. Go home.", fx={"gratitude": 1}),
    narr("Somewhere there is no river, a ship's horn sounds. A lantern swings in the doorway of the parlor, on the prow of a narrow boat no one else can see. The ferrywoman Magwayen does not get off. She never does.", music="silence"),
    when("promise_berto", say("berto", "The cushion, iho.")),
    when("promise_berto", say("teo", "The cushion. Twelve thousand. You weren't drinking it.")),
    when("refused_berto", say("berto", "So it was your job after all.")),
    narr("He steps onto the boat. The lantern goes out. The water on the tiles is only water, and then it is not even that.", flash=True),
    say("ising", "So. You see them."),
    say("teo", "Since I was six, 'La."),
    say("ising", "Since you were four. You told me about the woman on the stairwell landing. I told you it was a dream, because I wanted it to be."),
]

S["lola_answers"] = [
    narr("They sit on the stairs, the way they did when Teo was small and a wake ran late.", layout="banner", panel="ep1_10_lola_tea"),
    say("ising", "I'll answer you one thing tonight. Only one. Choose well, apo, because tomorrow I'm on a bus."),
    choice("big1", "One question.", ["\"What is the watch?\"", "\"Why are you leaving?\"", "\"What happened to Lolo?\""],
           [{"flags": ["ask_watch"], "remember": remember("Lola Ising", "you asked about the watch")},
            {"flags": ["ask_leaving"], "loob": 1, "remember": remember("Lola Ising", "you asked why she was leaving")},
            {"flags": ["ask_lolo"], "bond": {"ising": 1}, "remember": remember("Lola Ising", "you asked about your Lolo")}]),
    when("ask_watch", say("ising", "We are sundô, Teo. Your Lolo, his mother, her father. We walk the dead home before something hungrier finds them first.")),
    when("ask_watch", say("ising", "The watch is cut from the heart of a balete, the tree where Sidapa marks how long each of us will live. It can borrow time from that tree. A second. A minute. A flood.")),
    when("ask_watch", say("ising", "And every second it borrows, it writes down. Against this family. Someone always comes to collect.")),
    when("ask_leaving", say("ising", "Because people are coming for that watch, and I would rather they followed an old woman to Vigan than knocked on a door with you behind it.")),
    when("ask_leaving", say("teo", "One seat. You bought one seat.")),
    when("ask_leaving", say("ising", "The watch was supposed to go to the Salonga family in Tondo tonight. Old sundô, older than us. Then it ticked for you. So now I don't know what I'm doing. That's the truth. Are you happy?")),
    when("ask_lolo", say("ising", "Your Lolo borrowed four minutes and seventeen seconds, once, to push a flood out of this street. It cost him ten years. He died at sixty-one, looking eighty.")),
    when("ask_lolo", say("ising", "Those clocks downstairs stopped at the moment he finished. I never wound them again. I didn't want to hear them count.")),
    say("ising", "Keep it on you. Against your skin. And Teo: never point it at anyone you love."),
    say("teo", "Why?"),
    say("ising", "Because it will tell you the truth."),
]

S["act1_hook"] = [
    narr("2:03 AM. Lola Ising is asleep in her chair at the top of the stairs, glasses on, rosary in her lap.", layout="banner", panel="ep1_10_lola_tea"),
    think("Never point it at anyone you love. She said it like a dare. She knows me."),
    narr("Teo opens the watch. He turns it toward her."),
    narr("The hands spin, slow, and settle. Not on the time now. On a time.", panel="ep1_25_watch_future", flash=True),
    narr("2:40.", music="silence"),
    think("Thirty-seven minutes."),
]

# =============================================================================================== ACT 2: ANG SUNDÔ
S["two_forty"] = [
    narr("2:05 AM. Teo shakes Lola awake. She listens to all of it with her glasses pushed up on her forehead.", layout="banner", panel="ep1_10_lola_tea"),
    say("ising", "Everyone has a time, apo. I'm seventy-five. Mine was never going to be a surprise."),
    say("teo", "It's thirty-five minutes away, 'La! It's not a time, it's a reason. Something is coming here, at 2:40."),
    say("teo", "So I stay. I sit at the bottom of these stairs with the balisong until it's 2:41, and then we argue about it."),
    say("ising", "With the balisong from behind the patis. Against whatever is coming at 2:40. Apo, I raised you better than that plan."),
    say("ising", "If it's coming here, I want you out of this house."),
    say("teo", "'La..."),
    say("ising", "...You have your Lolo's temper. Then use it. Go to the water. That's where it starts, always. Find it before it finds the door. Come back before the bells."),
    think("Mang Berto's underpass. The child in the water. The rust."),
    say("ising", "One more thing. The old way, before you leave. Salt on the threshold, or the door open so you can hear me call?"),
    choice("door", "Salt keeps things out. An open door lets her call me.", ["Lay the salt line, like she taught me", "Leave the door open, so I hear her"],
           [{"flags": ["salt_door"], "bond": {"ising": 1}}, {"flags": ["open_door"], "loob": 1}]),
    when("salt_door", narr("A line of rock salt across the threshold, from the jar by the altar. Lola watches him do it and says nothing, which means he did it right.")),
    when("open_door", narr("Teo props the door with a chair. Lola says nothing, which means she would have chosen the salt.")),
]

S["estero"] = [
    narr("The estero behind Evangelista Street. A concrete creek with a tin roof of squatter houses over it. No rain tonight, and the water is up to the second rung of every ladder.", layout="banner", panel="ep1_34_estero_pump"),
    narr("At the end of the creek, where it meets the underpass, a new pumping station hums behind a chain-link fence. On the fence, a logo: a rising sun in a circle. HIRAYA ENERGY. LIWANAG PARA SA LAHAT."),
    think("Light for everyone. At two in the morning, pumping a creek that shouldn't be full."),
    narr("The watch ticks faster against his ribs as he walks toward the fence, like a heartbeat climbing stairs."),
    when("clue_rust", think("Rust. The whole creek smells of it. Same as Mang Berto's pillow.")),
    when("clue_hiraya", think("A man in a Hiraya jacket paid Mang Berto to drive him here at midnight. Now I'm here at two.")),
    narr("Three ways in: a hole in the fence by the pump house, the crying under the bridge, and a rusted catwalk over the water."),
    choice("route", "2:14. Which way?", ["Through the fence to the pump house", "Down to the crying under the bridge", "Along the catwalk, over the water"],
           [{"flags": ["route_pump"]}, {"flags": ["route_cry"], "loob": 1}, {"flags": ["route_catwalk"]}], seconds=12, default=0),
    when("route_pump", narr("Inside the fence: cables as thick as Teo's arm run from the pump down into the creek, and the creek water around them glows a faint, sick blue.")),
    when("route_pump", think("They're not pumping water out. They're pumping something out of the water.")),
    when("route_cry", narr("Under the bridge, the crying stops the moment his shoes touch the bank. A baby's blanket floats past, empty, and folds itself under like a hand closing.")),
    when("route_cry", think("Mang Berto stopped for a crying baby. That's how it got him. Nobody in Quiapo drives past a crying baby.")),
    when("route_catwalk", narr("From the catwalk, Teo can see shapes under the water. People. Lying on the bottom of the creek in rows, eyes open, waiting. None of them are breathing. None of them need to.")),
    when("route_catwalk", think("The unsent. Every drowned soul in this creek that never got a hatid. Someone's keeping them here.")),
    narr("All three ways end at the same place: the pump house fence. And between Teo and the fence, three people who are awake at two in the morning for reasons of their own."),
]

S["hub2_tess"] = [
    narr("A woman in a duster sits on the steps of the nearest house over the creek, awake, as if she has been awake for weeks.", layout="banner", panel="ep1_34_estero_pump"),
    say("tess", "You're looking at the water. Everybody looks at the water now. Three weeks ago nobody looked at it."),
    say("teo", "What happened three weeks ago, 'Te?"),
    say("tess", "My Bong went in after a ball. Nine years old. The Hiraya guards pulled me back from the fence. They said he drowned. They never let me see the water. They never gave me a body to bury."),
    think("No body. No wake. No hatid. He's down there with the others."),
    say("tess", "If you're from the church, tell Father I still light the candle. Every night. Tell him I don't know where to point it."),
    narr("Teo does not say he is not from the church.", fx={"flags": ["heard_tess"], "remember": {"who": "Aling Tess", "what": "you listened"}}),
]

S["hub2_celso"] = [
    narr("At the bridge, a barangay tanod in a reflective vest is drinking gin out of a coffee cup and pretending it is coffee.", layout="banner", panel="ep1_34_estero_pump"),
    say("celso", "Curfew, boy. Unless you're a Dimaculangan. Are you a Dimaculangan? You have the face. Pido's face."),
    think("Everybody over sixty on this side of Quiapo says that. Nobody under sixty knows what it means."),
    say("celso", "Hiraya pays our electric, pays our tanod allowance, paid for the new basketball court. Kapitan Obet signed the permit for that pump himself. Free light for everybody, he said. Who says no to light?"),
    say("teo", "Who signed it, Kuya?"),
    say("celso", "Kapitan Obet. Three weeks ago. Same week the kid went in. Coincidence, ha? Everything is a coincidence in this barangay.", fx={"flags": ["obet_permit"]}),
]

S["hub2_guard"] = [
    narr("At the fence, a Hiraya security guard, maybe nineteen, holds his flashlight like it might protect him from something.", layout="banner", panel="ep1_34_estero_pump"),
    say("guard", "Sir, bawal po. Restricted. I'm just contractual, sir, please. Five months and twenty-nine days. Endo na po ako next week."),
    say("teo", "What do they pump out of that creek?"),
    say("guard", "I don't know, sir. I don't ask. A white van comes at two every night, from the Wellness Center in Taguig, and takes the tanks. I sign the sheet. That's all."),
    narr("He glances at the pump house. Then at the watch chain hanging from Teo's pocket, ticking loud enough to hear. Then he turns his flashlight off and walks the other way, which is a kind of answer.", fx={"flags": ["van_schedule"]}),
]

S["creek_rises"] = [
    narr("2:18. Teo reaches the pump house fence. The watch in his pocket is ticking so hard he can feel it in his teeth.", layout="banner", panel="ep1_34_estero_pump", shake=True),
    narr("The creek feels it too. The surface bulges. Faces press up against it from underneath, the way they pressed up through the floor of the parlor in 1998."),
    think("Same as Lolo. Same as the old story. Except I don't have a sundang. I have a balisong and Lola's oil."),
    when("heard_tess", narr("Among the faces, a small one. A boy of nine with his mouth open, reaching up for a ball that is not there.")),
    when("heard_tess", think("Bong.")),
    narr("They come up out of the water all at once, hungry, and the watch is the warmest thing they have felt in years."),
    choice("creek", "They're coming for the watch.", ["Hold your ground on the bank", "Get your back to the fence"],
           [{"flags": ["creek_bank"], "loob": 1}, {"flags": ["creek_fence"]}], seconds=8, default=1),
    when("creek_bank", think("Walang atrasan. Not one step back from the water.")),
    when("creek_fence", think("Fence at my back. They come at me from the front or not at all.")),
]

S["dead_sundo"] = [
    narr("Inside the pump house, a folding chair. In the chair, an old man with a black panyo around his left wrist. He has been dead for less than an hour.", layout="banner", panel="ep1_35_dead_sundo"),
    think("A panyo on the left wrist. Like Lolo in the old photographs. He's a sundô."),
    narr("His ID, clipped to his shirt: AMBROSIO SALONGA, 47. The face on the ID is a man of forty-seven. The face in the chair is a man of ninety."),
    when("ask_leaving", think("Salonga. The family in Tondo. Lola's plan. The watch was supposed to go to him tonight.")),
    unless("ask_leaving", think("Salonga. Lola sends a Christmas card to Tondo every year.")),
    narr("On his lap, a ledger: names and dates in five different hands, back to 1901, every one a soul sent home. The last line is in fresh ink, the pen still in his fingers."),
    narr("DIMACULANGAN. KINOKOLEKTA NA.  Being collected."),
    narr("Around his neck, a string of balete beads, the kind his family would have used the way Teo's used a watch. Every bead is cracked through."),
    think("He borrowed until there was nothing left to borrow. That's what it looks like. That's what it looks like when they collect."),
    choice("ambo", "2:22. I could send him. It takes a minute I might not have.", ["Send him home (hatid)", "Take the ledger and keep moving"],
           [{"flags": ["ambo_sent"], "loob": 1, "gratitude": 1, "remember": remember("Mang Ambo", "you sent him home")}, {"flags": ["ledger_taken"]}], seconds=12, default=0),
    when("ambo_sent", say("teo", "Ambrosio Salonga. Your fare is paid. Go home.")),
    when("ambo_sent", narr("For a moment the old man in the chair is forty-seven again, and his eyes open, and they are not afraid.")),
    when("ambo_sent", say("ambo", "It wasn't the Hiraya men, Dimaculangan. It was what they feed. Run.")),
    when("ledger_taken", narr("Teo tucks the ledger into his jacket. It is heavier than paper should be.")),
    narr("Outside, along the creek, the streetlights go out one by one, from the far end toward the pump house. The last one, right above the door, flickers. Then it goes too."),
]

S["aswang_drop"] = [
    narr("Rusted iron screams overhead. Something heavy lands on the catwalk above the door, and the catwalk bends.", layout="right-split", panel="ep1_13_aswang_fire_escape", flash=True, shake=True, sfx="KRAAASH!"),
    narr("Too many joints. Skin like wet tar. A head that hangs upside down from its own neck, and at its ear, blinking green, a plastic clamp stamped with a little rising sun."),
    say("teo", "Diyos ko. It's tagged. Somebody tagged it like a cow.", layout="left-split", panel="ep1_14_renzo_shock", shake=True),
    narr("It turns its upside-down face toward Teo, and then toward the watch in his fist, and it smiles."),
    think("A balisong, Lola's oil, and a watch I don't know how to use. Walang atrasan.", layout="left-split", panel="ep1_15_renzo_cornered", shake=True),
]

S["after_aswang"] = [
    narr("The aswang comes apart into oily smoke, and the smoke goes down into the creek, and the creek, for a second, glows blue all the way to the river.", layout="banner", panel="ep1_14_renzo_shock"),
    narr("Teo is on his knees at the water's edge. In the black water, his reflection looks back."),
    narr("At his left temple, a streak of white hair that was not there an hour ago.", panel="ep1_36_white_streak", flash=True, music="silence"),
    think("Lolo's hair."),
    think("It turned back the moment that thing killed me. I felt it. Like falling up a staircase. And it wrote it down. It wrote it down against me."),
    when("heard_tess", narr("On the water, small lights rise, one for every face that was under it, and drift downstream toward a lantern that waits where the creek meets the river. One of them is small, and it bobs like a ball.")),
    when("heard_tess", say("teo", "Bong. Your fare is paid, little one. Go home. Your mother is lighting a candle.")),
    unless("heard_tess", narr("On the water, small lights rise, one for every face that was under it, and drift downstream toward a lantern that waits where the creek meets the river.")),
    narr("On the catwalk, the tag that fell off the aswang's ear still blinks green."),
    choice("tag", "The tag is still blinking.", ["Take it: evidence, even if it's tracking you", "Crush it under your heel"],
           [{"flags": ["has_tag"], "loob": 1}, {"flags": ["tag_crushed"]}]),
    when("has_tag", think("Green light, blinking against my palm. If it's telling someone where I am, let them come.")),
    when("tag_crushed", narr("The tag dies with a small, offended chirp.")),
    narr("2:29."),
]

S["gate_ram"] = [
    narr("Headlights. An engine screaming down the service road straight at the chained gate, and Teo is between the gate and the creek.", layout="banner", panel="ep1_19_gate_brace", shake=True, sfx="SKREEEE!"),
    qte("gate_brace", "The gate is about to come apart.", "BRACE!", 1.8, "free",
        ok={}, miss={"injury": 10, "banner": "Thrown by the blast: Teo starts the next fight 10 HP down"}),
    narr("The gate comes apart.", layout="banner", panel="ep1_18_dante_krash", flash=True, shake=True, sfx="KRASH!"),
    narr("An old electric-company bucket truck, the bucket still on its boom, the doors painted over in grey. At the wheel, in embalmer's coveralls: Kardo."),
    think("Kardo. Twenty-eight years in our basement, and I've heard him say maybe a hundred words. Most of them to the radio."),
    say("kardo", "Teo. Get in."),
    narr("Behind Teo, the creek has started to bubble again."),
    say("teo", "Since when do you have a truck?"),
    say("kardo", "Since before I had you to look after. Ask me while I'm driving."),
    say("teo", "Is that a whole electric-company truck?"),
    say("kardo", "The power company retired it. I un-retired it. The seatbelt's broken, so hold on to the Santo Niño. He's glued down."),
    narr("Down the service road, a white van with a rising sun on its side pulls away from the far end of the pumping station. No headlights. Something in the back is banging to get out."),
    choice("big2", "2:31. Lola's time is in nine minutes. The van is getting away.", ["\"Home. Lola. Drive!\"", "\"Follow that van. It's them.\""],
           [{"flags": ["went_home"], "bond": {"kardo": 1}, "remember": remember("Kardo", "you chose Lola over the van")},
            {"flags": ["chased_van"], "loob": 1, "remember": remember("Kardo", "you chased the van")}], seconds=10, default=0),
]

S["truck_talk"] = [
    narr("The bucket truck smells of diesel, formaldehyde and 3-in-1 coffee. Kardo drives like the road personally owes him money.", layout="banner", panel="ep1_37_kardo_truck"),
    narr("The radio is playing a drama on DZRH. Kardo turns it down out of respect. Then he turns it back up, because Lucinda is about to find out the twin was the father all along."),
    when("chased_van", narr("They chase the van four blocks along Quezon Boulevard, close enough for Teo to see the passenger window roll down. A woman's profile. A white streak at her temple, like his. Then the van turns under the Quiapo overpass and is simply gone.", fx={"flags": ["saw_celeste"]})),
    when("chased_van", say("kardo", "Lost it. Hiraya vans don't show up on anything. I'm turning back.")),
    when("went_home", say("kardo", "Your Lola called me a little after two. Said you'd gone to the water with that watch. Said, Kardo, it's time.")),
    narr("At the red light on Quezon Boulevard, Kardo glances over. Then he looks again, longer. At Teo's temple."),
    say("kardo", "How many times did it turn back for you?"),
    say("teo", "...Once. The aswang had me. And then it didn't."),
    say("kardo", "Once. Okay. Once you can live with."),
    think("He knows what the watch does. Lola's embalmer, who talks to the radio, knows exactly what the watch does."),
    choice("kardo_q", "Twenty-eight years in our basement. What else hasn't he said?", ["\"Who are you, really?\"", "\"You were there in '98. Weren't you?\"", "\"What's Hiraya doing with that creek?\""],
           [{"flags": ["kq_who"]}, {"flags": ["kq_98"], "bond": {"kardo": 1}}, {"flags": ["kq_hiraya"], "loob": 1}]),
    say("kardo", "Your Lolo didn't listen to anybody, so I'll say this once, to you. That watch doesn't give. It lends. Every time it saves you, somebody in your family pays."),
]

S["parlor_taken"] = [
    when("went_home", narr("2:41. Hidalgo Street. The truck brakes so hard the bucket swings. One minute late.", layout="banner", panel="ep1_24_workshop_raid")),
    when("went_home", narr("At the far end of the street, the tail lights of a second white van, no headlights, turning the corner onto Quezon Boulevard.")),
    when("went_home", narr("From inside it, through the metal, an old woman's voice shouts one word.")),
    when("went_home", say("ising", "TEO!", shake=True)),
    when("went_home", narr("Then the corner, and the tail lights, and nothing.")),
    when("chased_van", narr("2:48. Hidalgo Street. Eight minutes late.", layout="banner", panel="ep1_24_workshop_raid")),
    narr("The parlor's neon is dark. The door of Punerarya Dimaculangan stands open."),
    when("salt_door", narr("The salt line is unbroken. Whatever came for her could not cross it, so it did not try: it cut a hole through the wall beside the door, a perfect circle, the edges still hot.")),
    when("salt_door", narr("And in the salt, written with a finger, in Lola's hand: HUWAG KANG SUSUNOD.  Don't follow.")),
    when("open_door", narr("On the step, one of Lola's slippers. The other is in the street.")),
    narr("Inside: Aling Nena and the cousins asleep in their chairs, too deeply, a sweet chemical smell in the air. Mang Berto's coffin knocked off its stand. The aparador upstairs torn open, and the boxes for Vigan emptied on the floor."),
    say("teo", "LOLA!"),
    narr("Teo opens the watch and points it at her empty chair."),
    narr("The hands do not settle on a time. They do not move at all. Where her time was, the dial is blank.", panel="ep1_25_watch_future", flash=True, music="silence"),
    think("Not stopped. Taken."),
]

# =============================================================================================== ACT 3: UTANG
S["morgue"] = [
    narr("The basement of Punerarya Dimaculangan: Kardo's embalming room. Steel table, formaldehyde, a radio, and a jeepney seat bolted to the wall for a couch.", layout="banner", panel="ep1_38_morgue"),
    narr("Kardo puts a cup of 3-in-1 coffee into Teo's hands and closes his fingers around it, because they will not stop shaking."),
    say("kardo", "Drink. Sugar first. Then we think."),
    say("teo", "Mang Kardo, this is mostly sugar."),
    say("kardo", "It's 3-in-1. I made it 5-in-1. Drink."),
    say("teo", "They took her. While I was out there fighting their pet. That's what it was for. To get me out of the house."),
    when("oil_miss", say("kardo", "Hand. Give it. You cut it on the glass? You're your Lolo's grandson, all right.")),
    when("gate_brace_miss", say("kardo", "Ribs. Don't argue. Your ribs are telling me you hit that gate with your face.")),
    choice("morgue1", "Kardo has the suture kit out.", ["Let him patch you up", "\"I'm fine. Tell me where she is.\""],
           [{"flags": ["patched"], "bond": {"kardo": 1}}, {"flags": ["not_patched"], "loob": 1}]),
    when("patched", narr("Kardo stitches the way he embalms: fast, neat, no talking. It helps. Teo hates that it helps.")),
    when("not_patched", say("kardo", "I don't know yet. But I know who's going to tell us. Sit.")),
]

S["kardo_1998"] = [
    say("kardo", "You want to know about 1998? The real one. Not the one your Lola tells, and not the one your Lolo never told.", layout="banner", panel="ep1_38_morgue"),
    narr("He tells it the way the player has already seen it: the knocking coffins, the drowned rising, the watch, the river pouring backward down Hidalgo Street. Two hundred and fifty-seven seconds."),
    say("kardo", "Then he went white, and I thought that was the price. That was not the price."),
    say("kardo", "The water had to go somewhere. It went to Santa Ana. All at once. Thirty-one people drowned there before sunrise, kid. Riverside families. One of them was a bus driver named Villacorta, and he had a son."),
    narr("A long beat. The radio hisses between stations."),
    choice("big_moral", "Lolo saved this street. He drowned another one.", ["\"He couldn't have known.\"", "\"He knew.\"", "Say nothing."],
           [{"flags": ["lolo_innocent"], "bond": {"kardo": 1}}, {"flags": ["lolo_knew"], "loob": 1, "remember": remember("Kardo", "you said your Lolo knew")}, {"flags": ["lolo_silent"]}]),
    when("lolo_innocent", say("kardo", "Maybe. He never said. He spent his last eleven years lighting candles in Santa Ana every third of June, and he never said.")),
    when("lolo_knew", say("kardo", "...Yeah. I think he did. I think he knew where it was owed, and he chose us. I don't know if I'd have chosen different.")),
    when("lolo_silent", say("kardo", "That's what I said too, the first ten years.")),
]

S["tape"] = [
    narr("On a shelf behind the formaldehyde, a Nescafé can. Inside it, a cassette, labelled in Lola's careful capitals: KARDO. KUNG WALA NA AKO BAGO ANG KAMPANA.  If I'm gone before the bells.", layout="banner", panel="ep1_38_morgue"),
    say("kardo", "She gave me this in May. Made me swear not to play it unless I had to."),
    say("kardo", "She also made me label it twice. In case I forgot which tape was hers and which was my Eraserheads."),
    narr("The tape recorder clicks. Hiss, and then a voice calm as a kettle on the stove."),
    say("tape", "Teo. If Kardo is playing this, they came for me, and they came for the house, and you were not in it. Good. That was the plan."),
    say("tape", "The bus to Vigan was for them to follow. One seat. I meant to be the one they chased. If you are hearing this, it did not work. Don't blame Kardo. Blame the old woman who thought she could outrun a ledger."),
    when("ask_watch", say("tape", "You asked me about the watch. Here is the rest. It isn't a curse. It's a contract. Your Lolo signed it with a flood. I've spent twenty-eight years trying to make the payments small.")),
    when("ask_leaving", say("tape", "You asked me why I was leaving. Now you know. I'm sorry I lied about the packing. I'm not sorry I tried.")),
    when("ask_lolo", say("tape", "You asked me about your Lolo. He was a good man who did one terrible, necessary thing, and I never forgave him for it, and I loved him every day.")),
    when("clue_candles", say("tape", "Domeng will have told you about the candles. They are not for me, apo. They are for her. You'll understand.")),
    say("tape", "Every second you borrow, the watch writes down. Don't let them make you pay for our mistakes. And Teo: there is a place where the Pasig tastes of rust. Kardo knows it. That's where the door is."),
    when("clue_rust", think("Rust. Mang Berto's pillow. The creek. She knew where all of this was going.")),
    choice("tape_reply", "Her voice is so calm.", ["Say it out loud: \"I'm coming, 'La.\"", "Say nothing. Listen to the hiss.", "\"Stop the tape.\""],
           [{"flags": ["vow"], "loob": 1, "remember": remember("Lola Ising", "you promised you were coming")},
            {"flags": ["listened"], "bond": {"ising": 1}}, {"flags": ["stopped_tape"], "bond": {"kardo": -1}}]),
    when("vow", say("tape", "...And if I know you, you just said you're coming. Then come carefully.")),
    when("listened", narr("Under the hiss, very faintly, Lola is humming. The same song she hummed on the stairs when a wake ran late.")),
    when("stopped_tape", narr("Kardo stops it without a word. The silence in the morgue sounds like the inside of a coffin.")),
]

S["the_offer"] = [
    narr("At 3:20 AM, Teo's phone rings. Unknown number. A soft voice, the kind that has never once had to shout.", layout="banner", panel="ep1_23_aevum_chatter"),
    say("benitez", "Mr. Dimaculangan. Attorney Lorna Benitez, Hiraya Energy, Legal. I'm sorry for the hour, and I'm sorry about your grandmother's door."),
    say("teo", "Where is she?"),
    say("benitez", "Safe. The Hiraya Wellness Center in Taguig. Voluntary protective custody. Her heart is not what she tells you it is, Mr. Dimaculangan. Did you know she takes three different pills?"),
    when("van_schedule", think("The Wellness Center. The guard at the fence said a white van comes from there every night at two, and takes the tanks.")),
    narr("A photo arrives. Lola Ising in a clean hospital bed, an IV in her arm, holding today's Inquirer under her chin. She looks absolutely furious, which means she is alive."),
    say("benitez", "Here is our offer. Hiraya has already acquired Kapitan Obet's paper on your building. We forgive it, all of it. We return your grandmother home, tonight. We pay you a fair price for the lot, if you want to sell, and a better one if you don't."),
    say("benitez", "And the other debt. The one written in that watch. We can carry it for you. We have resources that can pay what your family owes, so that you never go white at thirty."),
    say("teo", "Resources. You mean the people in that creek."),
    say("benitez", "I mean the thirty-one people who drowned in Santa Ana on 3 June 1998, Mr. Dimaculangan. Our chairman was seventeen. He held his father's hand on a roof until he couldn't. We are not asking you to stop protecting your street. We are asking your family to stop drowning ours."),
    think("And the worst part is she believes it. And the worst part is, so do I. A little."),
    choice("big3", "Lola, the house, the debt. All of it, for the watch.", ["Refuse", "\"I need proof she's all right. In person.\"", "\"...Yes. Tell me where.\""],
           [{"flags": ["offer_refused"], "loob": 1, "remember": remember("Hiraya Energy", "you refused their offer")},
            {"flags": ["offer_stalled"], "bond": {"kardo": 1}, "remember": remember("Hiraya Energy", "you asked for proof")},
            {"flags": ["offer_yes"], "remember": remember("Hiraya Energy", "you said yes")}], seconds=15, default=1),
    when("offer_refused", say("benitez", "I understand. I would have, too, at your age. We'll speak again.")),
    when("offer_stalled", say("benitez", "Of course. I'll arrange it. A car will come.")),
    when("offer_yes", say("kardo", "Teo. Teo, no.")),
    when("offer_yes", say("benitez", "Thank you. Stay where you are. We'll collect it.")),
    narr("The line goes dead. On the radio, between stations, something begins to tick."),
]

S["hound_in"] = [
    narr("The street-level window grating over the morgue sink buckles inward, bolt by bolt.", layout="banner", panel="ep1_23_aevum_chatter", shake=True),
    when("has_tag", say("kardo", "You kept the tag?! Of course they found us!")),
    unless("has_tag", say("kardo", "They didn't need a tag. They've had this house on a map for twenty-eight years.")),
    when("offer_yes", say("teo", "I said yes! I said yes, why are they breaking in?")),
    when("offer_yes", say("kardo", "Because 'collect' doesn't mean the watch, kid. It means you.")),
    narr("Something long and white drops through the window onto the steel table: four piston legs, a ribbed body, and one round lens that glows like a rising sun."),
    when("offer_stalled", say("kardo", "That's not a car.")),
    say("kardo", "Finally. Something I'm qualified to fight."),
    say("teo", "You're an embalmer!"),
    say("kardo", "I was a lineman for twenty years before I was an embalmer. Electricity and the dead, kid. Same customers, eventually."),
    narr("Kardo pulls a coil of copper jumper wire off the wall, clamps one end to the steel table and the other to the morgue's breaker, and grins for the first time all night."),
    say("kardo", "I wire it, you cut it, I light it up. Don't stand in the water."),
]

S["after_hound"] = [
    narr("The hound's lens cracks, sparks, and goes dark. Its ribbed chest splits open on the steel table.", layout="banner", panel="ep1_38_morgue"),
    narr("Inside, where an engine should be: a glass vial of blue light, the same sick blue as the creek. And in the light, pressed against the glass, a face."),
    when("ambo_sent", narr("A woman Teo has never seen, maybe thirty, her mouth moving without sound. Someone else's mother. Someone else's unsent.")),
    unless("ambo_sent", narr("Mang Ambo Salonga. Forty-seven again. His mouth moving without sound.")),
    say("kardo", "Ginhawa. Breath. They're bottling them, Teo. That's their green power. That's what's running Hidalgo Street's free electricity."),
    narr("Kardo's hand, on the edge of the table, is shaking now too."),
    say("kardo", "If people saw this. If the whole barangay saw this, plugged into their electric fans..."),
    choice("vial", "Kardo wants proof. The soul in the glass wants out.", ["Break the vial and send them home", "Keep it. People need to see this."],
           [{"flags": ["vial_freed"], "loob": 1, "remember": remember("Kardo", "you broke the vial")},
            {"flags": ["vial_kept"], "bond": {"kardo": 2}, "remember": remember("Kardo", "you kept the proof")}]),
    when("vial_freed", say("teo", "Your fare is paid. Go home.")),
    when("vial_freed", narr("The glass breaks in his hand without his hand closing. A lantern swings in the morgue doorway for half a second. Kardo looks at the empty table for a long time.")),
    when("vial_freed", say("kardo", "...That was the right thing. I'm going to be angry about it for a week.")),
    when("vial_kept", narr("Kardo wraps it in a clean towel like something newborn and puts it in the freezer between two unclaimed bodies.")),
    when("vial_kept", say("kardo", "I'm sorry, whoever you are. We'll send you home. After everyone sees.")),
    when("promise_berto", narr("Teo's phone buzzes. A text from Aling Nena, at 3:51 AM: Nakita ko sa cushion. 12,000. Salamat, iho. Hindi pala siya umiinom. (Found it in the cushion. Thank you. He wasn't drinking after all.)")),
]

S["dawn"] = [
    narr("5:40 AM. Upstairs, the parlor is waking up. The gas wears off the mourners one by one, and they find the room as the raiders left it.", layout="banner", panel="ep1_30_wake_night"),
    narr("Aling Nena is putting Mang Berto's flowers back in their stands with her own hands. Mang Domeng arrives with his first candles of the day and stops in the doorway."),
    say("domeng", "Susmaryosep. Ising?"),
    narr("Behind him, one of the cousins wakes up from the gas, looks around the wrecked parlor, says \"Ay, bumaha ba?\", and goes back to sleep."),
    say("teo", "They took her, Mang Domeng. In the night. While I was out."),
    narr("Mang Domeng sets down his candles very carefully, the way you set down something you are afraid you will throw."),
    narr("At the door: Kapitan Obet, in yesterday's barong, two tanods behind him, and a new folder."),
    say("obet", "Teo. Iho. I heard. I'm sorry. I came to secure the property, that's all, there are papers..."),
    when("obet_permit", say("teo", "You signed the permit for the pump on the estero, Kap. Three weeks ago. The same week a nine-year-old went in that water.")),
    when("obet_permit", say("obet", "...It was a pumping station! For flooding! They said flooding!")),
    say("obet", "They bought the paper on this building, Teo. Three weeks ago. They paid me triple. I thought: Ising gets her money, everyone wins. Nobody said anything about taking her. I swear on my mother."),
    say("teo", "Three weeks ago. And last night you stood at Mang Berto's wake with a folder and told my Lola it was due Friday. You were collecting a debt you'd already sold, Kap."),
    say("obet", "...They asked me to keep the pressure on. So she'd sell. That's all. Pressure."),
    when("obet_out", say("obet", "And you threw me out of a wake, so don't look at me like that.")),
    when("obet_promise", say("obet", "You promised me Friday. I believed you. I'm the one who didn't keep his word. That's the truth.")),
    choice("obet_dawn", "Kapitan Obet sold us. He's also the only one here who's been inside Hiraya's offices.", ["\"Get out of my Lola's house.\"", "\"Then help me get her back. You owe her.\"", "Say nothing. Let the room look at him."],
           [{"flags": ["obet_shamed"], "loob": 1, "remember": {"who": "Kapitan Obet", "what": "you threw him out of the house"}},
            {"flags": ["obet_owes"], "bond": {"obet": 1}, "remember": {"who": "Kapitan Obet", "what": "you told him he owes her"}},
            {"flags": ["obet_silence"]}]),
    when("obet_shamed", narr("He goes. The two tanods hesitate, then follow him, and one of them leaves his flashlight on the table for Teo, which nobody mentions.")),
    when("obet_owes", say("obet", "...The Wellness Center. Fourth floor is the real one, not the clinic. I've been to the third. That's as high as they let a barangay captain go. I'll draw you the lobby.")),
    when("obet_silence", narr("Aling Nena looks at him. Mang Domeng looks at him. Every cousin who ever borrowed from his 5-6 looks at him. Kapitan Obet looks at the floor, and then he leaves the folder on the table and goes.")),
    say("domeng", "Your Lola paid me for forty days of candles, iho. I'm lighting the first one now. Not for her. For whoever brings her home."),
]

S["photo"] = [
    narr("Upstairs, Teo kneels in what is left of Lola's room. Among the things the raiders threw out of the aparador: a photograph in a plastic sleeve. He has never seen it.", layout="banner", panel="ep1_39_photo_liwayway"),
    narr("Lola Ising, young, on the stairs of this parlor, the walls still dark with flood water. In her arms, a baby girl."),
    narr("On the back, in Lolo Pido's handwriting: LIWAYWAY. 3 HUNYO 1998. SIYA ANG SUSUNOD."),
    say("teo", "Liwayway. Mama's first baby. She drowned in the flood. Mama still calls from Dubai on her birthday and doesn't say why."),
    say("teo", "'She is the next.' The next what? She drowned, Mang Kardo. Didn't she?"),
    narr("Kardo has followed him up the stairs. He looks at the photo, and then over the banister at the stopped clocks on the parlor wall below, all reading 4:17, and then at the floor."),
    say("kardo", "...Ask your Lola. When we get her back."),
    say("teo", "You were there. You were on those stairs."),
    say("kardo", "I was there. And I promised her. Ask me anything else."),
    choice("photo_q", "He knows. He's known for twenty-eight years.", ["Push him", "Let it go, for now"],
           [{"flags": ["pushed_kardo"], "loob": 1, "bond": {"kardo": -1}}, {"flags": ["spared_kardo"], "bond": {"kardo": 1}}]),
    when("pushed_kardo", say("kardo", "Somebody knocked on this door on the morning after the flood, Teo. That's all you get. That's already more than I should.")),
    when("spared_kardo", say("kardo", "...Thank you. Get two hours of sleep, downstairs, where it's quiet. Then Taguig.")),
]

S["cliffhanger"] = [
    narr("6:17 AM. The morgue is quiet. Kardo is asleep on the jeepney seat with the suture kit still open on his chest. Upstairs, the stopped clocks still say 4:17.", layout="banner", panel="ep1_38_morgue"),
    think("Kardo snores in exactly the rhythm of the radio static. Twenty-eight years in this basement. They've synced."),
    think("Never point it at anyone you love."),
    think("She never said anything about pointing it at myself."),
    narr("Teo opens the watch and turns it toward his own face."),
    narr("The hands do not settle on a time. The dial turns, and turns, and shows a date: the night the moon goes dark. Laho. Forty-seven days from now.", panel="ep1_25_watch_future", flash=True, sfx="TIK."),
    think("Forty-seven days."),
    narr("On the radio, the morning news replays last night's press conference from BGC: Hiraya Energy announces LIWANAG, free power for every household in Metro Manila, starting the night of the eclipse."),
    say("villacorta", "My father drowned when I was seventeen, in a flood no one could explain. I have spent my life making sure no Filipino family will ever again be at the mercy of things they cannot see."),
    narr("The TV in the corner, sound off, runs the same replay, with LAST NIGHT in the corner of the screen. Beside Gregorio Villacorta, in a white suit, stands his daughter and chief operating officer.", panel="ep1_40_celeste_tv"),
    when("saw_celeste", narr("Teo knows her profile. He saw it a few hours ago, in the window of a van with no headlights, on its way back from the creek.")),
    narr("Celeste Villacorta. Twenty-eight. When she tucks her hair behind her ear for the cameras, there is a streak of white at her left temple. Exactly where Teo's is.", music="sting"),
    say("teo", "...Liwayway.", flash=True),
]

S["title_card_note"] = []  # (cards live in the flow, not in scenes)
del S["title_card_note"]

json.dump({"_note": "Generated by tools/build_episode1.py. Edit the generator, not this file.", "scenes": S},
          open(os.path.join(DATA, "episode1.json"), "w"), indent=1, ensure_ascii=False)


# =============================================================================================== FLOW
def sc(id, goal, **k):
    d = {"type": "scene", "id": id, "goal": goal}
    d.update(k)
    return d


def card(big, lines, hold=4.0):
    return {"type": "card", "big": big, "lines": lines, "hold": hold}


FLOW = {"acts": [
    {"number": 1, "title": "Lamay", "beats": [
        dict(card("QUIAPO  ·  3 HUNYO 1998", ["3:58 in the morning.", "The river has come four streets inland."], 4.5), music="tension", chapter=0),
        sc("co_flood", "Hold the parlor against the drowned.", music="tension"),
        {"type": "fight", "enemy": "lunod", "party": ["pido"], "carry_wounds": True, "goal": "As Lolo Pido: send the drowned back (parry tutorial)."},
        sc("co_wave", "They keep coming.", music="tension"),
        {"type": "fight", "enemy": "lunod_tide", "party": ["pido"], "goal": "You can't win this one. Hold the stairs for three turns."},
        sc("co_rewind", "See what the watch can do, and what it costs.", music="tension"),
        sc("co_downriver", "See where the water went.", action="note", music="tension"),
        card("BALETE", ["Episode 1: Ang Lumang Orasan"], 3.5),
        {"type": "act_card", "chapter": 1, "music": "wake"},
        sc("hidalgo_arrive", "Walk to the parlor. The wake is waiting.", music="wake",
           stage={"map": "hidalgo", "focus": [5.0, 5.0], "cast": {"teo": {"at": [-0.4, 6.4]}}}),
        {"type": "hub", "id": "hidalgo", "title": "HIDALGO STREET", "music": "wake", "goal": "Get to the wake before eleven.",
         "prompt": "Who do you stop for on the way in? (At least one.)", "need": 1, "map": "hidalgo",
         "options": [
             {"scene": "hid_balut", "label": "Mang Isko, the balut vendor", "short": "Mang Isko", "at": [8.1, 3.3], "sprite": "balut", "h": 1.4},
             {"scene": "hid_trike", "label": "Rudy, asleep in his tricycle", "short": "Rudy", "at": [17.4, 5.6], "sprite": "trike", "h": 1.5},
             {"scene": "hid_kid", "label": "Nonoy, staring at the balete", "short": "Nonoy", "at": [20.8, 3.6], "sprite": "kid", "h": 1.15},
             # A visible enemy (retro JRPG): Mang Andoy drifts under the balete. Walk into him to fight
             # (scripts/stage_battle.gd), or keep clear of him. He comes for Teo when Teo gets close.
             {"scene": "hid_balete", "label": "The voice under the balete", "short": "Mang Andoy", "at": [23.3, 3.3],
              "roam": {"sprite": "mag_idle", "area": [22.2, 1.9, 24.8, 3.8], "h": 1.75, "ghost": True, "chase": 2.2, "speed": 0.55},
              "fight": {"enemy": "magbabalot", "map": "hidalgo"}, "after": "hid_balete_after"},
         ], "leave": "GO IN TO THE WAKE"},
        sc("lamay_open", "Night shift at the family's funeral parlor. Decide whether to keep pretending.", music="wake"),
        sc("debt_notice", "Meet the debt at the door.", music="wake",
           stage={"map": "hidalgo", "focus": [10.5, 4.0], "cast": {
               "teo": {"at": [13.0, 3.3]},
               "obet": {"sprite": "obet", "at": [3.5, 5.8], "h": 1.45, "name": "Kapitan Obet", "hidden": True, "speed": 2.2},
               "ising": {"sprite": "ising", "at": [13.5, 2.1], "h": 1.25, "name": "Lola Ising", "hidden": True, "speed": 0.9},
               "rudy": {"sprite": "trike", "at": [17.4, 5.6], "h": 1.5},
               "isko": {"sprite": "balut", "at": [8.1, 3.3], "h": 1.4}}}),
        {"type": "hub", "id": "wake", "title": "THE WAKE", "music": "wake", "goal": "Work the wake: learn how Mang Berto died.",
         "prompt": "Who do you sit with? (Talk to at least two people before midnight.)", "need": 2,
         "options": [
             {"scene": "hub_nena", "label": "Aling Nena, the widow", "short": "Aling Nena", "at": [8.4, 3.1], "sprite": "nena", "h": 1.35},
             {"scene": "hub_coffin", "label": "Straighten the flowers by the coffin", "short": "The coffin", "at": [9.5, 2.4], "tag_h": 1.9},
             {"scene": "hub_domeng", "label": "Mang Domeng, by the coffee urn", "short": "Mang Domeng", "at": [3.7, 1.7], "sprite": "domeng", "h": 1.35},
             {"scene": "hub_cards", "label": "The tong-its table", "short": "Tong-its table", "at": [4.6, 5.3], "tag_h": 1.25},
         ], "leave": "IT'S PAST MIDNIGHT",
         # The walkable wake (data/maps.json "parlor"): positions are [x, z] in metres on the parlor floor, from the
         # street door (front left) to the stairs (back right). Mang Berto's ghost sits in the empty chair beside his
         # wife, in front of his own coffin; two neighbours play tong-its.
         "map": "parlor",
         "extras": [{"sprite": "berto", "at": [10.6, 3.1], "h": 1.35, "ghost": True},
                    {"sprite": "cards_a", "at": [4.0, 4.25], "h": 1.3},
                    {"sprite": "cards_b", "at": [5.2, 4.25], "h": 1.3}]},
        sc("berto_ghost", "Talk to the dead man at his own wake.", music="wake"),
        sc("lola_watch", "Lola gives you the watch.", music="wake"),
        sc("berto_turns", "Mang Berto forgets himself.", music="tension"),
        {"type": "fight", "enemy": "ligaw_berto", "goal": "Cut the hunger out of Mang Berto (parry, and learn to dodge)."},
        sc("hatid", "Send Mang Berto home.", action="note", music="wake"),
        sc("lola_answers", "Lola answers one question.", music="wake"),
        sc("act1_hook", "Point the watch at Lola.", action="note", music="wake"),
    ]},
    {"number": 2, "title": "Ang Sundô", "beats": [
        {"type": "act_card", "chapter": 2, "music": "tension"},
        sc("two_forty", "Tell Lola, and choose how to leave her.", music="tension"),
        sc("estero", "Follow the water to where it starts.", music="tension"),
        {"type": "hub", "id": "estero", "title": "THE ESTERO, 2:16 AM", "music": "tension", "goal": "Ask around, fast: who else is awake at the creek?",
         "prompt": "No time to hear everyone. Talk to at least one.", "need": 1,
         "options": [
             {"scene": "hub2_tess", "label": "The woman on the steps", "short": "Woman on the steps", "at": [11.6, 2.55], "sprite": "tess", "h": 1.2},
             {"scene": "hub2_celso", "label": "The tanod on the bridge", "short": "Tanod", "at": [10.45, 5.4], "sprite": "celso", "h": 1.75},
             {"scene": "hub2_guard", "label": "The guard at the fence", "short": "Guard", "at": [19.6, 8.4], "sprite": "guard", "h": 1.7},
         ], "leave": "GO TO THE FENCE",
         # The walkable creek (data/maps.json "estero"): Teo comes in from the street on the left. The woman sits on
         # the far bank, across the footbridge; the pump house and its fence are at the right end.
         "map": "estero"},
        sc("creek_rises", "The creek's unsent rise for the watch.", music="tension"),
        {"type": "fight", "enemy": "unsent", "goal": "Hold off the creek's unsent dead without a sundang."},
        {"type": "chapter", "chapter": 3, "title": "Kinokolekta Na (Being Collected)", "music": "silence"},
        sc("dead_sundo", "Find the Salonga sundô, and decide whether to send him.", music="silence"),
        sc("aswang_drop", "The tagged aswang drops.", action="note", music="tension"),
        {"type": "fight", "enemy": "aswang", "goal": "Survive the aswang. The watch awakens."},
        sc("after_aswang", "See what the watch took from you.", music="tension"),
        sc("gate_ram", "Brace for the gate, and choose: Lola or the van.", music="tension"),
        sc("truck_talk", "Learn who Kardo is.", music="tension"),
        sc("parlor_taken", "Get home.", action="note", music="tension"),
    ]},
    {"number": 3, "title": "Utang", "beats": [
        {"type": "act_card", "chapter": 4, "music": "wake"},
        sc("morgue", "Steady your hands in Kardo's morgue.", music="wake"),
        sc("kardo_1998", "Hear what the water did downriver.", music="wake"),
        sc("tape", "Hear Lola's tape.", music="silence"),
        sc("the_offer", "Answer Hiraya's offer.", music="tension"),
        sc("hound_in", "The Hiraya hound breaks in.", action="note", music="tension"),
        {"type": "fight", "enemy": "hiraya_hound", "party": ["teo", "kardo"], "goal": "Fight beside Kardo: he wires it, you cut it."},
        sc("after_hound", "Decide what to do with the soul in the glass.", music="wake"),
        sc("dawn", "Face the morning, and Kapitan Obet.", music="wake"),
        sc("photo", "Find the photograph.", music="silence"),
        sc("cliffhanger", "Point the watch at yourself.", action="note", music="silence"),
        {"type": "end"},
    ]},
]}


# "Previously on Balete": shown when the player continues a saved run. In story order; a line shows when its flags
# are set (seen_<scene> is set when a scene finishes). The game shows the latest six that apply.
def rc(text, flag=None, unless_flag=None):
    d = {"text": text}
    if flag:
        d["if"] = flag
    if unless_flag:
        d["unless"] = unless_flag
    return d


FLOW["recap"] = [
    rc("1998. Lolo Pido turned a flood back for four minutes and seventeen seconds. Downriver, the water drowned thirty-one people.", "seen_co_downriver"),
    rc("At Mang Berto's wake, you nodded at a dead man. He nodded back.", "ghost_nod"),
    rc("At Mang Berto's wake, you pretended not to see a dead man. He saw you anyway.", "ignored_ghost"),
    rc("You promised Kapitan Obet the money by Friday.", "obet_promise"),
    rc("You threw Kapitan Obet out of a wake.", "obet_out"),
    rc("Kapitan Obet came to collect. You poured his coffee and said nothing.", "obet_quiet"),
    rc("Mang Berto's last fare wore a Hiraya Energy jacket.", "clue_hiraya"),
    rc("You promised Mang Berto you'd tell his wife about the money in the cushion.", "promise_berto"),
    rc("You told Mang Berto it wasn't your job.", "refused_berto"),
    rc("Lola Ising gave you Lolo Pido's watch. It ticked for you.", "bearer_teo", "watch_catch_miss"),
    rc("Lola Ising gave you Lolo Pido's watch. You dropped it, and the crystal cracked. It ticked for you anyway.", "watch_catch_miss"),
    rc("You sent Mang Berto home on Magwayen's boat.", "seen_hatid"),
    rc("Lola told you what the watch is: it borrows time, and writes every second against the family.", "ask_watch"),
    rc("Lola told you why she was leaving: to lead the people hunting the watch away from you.", "ask_leaving"),
    rc("Lola told you Lolo's four minutes cost him ten years.", "ask_lolo"),
    rc("You pointed the watch at Lola. It showed 2:40. Tonight.", "seen_act1_hook"),
    rc("You laid a salt line across the door, and went to the water.", "salt_door"),
    rc("You left the door open so you'd hear her call, and went to the water.", "open_door"),
    rc("Aling Tess's son went into the estero three weeks ago. Hiraya never gave her a body.", "heard_tess"),
    rc("Kapitan Obet signed the permit for Hiraya's pump on the estero.", "obet_permit"),
    rc("A white van comes for Hiraya's tanks every night at two.", "van_schedule"),
    rc("You sent home Mang Ambo Salonga, a sundô borrowed down to nothing.", "ambo_sent"),
    rc("You took Mang Ambo Salonga's ledger. Its last line: DIMACULANGAN. BEING COLLECTED.", "ledger_taken"),
    rc("The aswang killed you. The watch turned it back, and left a white streak in your hair.", "watch_awake"),
    rc("You kept the aswang's Hiraya tag.", "has_tag"),
    rc("Kardo rammed the gate. You chose Lola over the van, and got home one minute late.", "went_home"),
    rc("Kardo rammed the gate. You chased the van, and saw a woman with a white streak like yours.", "chased_van"),
    rc("Hiraya took Lola Ising. Where her time was, the dial is blank.", "seen_parlor_taken"),
    rc("Kardo told you the truth: the water Lolo pushed away drowned a boy's father. The boy was Gregorio Villacorta.", "seen_kardo_1998"),
    rc("Lola's tape: the bus to Vigan was a decoy, meant to lead them away from you.", "seen_tape"),
    rc("Hiraya offered Lola, the house and the debt for the watch. You refused.", "offer_refused"),
    rc("Hiraya offered Lola, the house and the debt for the watch. You asked for proof.", "offer_stalled"),
    rc("Hiraya offered Lola, the house and the debt for the watch. You said yes.", "offer_yes"),
    rc("Inside the Hiraya hound, a soul in a bottle. You set it free.", "vial_freed"),
    rc("Inside the Hiraya hound, a soul in a bottle. You kept it as proof.", "vial_kept"),
    rc("Kapitan Obet admitted he sold Lola's debt to Hiraya.", "seen_dawn"),
]

# =============================================================================================== STAGING
# Retro JRPG scenes: these scenes are acted on their map (data/maps.json) with sprites, under the text boxes. STAGES
# is each scene's set (who stands where at the start); direct() adds stage directions to the step whose text starts
# with the given words; big() keeps (or puts) a comic panel on one step, for the big moments. Every other panel in a
# staged scene goes. Directions: {"who", "walk"|"at": [x, z]}, {"who", "face"}, {"who", "hide": True},
# {"who", "sprite": pose}, {"focus": [x, z]} (see scripts/explore_map.gd act()).

def _find(scene, start):
    hits = [st for st in S[scene] if st.get("text", st.get("prompt", "")).startswith(start)]
    assert len(hits) >= 1, (scene, start)
    return hits


def direct(scene, start, *acts):
    for st in _find(scene, start):
        st["act"] = st.get("act", []) + list(acts)


def big(scene, start, panel=None):
    for st in _find(scene, start):
        if panel:
            st["panel"] = panel
        st["big"] = True


def W(who, x, z):
    return {"who": who, "walk": [x, z]}


def AT(who, x, z):
    return {"who": who, "at": [x, z]}


def F(x, z):
    return {"focus": [x, z]}


KARDO = {"sprite": "kardo", "h": 1.8, "name": "Kardo", "speed": 1.6}
ISING = {"sprite": "ising", "h": 1.25, "name": "Lola Ising", "speed": 0.9}
STAGES = {
    # --- Lola's room, upstairs (map "lola_room"): aparador at the back left, bed, altar, her armchair at the top of
    # the stairs (right), the stairwell dropping away at the far right.
    "lola_watch": {"map": "lola_room", "focus": [3.0, 2.6], "cast": {
        "teo": {"at": [10.5, 2.4], "face": "left"},
        "ising": dict(ISING, at=[1.6, 1.5], flip=True)}},
    "lola_answers": {"map": "lola_room", "focus": [9.8, 3.6], "cast": {
        "isingst": {"sprite": "ising_stair", "at": [9.2, 3.9], "h": 1.25, "name": "Lola Ising"},
        "teost": {"sprite": "teo_stair", "at": [10.6, 3.7], "h": 1.3, "y": -0.5, "name": "Teo"}}},
    "act1_hook": {"map": "lola_room", "focus": [9.0, 3.4], "cast": {
        "teo": {"at": [6.6, 4.6], "face": "right"},
        "isingz": {"sprite": "ising_sleep", "at": [9.4, 3.0], "h": 1.15, "name": "Lola Ising"}}},
    "two_forty": {"map": "lola_room", "focus": [8.8, 3.4], "cast": {
        "teo": {"at": [8.3, 3.9], "face": "right"},
        "isingz": {"sprite": "ising_sleep", "at": [9.4, 3.0], "h": 1.15, "name": "Lola Ising"}}},
    "photo": {"map": "lola_room", "focus": [2.4, 2.8], "cast": {
        "teo": {"at": [2.2, 2.0], "hidden": True},
        "teok": {"sprite": "teo_kneel", "at": [1.7, 1.7], "h": 1.3, "name": "Teo"},
        "kardo": dict(KARDO, at=[11.1, 6.6], hidden=True)}},
    # --- The estero (map "estero"): street on the left, footbridge, pump house and fence at the right end.
    "estero": {"map": "estero", "focus": [4.0, 8.0], "cast": {"teo": {"at": [-0.6, 7.6]}}},
    "creek_rises": {"map": "estero", "focus": [18.5, 7.4], "cast": {
        "teo": {"at": [19.4, 7.9], "face": "left"},
        "u1": {"sprite": "unsent_idle", "at": [16.2, 4.6], "h": 1.9, "ghost": True, "hidden": True},
        "u2": {"sprite": "unsent_idle", "at": [13.6, 5.0], "h": 1.7, "ghost": True, "hidden": True, "flip": True},
        "u3": {"sprite": "unsent_idle", "at": [18.4, 4.4], "h": 1.6, "ghost": True, "hidden": True}}},
    "aswang_drop": {"map": "estero", "focus": [20.0, 8.0], "cast": {
        "teo": {"at": [17.4, 7.8], "face": "right"},
        "aswang": {"sprite": "aswang_tell", "at": [19.9, 7.4], "h": 2.4, "hidden": True}}},
    "after_aswang": {"map": "estero", "focus": [14.0, 6.8], "cast": {
        "teo": {"at": [14.0, 6.6], "hidden": True},
        "teok": {"sprite": "teo_kneel", "at": [14.0, 6.5], "h": 1.3, "name": "Teo"},
        "s1": {"sprite": "unsent_calm", "at": [12.0, 4.6], "h": 1.5, "ghost": True, "hidden": True},
        "s2": {"sprite": "unsent_calm", "at": [16.6, 4.8], "h": 1.2, "ghost": True, "hidden": True}}},
    "gate_ram": {"map": "estero", "focus": [19.6, 8.6], "cast": {
        "teo": {"at": [16.8, 7.6], "face": "right"},
        "truck": {"sprite": "truck", "at": [29.0, 7.1], "h": 3.2, "speed": 9.0, "bob": False, "name": "Kardo"},
        "van": {"sprite": "van", "at": [24.6, 5.4], "h": 1.9, "speed": 4.0, "bob": False, "hidden": True}}},
    # --- Pump house interior (map "pumphouse").
    "dead_sundo": {"map": "pumphouse", "focus": [5.6, 3.2], "cast": {
        "teo": {"at": [5.0, 6.0], "face": "up"},
        "ambo": {"sprite": "salonga", "at": [6.0, 2.8], "h": 1.35, "name": "Mang Ambo"}}},
    # --- Hidalgo Street at 2:41 (map "hidalgo").
    "parlor_taken": {"map": "hidalgo", "focus": [11.0, 5.0], "cast": {
        "teo": {"at": [17.6, 6.2], "hidden": True},
        "truck": {"sprite": "truck", "at": [24.0, 6.6], "h": 3.2, "speed": 8.0, "bob": False},
        "van": {"sprite": "van", "at": [6.0, 6.6], "h": 1.9, "speed": 3.0, "bob": False, "flip": True, "name": "Lola Ising"}}},
    # --- The wake at dawn (map "parlor").
    "dawn": {"map": "parlor", "focus": [7.6, 4.0], "cast": {
        "teo": {"at": [6.4, 4.6], "face": "right"},
        "nena": {"sprite": "nena", "at": [8.4, 3.1], "h": 1.35, "name": "Aling Nena"},
        "domeng": {"sprite": "domeng", "at": [1.6, 7.4], "h": 1.35, "name": "Mang Domeng", "speed": 1.0},
        "obet": {"sprite": "obet", "at": [0.6, 7.6], "h": 1.45, "name": "Kapitan Obet", "hidden": True, "speed": 1.4}}},
}
# Kardo's morgue (map "morgue"): the jeepney seat and shelves at the back, the steel table in the middle, the sink and
# its street window at the right.
for _id in ["morgue", "kardo_1998", "tape", "the_offer", "hound_in", "after_hound"]:
    STAGES[_id] = {"map": "morgue", "focus": [5.6, 3.6], "cast": {
        "teo": {"at": [4.6, 3.9], "face": "right"},
        "kardo": dict(KARDO, at=[6.3, 4.3], flip=True)}}
STAGES["hound_in"]["cast"]["hound"] = {"sprite": "hound_tell", "at": [9.6, 1.4], "h": 1.6, "y": 0.95, "hidden": True}
STAGES["after_hound"]["cast"]["hound"] = {"sprite": "hound_hurt", "at": [7.0, 3.1], "h": 1.5, "y": 0.9}
STAGES["cliffhanger"] = {"map": "morgue", "focus": [4.0, 2.6], "cast": {
    "teo": {"at": [4.6, 2.4], "face": "down"},
    "kardoz": {"sprite": "kardo_sleep", "at": [2.4, 1.15], "h": 0.8, "y": 0.3}}}

# Lola's room
direct("lola_watch", "Upstairs, Lola Ising", W("teo", 2.9, 2.2), F(3.0, 2.4))
direct("lola_watch", "Half the room", F(4.6, 2.6))
direct("lola_watch", "'La. He's turning", {"who": "teo", "face": "left"}, F(2.4, 2.2))
direct("lola_watch", "From the aparador", {"who": "ising", "face": "right"})
direct("lola_answers", "They sit on the stairs")
direct("act1_hook", "Teo opens the watch. He turns", W("teo", 8.4, 3.7))
big("act1_hook", "The hands spin, slow, and settle")
direct("two_forty", "Everyone has a time", {"who": "isingz", "sprite": "ising"})
direct("two_forty", "...You have your Lolo's temper", W("teo", 9.8, 2.2))
direct("two_forty", "One more thing. The old way", {"who": "teo", "face": "left"})
direct("photo", "Lola Ising, young, on the stairs", F(2.0, 2.0))
big("photo", "Lola Ising, young, on the stairs", "ep1_39_photo_liwayway")
direct("photo", "Kardo has followed him up the stairs", W("kardo", 4.0, 3.2), F(3.0, 2.6))
direct("photo", "...Ask your Lola", {"who": "kardo", "face": "left"})
# The estero
direct("estero", "At the end of the creek", W("teo", 7.0, 7.4), F(15.0, 8.0))
direct("estero", "The watch ticks faster", F(8.0, 8.4))
direct("estero", "All three ways end", F(14.0, 7.6))
direct("creek_rises", "The creek feels it too", AT("u1", 16.2, 4.6), F(16.6, 6.4))
direct("creek_rises", "Among the faces, a small one", AT("u3", 18.4, 4.4))
direct("creek_rises", "They come up out of the water", AT("u2", 13.6, 5.0), W("u1", 17.0, 6.9), W("u3", 18.2, 6.8))
direct("aswang_drop", "Rusted iron screams overhead", AT("aswang", 19.9, 7.4), F(18.8, 7.6))
direct("aswang_drop", "Too many joints", {"who": "aswang", "sprite": "aswang_idle"})
direct("aswang_drop", "It turns its upside-down face", {"who": "aswang", "sprite": "aswang_wail"})
big("after_aswang", "At his left temple, a streak")
direct("after_aswang", "On the water, small lights rise", AT("s1", 12.0, 4.6), AT("s2", 16.6, 4.8))
direct("after_aswang", "On the catwalk, the tag", {"who": "s1", "hide": True}, {"who": "s2", "hide": True},
       {"who": "teok", "hide": True}, AT("teo", 14.0, 6.6))
direct("gate_ram", "Headlights.", W("truck", 19.6, 7.1), F(18.6, 7.6))
big("gate_ram", "The gate comes apart.")
direct("gate_ram", "Behind Teo, the creek", {"who": "teo", "face": "left"}, F(16.0, 7.4))
direct("gate_ram", "Down the service road", AT("van", 24.6, 5.4), W("van", 30.0, 5.4), F(21.0, 7.0))
# The pump house
big("dead_sundo", "Inside the pump house")
direct("dead_sundo", "A panyo on the left wrist", W("teo", 5.2, 3.6), {"who": "teo", "face": "right"})
direct("dead_sundo", "Outside, along the creek", W("teo", 5.0, 5.8), {"who": "teo", "face": "down"})
# Hidalgo Street, 2:41
direct("parlor_taken", "2:41. Hidalgo Street", W("truck", 17.0, 6.6), F(13.0, 5.0))
direct("parlor_taken", "At the far end of the street", W("van", -5.0, 6.6), F(6.0, 5.2))
direct("parlor_taken", "2:48. Hidalgo Street", W("truck", 17.0, 6.6), {"who": "van", "hide": True})
big("parlor_taken", "The parlor's neon is dark", "ep1_24_workshop_raid")
direct("parlor_taken", "The parlor's neon is dark", AT("teo", 13.2, 4.6), {"who": "teo", "face": "up"}, F(12.0, 4.0))
# Kardo's morgue
direct("morgue", "Kardo puts a cup", W("kardo", 5.4, 4.1))
direct("morgue", "Kardo has the suture kit out", F(5.0, 3.8))
direct("kardo_1998", "A long beat", W("kardo", 5.2, 1.6), F(5.0, 2.6))
direct("tape", "On a shelf behind the formaldehyde", W("kardo", 4.6, 1.3), F(4.6, 2.6))
direct("tape", "The tape recorder clicks", W("kardo", 5.6, 1.4), F(5.4, 2.6))
direct("the_offer", "At 3:20 AM", {"who": "teo", "face": "down"})
direct("hound_in", "The street-level window grating", W("teo", 6.4, 4.4), W("kardo", 8.4, 4.5), F(8.0, 4.0))
direct("hound_in", "Something long and white drops", AT("hound", 7.0, 3.1), F(7.2, 3.6))
direct("hound_in", "Kardo pulls a coil", {"who": "kardo", "face": "left"})
direct("after_hound", "Kardo's hand, on the edge", W("kardo", 7.9, 3.9))
direct("after_hound", "The glass breaks", {"who": "hound", "sprite": "hound_fade"})
direct("cliffhanger", "Teo opens the watch and turns it", {"who": "teo", "face": "down"})
big("cliffhanger", "The hands do not settle on a time")
big("cliffhanger", "The TV in the corner, sound off")
# The wake at dawn
direct("dawn", "Aling Nena is putting", W("domeng", 4.0, 6.0), F(5.6, 4.6))
direct("dawn", "At the door: Kapitan Obet", AT("obet", 0.6, 7.6), W("obet", 2.6, 6.6), {"who": "teo", "face": "left"}, F(4.0, 5.6))
direct("dawn", "He goes.", W("obet", -1.0, 7.8))

# --- Step 3: the last scenes that used panels as backdrops. 1998 is acted in the flooded parlor ("parlor_flood"):
# Lolo Pido (his battle poses) against the drowned, young Kardo and Ising off-screen on the stairs. The water rises
# wave by wave, and the rewind drains it. The wake scenes are acted in the parlor.
def LUNOD(x, z, h=1.9, flip=False):
    return {"sprite": "lunod_idle", "at": [x, z], "h": h, "ghost": True, "hidden": True, "flip": flip}


PIDO = {"sprite": "pidob_ready", "h": 1.75, "name": "Lolo Pido", "speed": 1.2}
STAGES.update({
    "co_flood": {"map": "parlor_flood", "focus": [8.6, 4.6], "cast": {
        "pido": dict(PIDO, at=[11.4, 4.6]),
        "l1": LUNOD(5.2, 4.4), "l2": LUNOD(6.4, 6.0, 1.7), "l3": LUNOD(3.8, 5.6, 2.0)}},
    "co_wave": {"map": "parlor_flood", "focus": [8.4, 4.8], "cast": {
        "pido": dict(PIDO, at=[9.4, 5.0], sprite="pidob_guard"),
        "l1": LUNOD(5.6, 4.6), "l2": LUNOD(6.8, 6.2, 1.7), "l3": LUNOD(12.8, 6.4, 1.8, True),
        "l4": LUNOD(3.4, 3.6, 2.0), "l5": LUNOD(13.4, 4.0, 1.6, True)}},
    "co_rewind": {"map": "parlor_flood", "focus": [10.0, 4.6], "cast": {
        "pido": dict(PIDO, at=[10.6, 5.0], sprite="pidob_down"),
        "l1": LUNOD(7.4, 4.6), "l2": LUNOD(8.4, 6.2, 1.7), "l3": LUNOD(6.4, 5.6, 2.0),
        "l4": LUNOD(13.6, 6.4, 1.8, True), "l5": LUNOD(12.8, 3.6, 1.7, True)}},
    "co_downriver": {"map": "parlor", "focus": [8.0, 4.6], "cast": {
        "pido": dict(PIDO, at=[9.0, 5.0], sprite="pidob_win")}},
    "lamay_open": {"map": "parlor", "focus": [5.0, 5.6], "cast": {
        "teo": {"at": [1.6, 7.6], "face": "up"},
        "nena": {"sprite": "nena", "at": [8.4, 3.1], "h": 1.35},
        "domeng": {"sprite": "domeng", "at": [3.7, 1.7], "h": 1.35},
        "ca": {"sprite": "cards_a", "at": [4.0, 4.25], "h": 1.3},
        "cb": {"sprite": "cards_b", "at": [5.2, 4.25], "h": 1.3},
        "berto": {"sprite": "berto", "at": [10.4, 2.2], "h": 1.35, "ghost": True, "hidden": True, "name": "Mang Berto"}}},
    "berto_ghost": {"map": "parlor", "focus": [9.0, 4.6], "cast": {
        "teo": {"at": [8.7, 5.0], "face": "right"},
        "nena": {"sprite": "nena", "at": [8.4, 3.1], "h": 1.35},
        "berto": {"sprite": "berto", "at": [11.6, 2.4], "h": 1.35, "ghost": True, "name": "Mang Berto", "speed": 0.8}}},
    "berto_turns": {"map": "parlor", "focus": [8.6, 3.8], "cast": {
        "teo": {"at": [6.8, 5.4], "face": "right"},
        "nena": {"sprite": "nena", "at": [8.4, 3.1], "h": 1.35},
        "berto": {"sprite": "lberto_idle", "at": [10.2, 2.3], "h": 1.8, "ghost": True, "flip": True, "name": "Mang Berto"},
        "ising": dict(ISING, at=[14.2, 3.4], hidden=True)}},
    "hatid": {"map": "parlor", "focus": [9.6, 4.0], "cast": {
        "teo": {"at": [7.4, 5.0], "face": "right"},
        "nena": {"sprite": "nena", "at": [8.4, 3.1], "h": 1.35},
        "berto": {"sprite": "lberto_calm", "at": [10.2, 3.4], "h": 1.8, "ghost": True, "flip": True, "name": "Mang Berto"},
        "ising": dict(ISING, at=[13.4, 3.6])}},
})
direct("co_flood", "Quiapo. 3 June 1998", {"water": 0.62, "secs": 0.2})
big("co_flood", "Quiapo. 3 June 1998")
direct("co_flood", "Mang Pido! I cut the line", F(12.6, 3.4))
direct("co_flood", "It's enough, Kardo", F(10.0, 4.4))
direct("co_flood", "Faces rise in the brown water", AT("l1", 5.2, 4.4), AT("l2", 6.4, 6.0), AT("l3", 3.8, 5.6), F(7.0, 5.0))
direct("co_flood", "Pido Dimaculangan, sundô", W("pido", 9.2, 5.0))
direct("co_wave", "The drowned sink", {"water": 0.62, "secs": 0.2}, AT("l1", 5.6, 4.6), AT("l2", 6.8, 6.2))
direct("co_wave", "Through the kitchen", AT("l3", 12.8, 6.4), AT("l4", 3.4, 3.6), AT("l5", 13.4, 4.0), F(9.4, 4.8))
direct("co_wave", "The water climbs the stairs", {"water": 0.86, "secs": 2.5}, {"who": "pido", "sprite": "pidob_hurt"},
       *[AT("l%d" % i, *xy) for i, xy in [(1, (7.2, 4.6)), (2, (8.0, 6.2)), (3, (6.0, 5.6)), (4, (14.0, 6.4)), (5, (12.8, 3.6))]], F(13.0, 3.6))
direct("co_wave", "Not the watch. Not yet", F(10.6, 4.6))
direct("co_rewind", "The water is at Pido's chest", {"water": 1.0, "secs": 0.3}, *[AT("l%d" % i, *xy) for i, xy in
       [(1, (7.4, 4.6)), (2, (8.4, 6.2)), (3, (6.4, 5.6)), (4, (13.6, 6.4)), (5, (12.8, 3.6))]])
direct("co_rewind", "He takes a pocket watch", {"who": "pido", "sprite": "pidob_pray"})
big("co_rewind", "The hands run backward. So does the river.")
direct("co_rewind", "The water slides off the walls", {"water": -0.9, "secs": 4.5},
       *[{"who": "l%d" % i, "hide": True} for i in range(1, 6)], F(8.0, 4.6))
direct("co_rewind", "When it is over", {"who": "pido", "sprite": "pidob_win"}, F(10.4, 4.6))
direct("co_rewind", "Pido. Your hair", {"who": "pido", "sprite": "pidob_ready"})
for _start in ["Two kilometres downriver", "A wall of it", "On one roof", "TATAY", "The ID card on his lanyard"]:
    big("co_downriver", _start, "ep1_c03_downriver")
direct("co_downriver", "Back in Quiapo, at dawn", F(9.0, 4.6))
direct("co_downriver", "And at the door", {"who": "pido", "sprite": "pidob_ready"}, F(3.0, 6.0))
direct("lamay_open", "Inside: monobloc chairs", W("teo", 6.4, 4.9))
direct("lamay_open", "Ernesto Calma", F(9.4, 3.4))
direct("lamay_open", "And at the head of the coffin", AT("berto", 10.4, 2.2), F(9.0, 3.6))
direct("lamay_open", "The dead man turns his head", {"who": "teo", "face": "right"})
big("berto_ghost", "Past midnight. The tong-its game breaks up")
direct("berto_ghost", "Mang Berto sits down", W("berto", 9.6, 4.5))
direct("berto_ghost", "Water runs from his sleeves", {"who": "berto", "sprite": "lberto_calm"})
direct("berto_turns", "Mang Berto stands over his own coffin", {"who": "berto", "sprite": "lberto_tell"})
direct("berto_turns", "Teo! The oil!", AT("ising", 14.2, 3.4), {"who": "teo", "face": "right"}, F(10.4, 4.0))
direct("berto_turns", "You don't hurt them", {"who": "berto", "sprite": "lberto_wail"}, F(8.6, 3.8))
direct("hatid", "Now send him. His whole name", {"who": "berto", "sprite": "berto"})
big("hatid", "Somewhere there is no river", "ep1_33_hatid_boat")
direct("hatid", "He steps onto the boat", {"who": "berto", "hide": True})
direct("hatid", "So. You see them.", W("ising", 9.0, 4.4), {"who": "teo", "face": "right"})

for _act in FLOW["acts"]:
    for _b in _act["beats"]:
        if _b.get("type") == "scene" and _b["id"] in STAGES:
            _b["stage"] = STAGES[_b["id"]]
            for st in S[_b["id"]]:
                if st.get("panel") and not st.pop("big", False):
                    del st["panel"]
                st.pop("big", None)

# Retro JRPG talks: on a walkable map, people talk in text boxes over the map, so a hub scene's backdrop panel goes.
# A step that is a big moment keeps its panel with big=True.
for act in FLOW["acts"]:
    for b in act["beats"]:
        if b.get("type") == "hub" and b.get("map"):
            for o in b["options"]:
                for st in S[o["scene"]]:
                    if st.get("panel") and not st.pop("big", False):
                        del st["panel"]
json.dump({"_note": "Generated by tools/build_episode1.py. Edit the generator, not this file.", "scenes": S},
          open(os.path.join(DATA, "episode1.json"), "w"), indent=1, ensure_ascii=False)
json.dump(FLOW, open(os.path.join(DATA, "episode1_flow.json"), "w"), indent=1, ensure_ascii=False)
print("scenes:", len(S), "steps:", sum(len(v) for v in S.values()))
