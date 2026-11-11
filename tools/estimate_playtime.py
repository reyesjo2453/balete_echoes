"""Estimates Episode 1 play time from the flow and scene data (run in CI so the number is always current).

Model: reading speed 22 characters per second plus 1.2 s per tap; a choice adds 7 s of thinking, a QTE 9 s (a
guided one 29 s with its lesson); a fight about 4.5 minutes (the hound, with Kardo, 3.7); cards 4-6 s; the
hub counts its required scenes in full and the optional ones at 60%. Conditional steps and scenes count at an average weight, since a player sees about
half of any branch. Prints per act, the total, and the longest stretch without a choice.
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "godot", "data")


def load(name):
    return json.load(open(os.path.join(DATA, name), encoding="utf8"))


scenes = load("episode1.json")["scenes"]
flow = load("episode1_flow.json")
READ_CPS, TAP = 22.0, 1.2


def weight(step):
    w = 1.0
    if "if" in step:
        w *= 0.45
    if "unless" in step:
        w *= 0.5
    return w


def scene_time(sid):
    t = 0.0
    for st in scenes.get(sid, []):
        w = weight(st)
        chars = len(st.get("text", ""))
        base = chars / READ_CPS + TAP
        if "choice" in st:
            base += 7.0
        if "qte" in st:
            base += 29.0 if st["qte"].get("level") == "guided" else 9.0
        t += base * w
    return t


total = 0.0
rows = []
gap = 0.0
longest = 0.0
choice_count = 0
step_count = 0
for act in flow["acts"]:
    at = 0.0
    for beat in act["beats"]:
        w = 0.5 if ("if" in beat or "unless" in beat) else 1.0
        kind = beat["type"]
        if kind == "card":
            t = beat.get("hold", 4.0) + 1.0
        elif kind == "act_card":
            t = 4.0
        elif kind == "scene":
            t = scene_time(beat["id"]) * w
            steps = scenes.get(beat["id"], [])
            step_count += len(steps)
            ch = sum(1 for s in steps if "choice" in s or "qte" in s)
            choice_count += ch
            if ch:
                gap = 0.0
            gap += t
            longest = max(longest, gap)
        elif kind == "hub":
            opts = beat["options"]
            need = beat.get("need", len(opts))
            per = [scene_time(o["scene"]) for o in opts]
            t = sum(per) * (need + (len(opts) - need) * 0.6) / len(opts) + 6.0 * need
            step_count += sum(len(scenes.get(o["scene"], [])) for o in opts)
            gap = 0.0
        elif kind == "fight":
            t = 220.0 if beat.get("enemy") == "hiraya_hound" else 270.0
            gap += t
        else:
            t = 0.0
        at += t
        longest = max(longest, gap)
    rows.append((act["number"], act["title"], at / 60.0))
    total += at
print("Episode 1 estimated play time")
for n, title, m in rows:
    print("  Act %d  %-14s %5.1f min" % (n, title, m))
print("  Total: %.0f min (%d scenes' steps, %d choices/QTEs); range %.0f to %.0f min" % (total / 60.0, step_count, choice_count, total / 60.0 * 0.85, total / 60.0 * 1.2))
print("  Longest stretch without a choice, QTE or the hub: %.1f min" % (longest / 60.0))
