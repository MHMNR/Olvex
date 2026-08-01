pragma Singleton

import Quickshell
import Olvex
import Olvex.Config
import qs.utils

Searcher {
    id: root

    property var _allAppsCache: []

    function warmCatalog(): void {
        if (_allAppsCache.length === 0)
            _allAppsCache = query("").map(e => e.entry);
    }

    function invalidateCatalog(): void {
        _allAppsCache = [];
        warmCatalog();
    }

    function launch(entry: DesktopEntry): void {
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

    function search(search: string): list<var> {
        const prefix = GlobalConfig.launcher.specialPrefix;

        if (search.startsWith(`${prefix}i `)) {
            setKeysAndWeights(["id", "name"], [0.9, 0.1]);
        } else if (search.startsWith(`${prefix}c `)) {
            setKeysAndWeights(["categories", "name"], [0.9, 0.1]);
        } else if (search.startsWith(`${prefix}d `)) {
            setKeysAndWeights(["comment", "name"], [0.9, 0.1]);
        } else if (search.startsWith(`${prefix}e `)) {
            setKeysAndWeights(["execString", "name"], [0.9, 0.1]);
        } else if (search.startsWith(`${prefix}w `)) {
            setKeysAndWeights(["startupClass", "name"], [0.9, 0.1]);
        } else if (search.startsWith(`${prefix}g `)) {
            setKeysAndWeights(["genericName", "name"], [0.9, 0.1]);
        } else if (search.startsWith(`${prefix}k `)) {
            setKeysAndWeights(["keywords", "name"], [0.9, 0.1]);
        } else {
            setKeysAndWeights(["name"], [1]);

            if (!search.startsWith(`${prefix}t `)) {
                return query(search).map(e => e.entry);
            }
        }

        const results = query(search.slice(prefix.length + 2)).map(e => e.entry);
        if (search.startsWith(`${prefix}t `))
            return results.filter(a => a.runInTerminal);
        return results;
    }

    function selector(item: var): string {
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
