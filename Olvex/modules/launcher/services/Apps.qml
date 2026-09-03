pragma Singleton

import Quickshell
import Olvex
import Olvex.Config
import qs.utils

Searcher {
    id: root

    property var _allAppsCache: []

    onCatalogChanged: warmCatalog()

    function warmCatalog() {
        if (_allAppsCache.length === 0)
            _allAppsCache = query("").map(e => e.entry);
    }

    function invalidateCatalog() {
        _allAppsCache = [];
        warmCatalog();
    }

    function launch(entry) {
        if (!entry) return;
        appDb.incrementFrequency(entry.id);

        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: ["app2unit", "--", ...Config.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...entry.command],
                workingDirectory: entry.workingDirectory
            });
        else
            Quickshell.execDetached({
                command: ["app2unit", "--", ...entry.command],
                workingDirectory: entry.workingDirectory
            });
    }

    function setKeysAndWeights(newKeys, newWeights) {
        let keysChanged = !keys || keys.length !== newKeys.length || keys.some((v, i) => v !== newKeys[i]);
        let weightsChanged = !weights || weights.length !== newWeights.length || weights.some((v, i) => v !== newWeights[i]);
        if (keysChanged) keys = newKeys;
        if (weightsChanged) weights = newWeights;
    }

    function search(text) {
        const prefix = GlobalConfig.launcher.specialPrefix;

        if (text.startsWith(`${prefix}i `)) {
            setKeysAndWeights(["id", "name"], [0.9, 0.1]);
        } else if (text.startsWith(`${prefix}c `)) {
            setKeysAndWeights(["categories", "name"], [0.9, 0.1]);
        } else if (text.startsWith(`${prefix}d `)) {
            setKeysAndWeights(["comment", "name"], [0.9, 0.1]);
        } else if (text.startsWith(`${prefix}e `)) {
            setKeysAndWeights(["execString", "name"], [0.9, 0.1]);
        } else if (text.startsWith(`${prefix}w `)) {
            setKeysAndWeights(["startupClass", "name"], [0.9, 0.1]);
        } else if (text.startsWith(`${prefix}g `)) {
            setKeysAndWeights(["genericName", "name"], [0.9, 0.1]);
        } else if (text.startsWith(`${prefix}k `)) {
            setKeysAndWeights(["keywords", "name"], [0.9, 0.1]);
        } else {
            setKeysAndWeights(["name"], [1]);

            if (!text.startsWith(`${prefix}t `)) {
                return query(text).map(e => e.entry);
            }
        }

        const results = query(text.slice(prefix.length + 2)).map(e => e.entry);
        if (text.startsWith(`${prefix}t `))
            return results.filter(a => a.runInTerminal);
        return results;
    }

    function selector(item) {
        return keys.map(k => item[k]).join(" ");
    }

    catalog: appDb.apps
    useFuzzy: GlobalConfig.launcher.useFuzzy.apps

    AppDb {
        id: appDb

        path: `${Paths.state}/apps.sqlite`
        favouriteApps: GlobalConfig.launcher.favouriteApps
        entries: DesktopEntries.applications.values.filter(a => !Strings.testRegexList(GlobalConfig.launcher.hiddenApps, a.id))
    }

}
