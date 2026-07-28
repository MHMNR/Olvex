
const emojis = {
    "FaceBags": "\u{1FAD9}",
    "Fingerprint": "\u{1FAC6}",
    "LeaflessTree": "\u{1FABA}",
    "RootVeg": "\u{1FADC}",
    "Harp": "\u{1FAA7}",
    "Shovel": "\u{1FAA6}",
    "Splat": "\u{1FAB7}",
    "Sark": "\u{1F1FC}\u{1F1F8}"
};

for (const [name, char] of Object.entries(emojis)) {
    console.log(`${name}: ${char} (Length: ${char.length})`);
    for (let i = 0; i < char.length; i++) {
        console.log(`  Code ${i}: \\u${char.charCodeAt(i).toString(16).toUpperCase()}`);
    }
}
