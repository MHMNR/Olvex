import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property var ydotool: null

    // ── Current word buffer ──────────────────────────────────────────────────
    property string currentWord: ""
    property var suggestions: []

    // ── User learned words: { word: frequency } ──────────────────────────────
    property var learnedWords: ({})

    // ── Built-in seed dictionary ─────────────────────────────────────────────
    readonly property var baseDictionary: [
        "the","be","to","of","and","a","in","that","have","it","for","not","on","with","he",
        "as","you","do","at","this","but","his","by","from","they","we","say","her","she","or",
        "an","will","my","one","all","would","there","their","what","so","up","out","if","about",
        "who","get","which","go","me","when","make","can","like","time","no","just","him","know",
        "take","people","into","year","your","good","some","could","them","see","other","than","then",
        "now","look","only","come","its","over","think","also","back","after","use","two","how",
        "our","work","first","well","way","even","new","want","because","any","these","give","day",
        "most","us","between","need","large","often","hand","high","place","hold","turn","here","why",
        "help","talk","where","much","through","before","down","should","never","each","those","feel",
        "seem","great","again","still","every","small","found","tell","since","while","might","next",
        "both","thing","put","against","home","little","three","ask","keep","right","change","world",
        "start","always","show","hear","name","long","old","part","play","real","same","stop","try",
        "already","ever","away","together","nothing","include","company","however","different","must",
        "something","state","number","information","point","today","during","follow","important","often",
        "better","provide","public","read","require","second","set","several","study","support","though",
        "write","until","without","done","open","clear","form","process","whether","large","possible",
        "actually","side","fact","action","problem","available","system","program","question","true",
        "thank","please","yes","okay","hi","hello","hey","bye","sorry","sure","maybe","really","very",
        "awesome","perfect","testing","building","making","looking","going","coming","trying","thinking","typing"
    ]

    // ── Persistence ──────────────────────────────────────────────────────────
    readonly property string savePath: {
        let home = Quickshell.env("HOME") || "/root";
        return home + "/.config/olvex/osk_words.json";
    }

    property Process saveProcess: Process {
        command: ["bash", "-c", ""]
        onExited: {}
    }

    property FileView loadFile: FileView {
        path: root.savePath
        watchChanges: false
        onLoaded: {
            try {
                root.learnedWords = JSON.parse(loadFile.text()) || {};
            } catch(e) {
                root.learnedWords = {};
            }
        }
    }

    function save() {
        let json = JSON.stringify(learnedWords);
        let escaped = json.replace(/'/g, "'\"'\"'"); // safe for single-quote shell
        saveProcess.command = ["bash", "-c", `mkdir -p ~/.config/olvex && echo '${escaped}' > "${savePath}"`];
        saveProcess.running = true;
    }

    // ── Public API ───────────────────────────────────────────────────────────

    property string lastChars: ""
    property bool autoCapPending: false
    signal sentenceBoundaryDetected()

    function onChar(ch) {
        let prevChars = lastChars;
        lastChars = (lastChars + ch).slice(-10);
        
        // Double-space to period shortcut (GBoard style)
        if (ch === ' ' && prevChars.endsWith(' ') && !prevChars.endsWith('. ')) {
            ydotool.tapKey(14); // backspace
            ydotool.tapKey(14); // backspace
            ydotool.typeString(". ");
            lastChars = lastChars.slice(0, -2) + ". ";
            sentenceBoundaryDetected();
            autoCapPending = true;
            return;
        }

        // Sentence boundary detection
        // Matches: . (space), ! (space), ? (space), or newline
        if (ch === '\n' || /[\.\!\?]\s+$/.test(lastChars)) {
            sentenceBoundaryDetected();
            autoCapPending = true;
        } else if (/[a-zA-Z]/.test(ch)) {
            autoCapPending = false;
        }
        
        // ... rest of the function
        if (/^[a-zA-Z']$/.test(ch)) {
            currentWord += ch.toLowerCase();
            updateSuggestions();
        } else {
            if (currentWord.length > 1) commitWord(currentWord);
            currentWord = "";
            suggestions = [];
        }
    }

    function onBackspace() {
        if (currentWord.length > 0) {
            currentWord = currentWord.slice(0, -1);
            updateSuggestions();
        }
        // If we backspace, we might need to reset autocap pending
        autoCapPending = false;
    }

    // Returns the suffix string to type after accepting a suggestion
    function acceptSuggestion(word) {
        let suffix = word.slice(currentWord.length);
        commitWord(word);
        currentWord = "";
        suggestions = [];
        return suffix + " ";
    }

    // ── Internals ────────────────────────────────────────────────────────────

    function commitWord(word) {
        if (word.length < 2) return;
        let w = word.toLowerCase();
        learnedWords[w] = (learnedWords[w] || 0) + 1;
        save();
    }

    function updateSuggestions() {
        if (currentWord.length === 0) { suggestions = []; return; }
        let prefix = currentWord.toLowerCase();
        let results = [];
        let seen = {};

        for (let word in learnedWords) {
            if (word.startsWith(prefix) && word !== prefix) {
                results.push({ word: word, score: learnedWords[word] * 2 });
                seen[word] = true;
            }
        }

        for (let i = 0; i < baseDictionary.length; i++) {
            let w = baseDictionary[i];
            if (!seen[w] && w.startsWith(prefix) && w !== prefix) {
                results.push({ word: w, score: 1 });
            }
        }

        results.sort((a, b) => b.score - a.score);
        suggestions = results.slice(0, 3).map(r => r.word);
    }

    Component.onCompleted: loadFile.reload()
}
