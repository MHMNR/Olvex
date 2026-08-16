import QtQuick
import Quickshell
import Olvex

Singleton {
    required property var catalog
    readonly property var list: catalog
    property string key: "name"
    property bool useFuzzy: false
    property var extraOpts: ({})
    property var beforeQuery: null

    // Extra stuff for fuzzy / multi-key
    property list<string> keys: [key]
    property list<real> weights: [1]

    function transformSearch(search: string): string {
        return search;
    }

    function query(search: string): list<var> {
        if (beforeQuery)
            beforeQuery();
        search = transformSearch(search);
        if (!search || !search.trim())
            return [...catalog];

        return FuzzySearcher.query(search, catalog, key, keys, weights);
    }
}
