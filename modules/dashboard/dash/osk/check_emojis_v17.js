
const emojis = {
    "FaceBags": "🫩",
    "Fingerprint": "🫆",
    "LeaflessTree": "🪾",
    "RootVeg": "🫜",
    "Harp": "🪉",
    "Shovel": "🪏",
    "Splat": "🫟",
    "Sark": "🇨🇶",
    "DistortedFace": "🫪",
    "FightCloud": "🫯",
    "HairyCreature": "🫈",
    "Orca": "🫍",
    "Landslide": "🛘",
    "Trombone": "🪊",
    "TreasureChest": "🪎"
};

for (const [name, char] of Object.entries(emojis)) {
    let result = "";
    for (let i = 0; i < char.length; i++) {
        result += "\\u" + char.charCodeAt(i).toString(16).toUpperCase();
    }
    console.log(`${name}: ${result}`);
}
