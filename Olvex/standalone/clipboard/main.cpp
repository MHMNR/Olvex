#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include <QObject>
#include <QProcess>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QJsonDocument>
#include <QJsonObject>
#include <QColor>
#include <QRegularExpression>
#include <QCoreApplication>
#include <QStringList>
#include <QSet>
#include <QHash>
#include <QVariantMap>
#include <QUrl>
#include <QEventLoop>
#include <QTimer>
#include <QDateTime>
#include <QElapsedTimer>
#include <QThread>
#include <QDebug>
#include <cstdio>

static void smokeLog(const char *level, const char *msg) {
    fprintf(stderr, "%s: %s\n", level, msg);
    fflush(stderr);
}

class SystemAccent : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString schemeMode READ schemeMode NOTIFY paletteChanged)
    Q_PROPERTY(QString schemeFilePath READ schemeFilePath NOTIFY paletteChanged)
    Q_PROPERTY(QColor accent READ accent NOTIFY paletteChanged)
    Q_PROPERTY(QColor accentContainer READ accentContainer NOTIFY paletteChanged)
    Q_PROPERTY(QColor onAccentContainer READ onAccentContainer NOTIFY paletteChanged)
    Q_PROPERTY(QColor primary READ primary NOTIFY paletteChanged)
    Q_PROPERTY(QColor fgPrimary READ fgPrimary NOTIFY paletteChanged)
    Q_PROPERTY(QColor primaryContainer READ primaryContainer NOTIFY paletteChanged)
    Q_PROPERTY(QColor fgPrimaryContainer READ fgPrimaryContainer NOTIFY paletteChanged)
    Q_PROPERTY(QColor secondaryContainer READ secondaryContainer NOTIFY paletteChanged)
    Q_PROPERTY(QColor fgSecondaryContainer READ fgSecondaryContainer NOTIFY paletteChanged)
    Q_PROPERTY(QColor tertiary READ tertiary NOTIFY paletteChanged)
    Q_PROPERTY(QColor tertiaryContainer READ tertiaryContainer NOTIFY paletteChanged)
    Q_PROPERTY(QColor fgTertiaryContainer READ fgTertiaryContainer NOTIFY paletteChanged)
    Q_PROPERTY(QColor surface READ surface NOTIFY paletteChanged)
    Q_PROPERTY(QColor fgSurface READ fgSurface NOTIFY paletteChanged)
    Q_PROPERTY(QColor fgMuted READ fgMuted NOTIFY paletteChanged)
    Q_PROPERTY(QColor rail READ rail NOTIFY paletteChanged)
    Q_PROPERTY(QColor stage READ stage NOTIFY paletteChanged)
    Q_PROPERTY(QColor stageHigh READ stageHigh NOTIFY paletteChanged)
    Q_PROPERTY(QColor stageContent READ stageContent NOTIFY paletteChanged)
    Q_PROPERTY(QColor outline READ outline NOTIFY paletteChanged)
    Q_PROPERTY(QColor outlineVariant READ outlineVariant NOTIFY paletteChanged)
    Q_PROPERTY(QColor error READ error NOTIFY paletteChanged)
    Q_PROPERTY(QColor errorContainer READ errorContainer NOTIFY paletteChanged)
    Q_PROPERTY(QColor fgErrorContainer READ fgErrorContainer NOTIFY paletteChanged)
    Q_PROPERTY(bool debugHud READ debugHud CONSTANT)
    Q_PROPERTY(QString schemeName READ schemeName NOTIFY paletteChanged)
    Q_PROPERTY(QString wallpaperSource READ wallpaperSource NOTIFY paletteChanged)
    Q_PROPERTY(bool transparencyEnabled READ transparencyEnabled NOTIFY paletteChanged)
    Q_PROPERTY(qreal transparencyBase READ transparencyBase NOTIFY paletteChanged)
    Q_PROPERTY(qreal transparencyLayers READ transparencyLayers NOTIFY paletteChanged)

public:
    explicit SystemAccent(QObject *parent = nullptr) : QObject(parent) {
        m_debounce.setSingleShot(true);
        m_debounce.setInterval(100);
        connect(&m_debounce, &QTimer::timeout, this, &SystemAccent::reload);
        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &SystemAccent::onPathChanged);
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &SystemAccent::onPathChanged);

        m_poll.setInterval(750);
        connect(&m_poll, &QTimer::timeout, this, &SystemAccent::reload);
        m_poll.start();

        reload();
    }

    ~SystemAccent() override = default;

    QString schemeName() const { return m_schemeName; }
    QString wallpaperSource() const { return m_wallpaperSource; }

    QString schemeMode() const { return m_schemeMode; }
    QString schemeFilePath() const { return m_activeSchemePath; }
    QColor accent() const { return m_primary; }
    QColor accentContainer() const { return m_primaryContainer; }
    QColor onAccentContainer() const { return m_fgPrimaryContainer; }
    QColor primary() const { return m_primary; }
    QColor fgPrimary() const { return m_fgPrimary; }
    QColor primaryContainer() const { return m_primaryContainer; }
    QColor fgPrimaryContainer() const { return m_fgPrimaryContainer; }
    QColor secondaryContainer() const { return m_secondaryContainer; }
    QColor fgSecondaryContainer() const { return m_fgSecondaryContainer; }
    QColor tertiary() const { return m_tertiary; }
    QColor tertiaryContainer() const { return m_tertiaryContainer; }
    QColor fgTertiaryContainer() const { return m_fgTertiaryContainer; }
    QColor surface() const { return m_surface; }
    QColor fgSurface() const { return m_fgSurface; }
    QColor fgMuted() const { return m_fgMuted; }
    QColor rail() const { return m_rail; }
    QColor stage() const { return m_stage; }
    QColor stageHigh() const { return m_stageHigh; }
    QColor stageContent() const { return m_stageContent; }
    QColor outline() const { return m_outline; }
    QColor outlineVariant() const { return m_outlineVariant; }
    QColor error() const { return m_error; }
    QColor errorContainer() const { return m_errorContainer; }
    QColor fgErrorContainer() const { return m_fgErrorContainer; }

    QString tokenHex(const QString &token) const {
        const QColor colour = colorForToken(token);
        return colour.isValid() ? colour.name(QColor::HexRgb) : QString();
    }

    bool debugHud() const { return qEnvironmentVariableIsSet("OLVEX_CLIPBOARD_DEBUG"); }
    bool transparencyEnabled() const { return m_transparencyEnabled; }
    qreal transparencyBase() const { return m_transparencyBase; }
    qreal transparencyLayers() const { return m_transparencyLayers; }

    Q_INVOKABLE QColor layerColor(const QColor &color, int layerLevel) const {
        Q_UNUSED(layerLevel);
        // Clipboard is opaque M3 only — no glassmorphism / frosted alpha layers.
        return color;
    }

signals:
    void paletteChanged();

private:
    // PaletteRole: token name, scheme.json key, default hex.
    // 14 essential tokens read from scheme.json; 7 derived at apply time.
    struct PaletteRole {
        const char *token;
        const char *schemeKey;  // "" = derived, not read from scheme.json
        const char *defaultHex;
    };

    static const PaletteRole kRoles[];
    static constexpr int kRoleCount = 21;

    static QColor parseHex(const QString &hex) {
        QString h = hex.trimmed();
        if (h.startsWith(QLatin1Char('#')))
            h = h.mid(1);
        if (h.size() == 6)
            return QColor(QStringLiteral("#") + h);
        return QColor();
    }

    static QString normalizedHex(const QString &hex) {
        const QColor colour = parseHex(hex);
        return colour.isValid() ? colour.name(QColor::HexRgb) : QString();
    }

    QColor colorForToken(const QString &token) const {
        for (int i = 0; i < kRoleCount; ++i) {
            if (token == QLatin1String(kRoles[i].token))
                return colorAt(i);
        }
        return QColor();
    }

    QColor colorAt(int index) const {
        switch (index) {
        case 0: return m_primary;
        case 1: return m_fgPrimary;
        case 2: return m_primaryContainer;
        case 3: return m_fgPrimaryContainer;
        case 4: return m_secondaryContainer;
        case 5: return m_fgSecondaryContainer;
        case 6: return m_tertiary;
        case 7: return m_tertiaryContainer;
        case 8: return m_fgTertiaryContainer;
        case 9: return m_surface;
        case 10: return m_fgSurface;
        case 11: return m_fgMuted;
        case 12: return m_rail;
        case 13: return m_stage;
        case 14: return m_stageHigh;
        case 15: return m_stageContent;
        case 16: return m_outline;
        case 17: return m_outlineVariant;
        case 18: return m_error;
        case 19: return m_errorContainer;
        case 20: return m_fgErrorContainer;
        default: return QColor();
        }
    }

    void setColorAt(int index, const QColor &colour) {
        switch (index) {
        case 0: m_primary = colour; break;
        case 1: m_fgPrimary = colour; break;
        case 2: m_primaryContainer = colour; break;
        case 3: m_fgPrimaryContainer = colour; break;
        case 4: m_secondaryContainer = colour; break;
        case 5: m_fgSecondaryContainer = colour; break;
        case 6: m_tertiary = colour; break;
        case 7: m_tertiaryContainer = colour; break;
        case 8: m_fgTertiaryContainer = colour; break;
        case 9: m_surface = colour; break;
        case 10: m_fgSurface = colour; break;
        case 11: m_fgMuted = colour; break;
        case 12: m_rail = colour; break;
        case 13: m_stage = colour; break;
        case 14: m_stageHigh = colour; break;
        case 15: m_stageContent = colour; break;
        case 16: m_outline = colour; break;
        case 17: m_outlineVariant = colour; break;
        case 18: m_error = colour; break;
        case 19: m_errorContainer = colour; break;
        case 20: m_fgErrorContainer = colour; break;
        default: break;
        }
    }

    void applyColors(const QVariantMap &colors) {
        for (int i = 0; i < kRoleCount; ++i) {
            const QString key = QString::fromLatin1(kRoles[i].token);
            setColorAt(i, parseHex(colors.value(key).toString()));
        }
    }

    QString shellConfigPath() const {
        const QString configBase = qEnvironmentVariableIsSet("XDG_CONFIG_HOME")
            ? QString::fromUtf8(qgetenv("XDG_CONFIG_HOME"))
            : QDir::homePath() + QStringLiteral("/.config");
        const QStringList candidates = {
            configBase + QStringLiteral("/olvex/shell.json"),
            configBase + QStringLiteral("/olvex-shell/shell.json"),
        };
        for (const auto &candidate : candidates) {
            if (QFileInfo::exists(candidate))
                return candidate;
        }
        return QString();
    }

    void loadShellTransparency() {
        // Standalone clipboard never inherits shell glass transparency.
        m_transparencyEnabled = false;
        m_transparencyBase = 1.0;
        m_transparencyLayers = 1.0;
    }

    QString olvexStateDir() const {
        const QString base = qEnvironmentVariableIsSet("XDG_STATE_HOME")
            ? QString::fromUtf8(qgetenv("XDG_STATE_HOME"))
            : QDir::homePath() + QStringLiteral("/.local/state");
        return base + QStringLiteral("/olvex");
    }

    QString schemePath() const {
        return olvexStateDir() + QStringLiteral("/scheme.json");
    }

    QString colourSourceCachePath() const {
        return olvexStateDir() + QStringLiteral("/wallpaper/colour-source.txt");
    }

    QString wallpaperPathCachePath() const {
        return olvexStateDir() + QStringLiteral("/wallpaper/path.txt");
    }

    static QString readTrimmedFile(const QString &path) {
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly))
            return QString();
        return QString::fromUtf8(file.readAll()).trimmed();
    }

    QString currentColourSource() const {
        QString source = readTrimmedFile(colourSourceCachePath());
        if (source.isEmpty())
            source = readTrimmedFile(wallpaperPathCachePath());
        return source;
    }

    static QString shellSingleQuote(const QString &value) {
        QString out = value;
        out.replace(QLatin1Char('\''), QStringLiteral("'\\''"));
        return out;
    }

    bool isDiskSchemeStale(const QString &) const {
        return false;
    }

    qint64 schemeMtimeMs() const {
        const QFileInfo info(schemePath());
        return info.exists() ? info.lastModified().toMSecsSinceEpoch() : 0;
    }

    QVariantMap paletteFallback() const {
        return m_paletteReady ? m_cachedPalette : defaultPalette();
    }

    bool applySchemeRoot(const QJsonObject &root, const QString &sourceLabel) {
        const auto colours = root.value(QStringLiteral("colours")).toObject();
        if (colours.isEmpty())
            return false;

        const QVariantMap next = paletteFromScheme(colours, paletteFallback());
        if (m_paletteReady && next == m_cachedPalette && m_activeSchemePath == sourceLabel)
            return false;

        const QString schemeMode = root.value(QStringLiteral("mode")).toString();
        if (!schemeMode.isEmpty())
            m_schemeMode = schemeMode;
        m_schemeName = root.value(QStringLiteral("name")).toString();
        m_activeSchemePath = sourceLabel;
        m_cachedPalette = next;
        m_paletteReady = true;
        applyColors(next);
        return true;
    }

    bool loadSchemeFile(const QString &path) {
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly))
            return false;
        const auto doc = QJsonDocument::fromJson(file.readAll());
        const bool changed = applySchemeRoot(doc.object(), path);
        if (changed)
            m_loadedSchemeMtime = QFileInfo(path).lastModified().toMSecsSinceEpoch();
        return changed;
    }

    void requestWallpaperPalette(const QString &) {}
    void onWallpaperPaletteFinished(int, QProcess::ExitStatus) {}

    QVariantMap defaultPalette() const {
        QVariantMap palette;
        for (int i = 0; i < kRoleCount; ++i)
            palette.insert(QString::fromLatin1(kRoles[i].token), QString::fromLatin1(kRoles[i].defaultHex));
        return palette;
    }

    QColor schemeColour(const QJsonObject &colours, const char *key,
                        const QColor &fallback = QColor()) const {
        const auto value = colours.value(QLatin1String(key));
        if (!value.isString())
            return fallback;
        const QColor parsed = parseHex(value.toString());
        return parsed.isValid() ? parsed : fallback;
    }

    // 14 essential scheme.json keys → 21 clipboard tokens.
    // 7 tokens (tertiary, tertiaryContainer, fgTertiaryContainer, rail, outline,
    // stageContent, fgErrorContainer) are derived from the 14 essentials.
    QVariantMap paletteFromScheme(const QJsonObject &colours, const QVariantMap &fallback) const {
        auto fb = [&](const char *token) {
            return parseHex(fallback.value(QString::fromLatin1(token)).toString());
        };
        auto hex = [](const QColor &c) { return c.isValid() ? c.name(QColor::HexRgb) : QString(); };

        const QColor primary = schemeColour(colours, "primary", fb("primary"));
        const QColor onPrimary = schemeColour(colours, "onPrimary", fb("fgPrimary"));
        const QColor primaryContainer = schemeColour(colours, "primaryContainer", fb("primaryContainer"));
        const QColor onPrimaryContainer = schemeColour(colours, "onPrimaryContainer", fb("fgPrimaryContainer"));
        const QColor secondaryContainer = schemeColour(colours, "secondaryContainer", fb("secondaryContainer"));
        const QColor onSecondaryContainer = schemeColour(colours, "onSecondaryContainer", fb("fgSecondaryContainer"));
        const QColor surface = schemeColour(colours, "surface", fb("surface"));
        const QColor onSurface = schemeColour(colours, "onSurface", fb("fgSurface"));
        const QColor onSurfaceVariant = schemeColour(colours, "onSurfaceVariant", fb("fgMuted"));
        const QColor surfaceContainer = schemeColour(colours, "surfaceContainer", fb("stage"));
        const QColor surfaceContainerHigh = schemeColour(colours, "surfaceContainerHigh", fb("stageHigh"));
        const QColor surfaceContainerHighest = schemeColour(colours, "surfaceContainerHighest", fb("stageContent"));
        const QColor outline = schemeColour(colours, "outline", fb("outline"));
        const QColor outlineVariant = schemeColour(colours, "outlineVariant", fb("outlineVariant"));
        const QColor error = schemeColour(colours, "error", fb("error"));
        const QColor onError = schemeColour(colours, "onError", fb("fgPrimary"));
        const QColor errorContainer = schemeColour(colours, "errorContainer", fb("errorContainer"));
        const QColor onErrorContainer = schemeColour(colours, "onErrorContainer", fb("fgErrorContainer"));

        QVariantMap palette;
        palette.insert(QStringLiteral("primary"), hex(primary));
        palette.insert(QStringLiteral("fgPrimary"), hex(onPrimary));
        palette.insert(QStringLiteral("primaryContainer"), hex(primaryContainer));
        palette.insert(QStringLiteral("fgPrimaryContainer"), hex(onPrimaryContainer));
        palette.insert(QStringLiteral("secondaryContainer"), hex(secondaryContainer));
        palette.insert(QStringLiteral("fgSecondaryContainer"), hex(onSecondaryContainer));
        // Derived: tertiary ≈ primary, tertiaryContainer ≈ primaryContainer
        palette.insert(QStringLiteral("tertiary"), hex(primary));
        palette.insert(QStringLiteral("tertiaryContainer"), hex(primaryContainer));
        palette.insert(QStringLiteral("fgTertiaryContainer"), hex(onPrimaryContainer));
        palette.insert(QStringLiteral("surface"), hex(surface));
        palette.insert(QStringLiteral("fgSurface"), hex(onSurface));
        palette.insert(QStringLiteral("fgMuted"), hex(onSurfaceVariant));
        // Opaque M3 surface ladder (no glass alpha)
        palette.insert(QStringLiteral("rail"), hex(surface));
        palette.insert(QStringLiteral("stage"), hex(surfaceContainer));
        palette.insert(QStringLiteral("stageHigh"), hex(surfaceContainerHigh));
        palette.insert(QStringLiteral("stageContent"), hex(surfaceContainerHighest));
        palette.insert(QStringLiteral("outline"), hex(outline));
        palette.insert(QStringLiteral("outlineVariant"), hex(outlineVariant));
        palette.insert(QStringLiteral("error"), hex(error));
        palette.insert(QStringLiteral("errorContainer"), hex(errorContainer));
        palette.insert(QStringLiteral("fgErrorContainer"), hex(onErrorContainer));
        Q_UNUSED(onError);
        return palette;
    }

    bool loadHyprPrimaryTriplet(QVariantMap *palette) {
        const QString hyprScheme = QDir::homePath()
            + QStringLiteral("/.config/hypr/scheme/current.conf");
        QFile file(hyprScheme);
        if (!file.open(QIODevice::ReadOnly))
            return false;

        const QString content = QString::fromUtf8(file.readAll());
        static const QRegularExpression primaryRe(
            QStringLiteral(R"(\$primary\s*=\s*([0-9a-fA-F]{6}))"));
        static const QRegularExpression containerRe(
            QStringLiteral(R"(\$primaryContainer\s*=\s*([0-9a-fA-F]{6}))"));
        static const QRegularExpression onContainerRe(
            QStringLiteral(R"(\$onPrimaryContainer\s*=\s*([0-9a-fA-F]{6}))"));

        const auto primaryMatch = primaryRe.match(content);
        if (!primaryMatch.hasMatch())
            return false;

        (*palette)[QStringLiteral("primary")] = normalizedHex(primaryMatch.captured(1));
        const auto containerMatch = containerRe.match(content);
        if (containerMatch.hasMatch())
            (*palette)[QStringLiteral("primaryContainer")] = normalizedHex(containerMatch.captured(1));
        const auto onContainerMatch = onContainerRe.match(content);
        if (onContainerMatch.hasMatch())
            (*palette)[QStringLiteral("fgPrimaryContainer")] = normalizedHex(onContainerMatch.captured(1));
        return true;
    }

    void watchPaths() {
        const QString dir = olvexStateDir();
        if (!dir.isEmpty() && QFileInfo::exists(dir) && !m_watcher.directories().contains(dir))
            m_watcher.addPath(dir);

        const QString wallpaperDir = olvexStateDir() + QStringLiteral("/wallpaper");
        if (!wallpaperDir.isEmpty() && QFileInfo::exists(wallpaperDir)
            && !m_watcher.directories().contains(wallpaperDir))
            m_watcher.addPath(wallpaperDir);

        const QStringList files = {
            schemePath(),
            wallpaperPathCachePath(),
            colourSourceCachePath(),
            shellConfigPath(),
        };
        for (const auto &path : files) {
            if (!path.isEmpty() && QFileInfo::exists(path) && !m_watcher.files().contains(path))
                m_watcher.addPath(path);
        }
    }

    void onPathChanged(const QString &path) {
        if (m_watcher.files().contains(path))
            m_watcher.removePath(path);
        m_debounce.start();
    }

    void reload() {
        watchPaths();
        loadShellTransparency();

        const QString colourSource = currentColourSource();
        m_wallpaperSource = colourSource;

        const qint64 schemeMtime = schemeMtimeMs();
        const bool schemeUpdatedOnDisk = schemeMtime > m_loadedSchemeMtime;
        bool changed = false;

        if (!m_paletteReady) {
            changed = loadSchemeFile(schemePath());
            if (!changed) {
                QVariantMap next = paletteFallback();
                const QString hyprScheme = QDir::homePath()
                    + QStringLiteral("/.config/hypr/scheme/current.conf");
                if (loadHyprPrimaryTriplet(&next)) {
                    m_cachedPalette = next;
                    m_activeSchemePath = hyprScheme;
                    m_paletteReady = true;
                    applyColors(next);
                    changed = true;
                } else {
                    m_cachedPalette = next;
                    m_paletteReady = true;
                    applyColors(next);
                    changed = true;
                }
            }
            if (changed)
                m_appliedColourSource = colourSource;
        } else if (schemeUpdatedOnDisk) {
            changed = loadSchemeFile(schemePath());
            if (changed) {
                m_appliedColourSource = colourSource;
            }
        }

        if (changed)
            emit paletteChanged();
    }

    QTimer m_debounce;
    QTimer m_poll;
    QFileSystemWatcher m_watcher;
    QVariantMap m_cachedPalette;
    QString m_schemeMode;
    QString m_schemeName;
    QString m_activeSchemePath;
    QString m_wallpaperSource;
    QString m_appliedColourSource;
    qint64 m_loadedSchemeMtime = 0;
    bool m_paletteReady = false;
    bool m_transparencyEnabled = false;
    qreal m_transparencyBase = 0.85;
    qreal m_transparencyLayers = 0.4;
    QColor m_primary;
    QColor m_fgPrimary;
    QColor m_primaryContainer;
    QColor m_fgPrimaryContainer;
    QColor m_secondaryContainer;
    QColor m_fgSecondaryContainer;
    QColor m_tertiary;
    QColor m_tertiaryContainer;
    QColor m_fgTertiaryContainer;
    QColor m_surface;
    QColor m_fgSurface;
    QColor m_fgMuted;
    QColor m_rail;
    QColor m_stage;
    QColor m_stageHigh;
    QColor m_stageContent;
    QColor m_outline;
    QColor m_outlineVariant;
    QColor m_error;
    QColor m_errorContainer;
    QColor m_fgErrorContainer;
};

const SystemAccent::PaletteRole SystemAccent::kRoles[] = {
    {"primary", "primary", "#CFBCFF"},
    {"fgPrimary", "onPrimary", "#381E72"},
    {"primaryContainer", "primaryContainer", "#4F378A"},
    {"fgPrimaryContainer", "onPrimaryContainer", "#E9DDFF"},
    {"secondaryContainer", "secondaryContainer", "#4A4458"},
    {"fgSecondaryContainer", "onSecondaryContainer", "#E8DEF8"},
    {"tertiary", "tertiary", "#EFB8C8"},
    {"tertiaryContainer", "tertiaryContainer", "#633B48"},
    {"fgTertiaryContainer", "onTertiaryContainer", "#FFD8E4"},
    {"surface", "surface", "#141218"},
    {"fgSurface", "onSurface", "#E6E1E5"},
    {"fgMuted", "onSurfaceVariant", "#CAC4D0"},
    {"rail", "surfaceContainerLowest", "#0F0D13"},
    {"stage", "surfaceContainer", "#211F26"},
    {"stageHigh", "surfaceContainerHigh", "#2B2930"},
    {"stageContent", "surfaceContainerHighest", "#36343B"},
    {"outline", "outline", "#938F99"},
    {"outlineVariant", "outlineVariant", "#49454F"},
    {"error", "error", "#F2B8B5"},
    {"errorContainer", "errorContainer", "#8C1D18"},
    {"fgErrorContainer", "onErrorContainer", "#F9DEDC"},
};

static QString defaultCliphistDbPath() {
    return QDir::homePath() + QStringLiteral("/.cache/cliphist/db");
}

static QString parseCliphistDbPathFromVersionOutput(const QByteArray &output) {
    static const QRegularExpression re(QStringLiteral(R"(db-path\s*(\S+))"));
    const QStringList lines = QString::fromUtf8(output).split(QLatin1Char('\n'));
    for (const auto &line : lines) {
        const auto match = re.match(line.trimmed());
        if (match.hasMatch()) {
            const QString path = match.captured(1).trimmed();
            if (!path.isEmpty())
                return path;
        }
    }
    return {};
}

class ClipboardBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList entries READ entries NOTIFY entriesChanged)
    Q_PROPERTY(QVariantList items READ items NOTIFY entriesChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool hasError READ hasError NOTIFY errorChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorChanged)
    Q_PROPERTY(QString dbPath READ dbPath CONSTANT)

public:
    explicit ClipboardBackend(QObject *parent = nullptr) : QObject(parent) {
        m_refreshProc.setParent(this);
        connect(&m_refreshProc, &QProcess::finished, this, &ClipboardBackend::onRefreshFinished);

        // Use default immediately — probing cliphist version synchronously blocked startup.
        m_dbPath = defaultCliphistDbPath();
        m_refreshDebounce.setSingleShot(true);
        m_refreshDebounce.setInterval(200);
        connect(&m_refreshDebounce, &QTimer::timeout, this, &ClipboardBackend::refresh);

        connect(&m_dbWatcher, &QFileSystemWatcher::fileChanged, this,
                &ClipboardBackend::onDbPathChanged);
        connect(&m_dbWatcher, &QFileSystemWatcher::directoryChanged, this,
                &ClipboardBackend::onDbPathChanged);
        ensureDbWatch();
        QTimer::singleShot(0, this, &ClipboardBackend::refresh);
        QTimer::singleShot(0, this, &ClipboardBackend::probeDbPathAsync);
    }

    QStringList entries() const { return m_entries; }
    QVariantList items() const { return m_items; }
    bool loading() const { return m_loading; }
    bool hasError() const { return m_error; }
    QString errorMessage() const { return m_errorMessage; }
    QString dbPath() const { return m_dbPath; }

    Q_INVOKABLE void refresh() {
        if (m_refreshProc.state() != QProcess::NotRunning) {
            m_refreshPending = true;
            return;
        }

        setLoading(true);
        setError(false, QString());

        m_refreshProc.setProgram(QStringLiteral("cliphist"));
        m_refreshProc.setArguments(cliphistArgs({QStringLiteral("list")}));
        m_refreshProc.start();
    }

    Q_INVOKABLE bool entryIsImage(const QString &entry) const {
        static const QRegularExpression re(QStringLiteral(R"(^(\d+)\t\[\[.*binary data.*\d+x\d+.*\]\]$)"));
        return re.match(entry).hasMatch();
    }

    Q_INVOKABLE QString entryId(const QString &entry) const {
        const qsizetype idx = entry.indexOf('\t');
        if (idx <= 0) return QString();
        return entry.left(idx).trimmed();
    }

    Q_INVOKABLE void copy(const QString &entry) {
        if (entry.isEmpty())
            return;

        const QString id = entryId(entry);
        if (!id.isEmpty()) {
            const QString cmd = QStringLiteral("cliphist %1decode %2 | wl-copy")
                                    .arg(cliphistDbShellPrefix(), id);
            runBash(cmd);
        } else {
            QProcess proc;
            proc.setProgram(QStringLiteral("bash"));
            proc.setArguments({QStringLiteral("-lc"), QStringLiteral("cliphist %1decode | wl-copy").arg(cliphistDbShellPrefix())});
            proc.start();
            proc.write(entry.toUtf8());
            proc.closeWriteChannel();
            proc.waitForFinished(3000);
        }
        scheduleRefresh();
    }

    Q_INVOKABLE void copyText(const QString &text) {
        if (text.isEmpty())
            return;

        QProcess proc;
        proc.setProgram(QStringLiteral("wl-copy"));
        proc.start();
        proc.write(text.toUtf8());
        proc.closeWriteChannel();
        proc.waitForFinished(3000);
        scheduleRefresh();
    }

    Q_INVOKABLE void deleteEntry(const QString &entry) {
        if (entry.isEmpty())
            return;

        const QString id = entryId(entry);
        if (!id.isEmpty()) {
            const QString cmd = QStringLiteral("cliphist %1delete %2")
                                    .arg(cliphistDbShellPrefix(), id);
            runBash(cmd);
        } else {
            QProcess proc;
            proc.setProgram(QStringLiteral("bash"));
            proc.setArguments({QStringLiteral("-lc"), QStringLiteral("cliphist %1delete").arg(cliphistDbShellPrefix())});
            proc.start();
            proc.write(entry.toUtf8());
            proc.closeWriteChannel();
            proc.waitForFinished(3000);
        }
        refresh();
    }

    Q_INVOKABLE void wipe() {
        const QString cmd = QStringLiteral("cliphist %1wipe").arg(cliphistDbShellPrefix());
        runBash(cmd);
        refresh();
    }

    Q_INVOKABLE QString decodeTextById(const QString &id) {
        if (id.isEmpty())
            return QString();

        QProcess proc;
        proc.setProgram(QStringLiteral("cliphist"));
        proc.setArguments(cliphistArgs({QStringLiteral("decode"), id}));
        proc.start();

        if (!proc.waitForFinished(10000))
            return QString();

        if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0)
            return QString();

        return QString::fromUtf8(proc.readAllStandardOutput());
    }

    Q_INVOKABLE QString decodeText(const QString &entry) {
        if (entry.isEmpty())
            return QString();

        const qsizetype tab = entry.indexOf(QLatin1Char('\t'));
        if (tab > 0) {
            const QString id = entry.left(tab).trimmed();
            const QString byId = decodeTextById(id);
            if (!byId.isEmpty())
                return byId;
        }

        const QString escaped = shellSingleQuoteEscape(entry);

        QProcess proc;
        proc.setProgram(QStringLiteral("bash"));
        proc.setArguments({QStringLiteral("-lc"),
                           QStringLiteral("printf '%%s' '%1' | cliphist %2decode")
                               .arg(escaped, cliphistDbShellPrefix())});
        proc.start();

        if (!proc.waitForFinished(10000))
            return QString();

        if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0)
            return QString();

        return QString::fromUtf8(proc.readAllStandardOutput());
    }

    Q_INVOKABLE QString decodeImageById(const QString &id, const QString &outPngPath) {
        if (id.isEmpty() || outPngPath.isEmpty())
            return QString();

        QDir().mkpath(QFileInfo(outPngPath).absolutePath());

        const QFileInfo existing(outPngPath);
        if (existing.isFile() && existing.size() > 0)
            return outPngPath;

        QProcess proc;
        proc.setProgram(QStringLiteral("cliphist"));
        proc.setArguments(cliphistArgs({QStringLiteral("decode"), id}));
        proc.start();

        if (!proc.waitForFinished(30000))
            return QString();

        if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0)
            return QString();

        const QByteArray data = proc.readAllStandardOutput();
        if (data.isEmpty())
            return QString();

        QFile out(outPngPath);
        if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate))
            return QString();

        if (out.write(data) != data.size()) {
            out.close();
            QFile::remove(outPngPath);
            return QString();
        }

        out.close();
        return outPngPath;
    }

    Q_INVOKABLE QString decodeImageTo(const QString &entry, const QString &outPngPath) {
        if (entry.isEmpty() || outPngPath.isEmpty())
            return QString();

        const qsizetype tab = entry.indexOf(QLatin1Char('\t'));
        if (tab > 0) {
            const QString byId = decodeImageById(entry.left(tab).trimmed(), outPngPath);
            if (!byId.isEmpty())
                return byId;
        }

        const QString escaped = shellSingleQuoteEscape(entry);

        QDir().mkpath(QFileInfo(outPngPath).absolutePath());

        const QString cmd = QStringLiteral("printf '%%s' '%1' | cliphist %3decode > '%2'")
                                 .arg(escaped, outPngPath, cliphistDbShellPrefix());
        runBash(cmd);

        const QFileInfo written(outPngPath);
        return written.isFile() && written.size() > 0 ? outPngPath : QString();
    }

    Q_INVOKABLE void requestDecodeTextById(const QString &id) {
        if (id.isEmpty() || m_pendingTextDecode.contains(id))
            return;

        m_pendingTextDecode.insert(id);
        auto *proc = new QProcess(this);
        proc->setProgram(QStringLiteral("cliphist"));
        proc->setArguments(cliphistArgs({QStringLiteral("decode"), id}));
        connect(proc, &QProcess::finished, this, [this, id, proc](int exitCode, QProcess::ExitStatus st) {
            m_pendingTextDecode.remove(id);
            QString text;
            if (st == QProcess::NormalExit && exitCode == 0)
                text = QString::fromUtf8(proc->readAllStandardOutput());
            emit textDecoded(id, text);
            proc->deleteLater();
        });
        proc->start();
    }

    Q_INVOKABLE void requestDecodeImageById(const QString &id, const QString &outPngPath) {
        if (id.isEmpty() || outPngPath.isEmpty())
            return;

        const QFileInfo existing(outPngPath);
        if (existing.isFile() && existing.size() > 0) {
            emit imageDecoded(id, outPngPath, true);
            return;
        }

        const QString key = id + QLatin1Char('\n') + outPngPath;
        if (m_pendingImageDecode.contains(key))
            return;

        QDir().mkpath(QFileInfo(outPngPath).absolutePath());
        m_pendingImageDecode.insert(key);

        auto *proc = new QProcess(this);
        proc->setProgram(QStringLiteral("cliphist"));
        proc->setArguments(cliphistArgs({QStringLiteral("decode"), id}));
        connect(proc, &QProcess::finished, this, [this, id, outPngPath, key, proc](int exitCode, QProcess::ExitStatus st) {
            m_pendingImageDecode.remove(key);
            bool ok = false;
            if (st == QProcess::NormalExit && exitCode == 0) {
                const QByteArray data = proc->readAllStandardOutput();
                if (!data.isEmpty()) {
                    QFile out(outPngPath);
                    if (out.open(QIODevice::WriteOnly | QIODevice::Truncate)
                        && out.write(data) == data.size()) {
                        out.close();
                        ok = true;
                    } else {
                        out.close();
                        QFile::remove(outPngPath);
                    }
                }
            }
            emit imageDecoded(id, outPngPath, ok);
            proc->deleteLater();
        });
        proc->start();
    }

signals:
    void entriesChanged();
    void loadingChanged();
    void errorChanged();
    void textDecoded(const QString &id, const QString &text);
    void imageDecoded(const QString &id, const QString &path, bool ok);

private slots:
    void onDbPathChanged(const QString &path) {
        Q_UNUSED(path);
        ensureDbWatch();
        scheduleRefresh();
    }

    void scheduleRefresh() { m_refreshDebounce.start(); }

private:
    void onRefreshFinished(int exitCode, QProcess::ExitStatus exitStatus) {
        setLoading(false);

        if (exitStatus != QProcess::NormalExit || exitCode != 0) {
            setError(true, QStringLiteral("cliphist list failed"));
            emit entriesChanged();
            return;
        }

        m_entries.clear();
        m_items.clear();

        const QString out = QString::fromUtf8(m_refreshProc.readAllStandardOutput());
        const QStringList lines = out.split(QLatin1Char('\n'), Qt::KeepEmptyParts);
        QSet<QString> seenIds;

        for (const auto &line : lines) {
            if (line.trimmed().isEmpty())
                continue;

            m_entries.push_back(line);

            const qsizetype tab = line.indexOf(QLatin1Char('\t'));
            if (tab <= 0)
                continue;

            const QString entryId = line.left(tab).trimmed();
            if (entryId.isEmpty() || seenIds.contains(entryId))
                continue;
            seenIds.insert(entryId);

            const QString entryPreview = line.mid(tab + 1).trimmed();

            QVariantMap item;
            item.insert(QStringLiteral("entryId"), entryId);
            item.insert(QStringLiteral("entryPreview"), entryPreview);
            item.insert(QStringLiteral("entryRaw"), line);
            item.insert(QStringLiteral("entryText"), entryPreview);
            item.insert(QStringLiteral("isImage"), entryIsImage(line));
            item.insert(QStringLiteral("imagePath"), QString());
            item.insert(QStringLiteral("decoded"), false);
            item.insert(QStringLiteral("edited"), false);
            m_items.push_back(item);
        }

        emit entriesChanged();

        if (m_refreshPending) {
            m_refreshPending = false;
            QTimer::singleShot(0, this, &ClipboardBackend::refresh);
        }
    }

    void setLoading(bool on) {
        if (m_loading == on)
            return;
        m_loading = on;
        emit loadingChanged();
    }
    static QString shellSingleQuoteEscape(const QString &s) {
        // Safe for embedding in single quotes: abc'd -> 'abc'"'"'d'
        // For our usage, we return a string that is already safe when placed inside single quotes.
        QString out = s;
        out.replace('\'', QStringLiteral("'\\''"));
        return out;
    }

    void setError(bool on, const QString &msg) {
        m_error = on;
        m_errorMessage = msg;
        emit errorChanged();
    }

    void runBash(const QString &cmd) {
        QProcess proc;
        proc.setProgram(QStringLiteral("bash"));
        proc.setArguments({QStringLiteral("-lc"), cmd});
        proc.start();
        proc.waitForFinished(6000);
    }

    QStringList cliphistArgs(const QStringList &command) const {
        QStringList args;
        if (!m_dbPath.isEmpty()) {
            args << QStringLiteral("-db-path") << m_dbPath;
        }
        args += command;
        return args;
    }

    QString cliphistDbShellPrefix() const {
        if (m_dbPath.isEmpty())
            return QString();
        return QStringLiteral("-db-path '%1' ").arg(shellSingleQuoteEscape(m_dbPath));
    }

    void ensureDbWatch() {
        const QFileInfo info(m_dbPath);
        const QString dir = info.absolutePath();
        if (!dir.isEmpty() && QFileInfo::exists(dir) && !m_dbWatcher.directories().contains(dir))
            m_dbWatcher.addPath(dir);
        if (info.exists() && !m_dbWatcher.files().contains(m_dbPath))
            m_dbWatcher.addPath(m_dbPath);
    }

    void probeDbPathAsync() {
        auto *proc = new QProcess(this);
        proc->setProgram(QStringLiteral("cliphist"));
        proc->setArguments({QStringLiteral("version")});
        connect(proc, &QProcess::finished, this, [this, proc](int exitCode, QProcess::ExitStatus st) {
            if (st == QProcess::NormalExit && exitCode == 0) {
                const QString resolved = parseCliphistDbPathFromVersionOutput(proc->readAllStandardOutput());
                if (!resolved.isEmpty() && resolved != m_dbPath) {
                    m_dbPath = resolved;
                    ensureDbWatch();
                    refresh();
                }
            }
            proc->deleteLater();
        });
        proc->start();
    }

private:
    QProcess m_refreshProc;
    QFileSystemWatcher m_dbWatcher;
    QTimer m_refreshDebounce;
    QString m_dbPath;
    QStringList m_entries;
    QVariantList m_items;
    QSet<QString> m_pendingTextDecode;
    QSet<QString> m_pendingImageDecode;
    bool m_loading = false;
    bool m_error = false;
    bool m_refreshPending = false;
    QString m_errorMessage;
};

static bool waitForRefresh(ClipboardBackend &backend, int timeoutMs = 15000) {
    QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
    if (!backend.loading())
        return true;

    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);
    timer.setInterval(timeoutMs);
    QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(&backend, &ClipboardBackend::entriesChanged, &loop, &QEventLoop::quit);
    QObject::connect(&backend, &ClipboardBackend::loadingChanged, &loop, [&]() {
        if (!backend.loading())
            loop.quit();
    });
    timer.start();
    loop.exec();
    return !backend.loading();
}

static int runSmokeTest(ClipboardBackend &backend) {
    int failures = 0;
    const auto pass = [](const char *msg) { smokeLog("PASS", msg); };
    const auto fail = [&](const char *msg) {
        smokeLog("FAIL", msg);
        ++failures;
    };

    SystemAccent accent;
    QCoreApplication::processEvents(QEventLoop::AllEvents, 500);
    const QString primary = accent.tokenHex(QStringLiteral("primary"));
    if (primary.isEmpty() || !QColor(primary).isValid()) {
        fail("system palette primary invalid");
    } else {
        pass("system palette loaded");
        fprintf(stderr, "INFO: palette.primary=%s mode=%s\n",
                primary.toUtf8().constData(),
                accent.schemeMode().toUtf8().constData());
        fflush(stderr);
    }

    backend.refresh();
    if (!waitForRefresh(backend)) {
        fail("cliphist list timed out");
        return failures > 0 ? 1 : 0;
    }

    if (backend.hasError()) {
        fail("cliphist list returned an error");
        return 1;
    }

    pass("cliphist list refresh");
    fprintf(stderr, "INFO: entries=%lld\n", static_cast<long long>(backend.entries().size()));
    fflush(stderr);

    const QString marker = QStringLiteral("OLVEX_CLIPBOARD_SMOKE_")
        + QString::number(QDateTime::currentMSecsSinceEpoch());
    backend.copyText(marker);
    QThread::msleep(800);

    backend.refresh();
    if (!waitForRefresh(backend)) {
        fail("refresh after copyText timed out");
        return 1;
    }

    QString markerEntry;
    for (const auto &entry : backend.entries()) {
        if (entry.contains(marker)) {
            markerEntry = entry;
            break;
        }
    }

    if (markerEntry.isEmpty()) {
        fail("copied marker not found in cliphist list");
    } else {
        pass("list contains copied text entry");

        const QString decoded = backend.decodeText(markerEntry);
        if (!decoded.contains(marker)) {
            fail("decodeText did not return marker payload");
        } else {
            pass("decodeText");
        }

        backend.deleteEntry(markerEntry);
        if (!waitForRefresh(backend)) {
            fail("refresh after deleteEntry timed out");
        }

        bool stillPresent = false;
        for (const auto &entry : backend.entries()) {
            if (entry.contains(marker)) {
                stillPresent = true;
                break;
            }
        }

        if (stillPresent) {
            fail("deleteEntry did not remove marker");
        } else {
            pass("deleteEntry");
        }

        const QString copyMarker = QStringLiteral("OLVEX_CLIPBOARD_COPY_")
            + QString::number(QDateTime::currentMSecsSinceEpoch());
        backend.copyText(copyMarker);
        QThread::msleep(800);
        backend.refresh();
        if (!waitForRefresh(backend)) {
            fail("refresh after copy-marker timed out");
        }

        QString copyEntry;
        for (const auto &entry : backend.entries()) {
            if (entry.contains(copyMarker)) {
                copyEntry = entry;
                break;
            }
        }

        if (copyEntry.isEmpty()) {
            fail("copy pipeline setup marker missing");
        } else {
            backend.copy(copyEntry);
            pass("copy entry pipeline");
            backend.copyText(QStringLiteral("OLVEX_CLIPBOARD_NEUTRAL"));
            QThread::msleep(300);
            backend.deleteEntry(copyEntry);
            waitForRefresh(backend);
        }
    }

    QString imageEntry;
    for (const auto &entry : backend.entries()) {
        if (backend.entryIsImage(entry)) {
            imageEntry = entry;
            break;
        }
    }

    if (imageEntry.isEmpty()) {
        smokeLog("SKIP", "no image entry in cliphist history");
    } else {
        const QString outPath = QDir::tempPath()
            + QStringLiteral("/olvex-clipboard-smoke-")
            + QString::number(QDateTime::currentMSecsSinceEpoch())
            + QStringLiteral(".png");
        const QString decodedPath = backend.decodeImageTo(imageEntry, outPath);
        if (decodedPath.isEmpty() || !QFileInfo::exists(decodedPath)) {
            fail("decodeImageTo did not produce a PNG");
        } else {
            pass("decodeImageTo");
            QFile::remove(decodedPath);
        }
    }

    const QString wipeMarker = QStringLiteral("OLVEX_CLIPBOARD_WIPE_")
        + QString::number(QDateTime::currentMSecsSinceEpoch());
    backend.copyText(wipeMarker);
    QThread::msleep(800);
    backend.refresh();
    if (!waitForRefresh(backend)) {
        fail("refresh before wipe timed out");
    }

    QString wipeEntry;
    for (const auto &entry : backend.entries()) {
        if (entry.contains(wipeMarker)) {
            wipeEntry = entry;
            break;
        }
    }

    if (wipeEntry.isEmpty()) {
        fail("wipe setup marker missing");
    } else {
        backend.wipe();
        if (!waitForRefresh(backend)) {
            fail("refresh after wipe timed out");
        }

        if (backend.entries().contains(wipeEntry)) {
            fail("wipe did not clear marker entry");
        } else {
            pass("wipe");
        }
    }

    if (failures == 0) {
        smokeLog("SMOKE", "OK");
        return 0;
    }

    fprintf(stderr, "SMOKE_FAILED failures=%d\n", failures);
    fflush(stderr);
    return 1;
}

static int printPalette(SystemAccent &accent) {
    QCoreApplication::processEvents(QEventLoop::AllEvents, 500);

    fprintf(stderr, "wallpaper=%s\n", accent.wallpaperSource().toUtf8().constData());
    fprintf(stderr, "scheme_file=%s\n", accent.schemeFilePath().toUtf8().constData());
    fprintf(stderr, "scheme_mode=%s\n", accent.schemeMode().toUtf8().constData());
    fprintf(stderr, "scheme_name=%s\n", accent.schemeName().toUtf8().constData());
    fprintf(stderr, "primary=%s\n", accent.tokenHex(QStringLiteral("primary")).toUtf8().constData());
    fprintf(stderr, "surface=%s\n", accent.tokenHex(QStringLiteral("surface")).toUtf8().constData());
    fprintf(stderr, "rail=%s\n", accent.tokenHex(QStringLiteral("rail")).toUtf8().constData());
    fflush(stderr);
    return accent.tokenHex(QStringLiteral("primary")).isEmpty() ? 1 : 0;
}

int main(int argc, char **argv) {
    qputenv("QSG_RENDER_LOOP", "threaded");
    QGuiApplication app(argc, argv);
    app.setOrganizationName(QStringLiteral("olvex"));
    app.setApplicationName(QStringLiteral("olvex-clipboard"));
    app.setApplicationDisplayName(QStringLiteral("Olvex Clipboard"));

    ClipboardBackend backend;
    SystemAccent systemAccent;
    const bool smokeTest = app.arguments().contains(QStringLiteral("--smoke-test"));
    const bool printPaletteMode = app.arguments().contains(QStringLiteral("--print-palette"));
    if (printPaletteMode)
        return printPalette(systemAccent);
    if (smokeTest)
        return runSmokeTest(backend);

    QQmlApplicationEngine engine;

    QObject::connect(&engine, &QQmlEngine::warnings, [](const QList<QQmlError> &warnings) {
        for (const auto &warning : warnings)
            qWarning().noquote() << warning.toString();
    });

    engine.rootContext()->setContextProperty(QStringLiteral("ClipboardBackend"), &backend);
    engine.rootContext()->setContextProperty(QStringLiteral("Cliphist"), &backend);
    engine.rootContext()->setContextProperty(QStringLiteral("SystemAccent"), &systemAccent);

    const QString qmlName = QStringLiteral("ClipboardStandalone.qml");
    const QString appDir = QCoreApplication::applicationDirPath();

    const QStringList candidates = {
        QDir(appDir).filePath(QStringLiteral("../../../standalone/clipboard/") + qmlName),
        QDir(appDir).filePath(QStringLiteral("../../etc/xdg/quickshell/olvex/standalone/clipboard/") + qmlName),
        QDir(appDir).filePath(QStringLiteral("../share/olvex/standalone/clipboard/") + qmlName),
        QDir(appDir).filePath(QStringLiteral("../../standalone/clipboard/") + qmlName),
        QDir(appDir).filePath(QStringLiteral("clipboard/") + qmlName),
        QDir::current().filePath(qmlName),
        QDir(appDir).filePath(qmlName),
        QStringLiteral("qrc:/") + qmlName,
    };

    for (const auto &path : candidates) {
        const bool isQrc = path.startsWith(QStringLiteral("qrc:"));
        const QString cleaned = isQrc ? path : QDir::cleanPath(path);
        if (!isQrc && !QFileInfo::exists(cleaned))
            continue;

        if (qEnvironmentVariableIsSet("OLVEX_CLIPBOARD_DEBUG"))
            qInfo().noquote() << QStringLiteral("Loading QML:") << cleaned;

        engine.load(isQrc ? QUrl(cleaned) : QUrl::fromLocalFile(cleaned));
        if (!engine.rootObjects().isEmpty())
            break;
    }

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}

#include "main.moc"
