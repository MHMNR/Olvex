#!/usr/bin/env python3
import urllib.request
import json
import os
import sys
import re

def update_emojis():
    output_path = os.path.expanduser("~/.config/olvex/emojis.json")
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    gemoji_url = "https://raw.githubusercontent.com/github/gemoji/master/db/emoji.json"
    emojilib_url = "https://raw.githubusercontent.com/muan/emojilib/main/dist/emoji-en-US.json"

    # Base categories fallback
    default_categories = [
        {"name": "Recent", "icon": "history", "emojis": []},
        {"name": "Smileys & Emotion", "icon": "sentiment_satisfied", "emojis": []},
        {"name": "People & Body", "icon": "person", "emojis": []},
        {"name": "Animals & Nature", "icon": "pets", "emojis": []},
        {"name": "Food & Drink", "icon": "restaurant", "emojis": []},
        {"name": "Travel & Places", "icon": "flight", "emojis": []},
        {"name": "Activities", "icon": "sports_soccer", "emojis": []},
        {"name": "Objects", "icon": "lightbulb", "emojis": []},
        {"name": "Symbols", "icon": "emoji_symbols", "emojis": []},
        {"name": "Flags", "icon": "flag", "emojis": []}
    ]

    cats = default_categories
    orig_kw = {}

    script_dir = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        output_path,
        os.path.join(script_dir, "emojis.js"),
        os.path.expanduser("~/.local/Olvex/standalone/emoji/emojis.js"),
    ]

    for cand in candidates:
        if os.path.exists(cand):
            try:
                with open(cand, "r", encoding="utf-8") as f:
                    content = f.read()
                if cand.endswith(".json"):
                    data = json.loads(content)
                    if "categories" in data and len(data["categories"]) > 0:
                        cats = data["categories"]
                    if "keywords" in data:
                        orig_kw = data["keywords"]
                    break
                else:
                    m = re.search(r'var categories = (\[.*?\]);\s*var emojiKeywords = (\{.*?\});', content, re.DOTALL)
                    if m:
                        cats = json.loads(m.group(1))
                        orig_kw = json.loads(m.group(2))
                        break
            except Exception:
                pass

    try:
        req1 = urllib.request.Request(gemoji_url, headers={"User-Agent": "OlvexEmojiUpdater/1.0"})
        with urllib.request.urlopen(req1, timeout=8) as resp:
            gemoji_data = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        gemoji_data = []

    try:
        req2 = urllib.request.Request(emojilib_url, headers={"User-Agent": "OlvexEmojiUpdater/1.0"})
        with urllib.request.urlopen(req2, timeout=8) as resp:
            emojilib_data = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        emojilib_data = {}

    gemoji_map = {}
    cat_map = {
        "Smileys & Emotion": cats[1]["emojis"],
        "People & Body": cats[2]["emojis"],
        "Animals & Nature": cats[3]["emojis"],
        "Food & Drink": cats[4]["emojis"],
        "Travel & Places": cats[5]["emojis"],
        "Activities": cats[6]["emojis"],
        "Objects": cats[7]["emojis"],
        "Symbols": cats[8]["emojis"],
        "Flags": cats[9]["emojis"],
    }

    cat_name_normalize = {
        "smileys-emotion": "Smileys & Emotion",
        "smileys & emotion": "Smileys & Emotion",
        "people-body": "People & Body",
        "people & body": "People & Body",
        "animals-nature": "Animals & Nature",
        "animals & nature": "Animals & Nature",
        "food-drink": "Food & Drink",
        "food & drink": "Food & Drink",
        "travel-places": "Travel & Places",
        "travel & places": "Travel & Places",
        "activities": "Activities",
        "objects": "Objects",
        "symbols": "Symbols",
        "flags": "Flags",
    }

    all_emojis_in_cats = set()
    for c in cats:
        for em in c["emojis"]:
            all_emojis_in_cats.add(em)

    for item in gemoji_data:
        em = item.get("emoji")
        if not em:
            continue
        words = []
        if item.get("description"):
            words.append(item["description"])
        if item.get("aliases"):
            words.extend(item["aliases"])
        if item.get("tags"):
            words.extend(item["tags"])
        gemoji_map[em] = words
        clean_em = em.replace("\ufe0f", "")
        if clean_em not in gemoji_map:
            gemoji_map[clean_em] = words

        # If gemoji has a new emoji not in our categories, add it to proper category!
        if em not in all_emojis_in_cats and clean_em not in all_emojis_in_cats:
            raw_cat = item.get("category", "").lower().strip()
            mapped_cat = cat_name_normalize.get(raw_cat)
            if mapped_cat and mapped_cat in cat_map:
                cat_map[mapped_cat].append(em)
                all_emojis_in_cats.add(em)

    custom_extras = {
        "🗿": ["moyai", "moai", "chad", "gigachad", "sigma", "easter island", "stone face", "rock", "statue", "stone", "head"],
        "💀": ["skull", "dead", "ded", "death", "skeleton", "rip", "dying", "bones", "corpse"],
        "☠️": ["skull and crossbones", "pirate", "poison", "danger", "dead", "death"],
        "🙏": ["folded hands", "pray", "prayer", "please", "thank you", "thanks", "namaste", "highfive", "bless", "amen", "hope"],
        "😭": ["loudly crying face", "sob", "crying", "cry", "tears", "sad", "bawling", "weep"],
        "💩": ["pile of poo", "poop", "poo", "shit", "crap", "turd", "feces"],
        "💯": ["hundred points", "100", "hundred", "perfect", "keep it 100", "score", "lit", "real"],
        "🤣": ["rolling on the floor laughing", "rofl", "lmao", "lol", "haha", "laugh", "crying laughing"],
        "😂": ["face with tears of joy", "joy", "lol", "lmao", "haha", "laugh", "crying"],
        "🥹": ["face holding back tears", "teary", "pleading", "emotional", "touched", "wholesome", "grateful", "proud"],
        "🫠": ["melting face", "melt", "sarcasm", "hot", "heat", "embarrassed", "awkward", "disappearing"],
        "🫡": ["saluting face", "salute", "yes sir", "respect", "aye captain", "understood", "o7"],
        "🫶": ["heart hands", "love", "hand heart", "appreciate", "affection", "wholesome"],
        "🫰": ["hand with index finger and thumb crossed", "finger heart", "kpop", "saranghae", "love", "money"],
        "🫵": ["index pointing at the viewer", "you", "pointing at you", "uncle sam", "hey you"],
        "🤡": ["clown face", "clown", "fool", "silly", "joke", "honk"],
        "🤓": ["nerd face", "nerd", "geek", "glasses", "dork", "ackchyually", "smart"],
        "😎": ["smiling face with sunglasses", "cool", "sunglasses", "swag", "boss", "shades"],
        "🔥": ["fire", "flame", "lit", "hot", "fire", "burn", "hype", "heat"],
        "✨": ["sparkles", "sparkle", "glitter", "aesthetic", "shiny", "magic", "clean", "new"],
        "🚀": ["rocket", "to the moon", "launch", "blast off", "fast", "crypto", "space"],
        "🧢": ["billed cap", "cap", "no cap", "hat", "baseball cap", "capping", "lying"],
    }

    # Ensure 🗿 is in Travel & Places as well as Objects
    for c in cats:
        if c["name"] == "Travel & Places" and "🗿" not in c["emojis"]:
            c["emojis"].append("🗿")

    new_kw = {}
    all_known_emojis = set(orig_kw.keys()) | set(gemoji_map.keys()) | set(emojilib_data.keys()) | all_emojis_in_cats

    for em in all_known_emojis:
        terms = []
        if em in orig_kw:
            terms.append(orig_kw[em])
        clean_em = em.replace("\ufe0f", "")
        if clean_em in orig_kw and orig_kw[clean_em] not in terms:
            terms.append(orig_kw[clean_em])
        if em in gemoji_map:
            terms.extend(gemoji_map[em])
        elif clean_em in gemoji_map:
            terms.extend(gemoji_map[clean_em])
        if em in emojilib_data:
            terms.extend(emojilib_data[em])
        elif clean_em in emojilib_data:
            terms.extend(emojilib_data[clean_em])
        if em in custom_extras:
            terms.extend(custom_extras[em])
        elif clean_em in custom_extras:
            terms.extend(custom_extras[clean_em])

        seen = set()
        cleaned = []
        for t in terms:
            t_clean = t.replace("_", " ").lower().strip()
            for sub in t_clean.split(":"):
                s = sub.strip()
                if s and s not in seen:
                    seen.add(s)
                    cleaned.append(s)
        new_kw[em] = " ".join(cleaned)

    full_db = {
        "version": "1.1",
        "categories": cats,
        "keywords": new_kw
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(full_db, f, ensure_ascii=False, indent=2)

    result = {
        "status": "ok",
        "categories_count": len(cats),
        "keywords_count": len(new_kw),
        "path": output_path
    }
    print(json.dumps(result))
    return 0

if __name__ == "__main__":
    sys.exit(update_emojis())
