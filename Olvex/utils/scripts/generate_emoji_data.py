#!/usr/bin/env python3
import os
import sys
import re
import json
import urllib.request

GROUP_ICONS = {
    "Smileys & Emotion": "sentiment_satisfied",
    "People & Body": "person",
    "Animals & Nature": "pets",
    "Food & Drink": "lunch_dining",
    "Travel & Places": "directions_car",
    "Activities": "sports_soccer",
    "Objects": "lightbulb",
    "Symbols": "emoji_symbols",
    "Flags": "flag"
}

UNICODE_SEARCH_PATHS = [
    "/usr/share/unicode/emoji/emoji-test.txt",
    os.path.expanduser("~/.local/share/unicode/emoji/emoji-test.txt"),
]

ONLINE_URL = "https://unicode.org/Public/emoji/latest/emoji-test.txt"
SKIN_TONE_RE = re.compile(r'[\U0001F3FB-\U0001F3FF]')

def get_emoji_source():
    for p in UNICODE_SEARCH_PATHS:
        if os.path.isfile(p):
            return p
    
    # Download to ~/.local/share/unicode/emoji/emoji-test.txt
    local_target = os.path.expanduser("~/.local/share/unicode/emoji/emoji-test.txt")
    os.makedirs(os.path.dirname(local_target), exist_ok=True)
    print(f"Downloading latest official Unicode emoji dataset from {ONLINE_URL}...")
    try:
        urllib.request.urlretrieve(ONLINE_URL, local_target)
        return local_target
    except Exception as e:
        print(f"Error downloading emoji dataset: {e}", file=sys.stderr)
        return None

def parse_emoji_test(filepath):
    categories = [{"name": "Recent", "icon": "history", "emojis": []}]
    cat_map = {}
    emoji_keywords = {}
    current_group = None
    
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith("# group:"):
                current_group = line.split(":", 1)[1].strip()
                if current_group == "Component":
                    current_group = None
                elif current_group not in cat_map:
                    cat = {
                        "name": current_group,
                        "icon": GROUP_ICONS.get(current_group, "star"),
                        "emojis": []
                    }
                    cat_map[current_group] = cat
                    categories.append(cat)
                continue
            
            if not current_group or line.startswith("#"):
                continue
            
            if "; fully-qualified" in line:
                parts = line.split("#", 1)
                if len(parts) == 2:
                    right = parts[1].strip()
                    m = re.match(r'^(\S+)\s+(E\d+\.\d+)\s+(.+)$', right)
                    if m:
                        emoji_char = m.group(1)
                        name = m.group(3).strip()
                        if not SKIN_TONE_RE.search(emoji_char):
                            if emoji_char not in cat_map[current_group]["emojis"]:
                                cat_map[current_group]["emojis"].append(emoji_char)
                                emoji_keywords[emoji_char] = name

    return categories, emoji_keywords

def main():
    source_file = get_emoji_source()
    if not source_file:
        print("Failed to locate or download Unicode emoji source.", file=sys.stderr)
        sys.exit(1)

    print(f"Parsing Unicode emoji source: {source_file}")
    categories, keywords = parse_emoji_test(source_file)
    total_emojis = sum(len(c["emojis"]) for c in categories)
    print(f"Successfully loaded {total_emojis} base emojis across {len(categories)} categories.")

    # Target output paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(script_dir, "../.."))
    
    out_paths = [
        os.path.join(repo_root, "modules/dashboard/dash/osk/emojis.js"),
        os.path.join(repo_root, "standalone/emoji/emojis.js"),
    ]

    content = ".pragma library\n\n"
    content += "var categories = " + json.dumps(categories, ensure_ascii=False, indent=4) + ";\n\n"
    content += "var emojiKeywords = " + json.dumps(keywords, ensure_ascii=False, indent=4) + ";\n"

    for out_path in out_paths:
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Generated: {out_path}")

if __name__ == "__main__":
    main()
