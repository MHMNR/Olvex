#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QClipboard>
#include <QObject>
#include <QProcess>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QColor>
#include <QRegularExpression>
#include <QCoreApplication>
#include <QStringList>
#include <QSet>
#include <QVector>
#include <QTimer>
#include <QDebug>
#include <cstdio>

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

    bool debugHud() const { return qEnvironmentVariableIsSet("OLVEX_EMOJI_DEBUG"); }

signals:
    void paletteChanged();

private:
    struct PaletteRole {
        const char *token;
        const char *schemeKey;
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

    QVariantMap paletteFallback() const {
        QVariantMap palette;
        for (int i = 0; i < kRoleCount; ++i)
            palette.insert(QString::fromLatin1(kRoles[i].token), QString::fromLatin1(kRoles[i].defaultHex));
        return palette;
    }

    QColor schemeColour(const QJsonObject &colours, const char *key, const QColor &fallback = QColor()) const {
        const auto value = colours.value(QLatin1String(key));
        if (!value.isString())
            return fallback;
        const QColor parsed = parseHex(value.toString());
        return parsed.isValid() ? parsed : fallback;
    }

    QVariantMap paletteFromScheme(const QJsonObject &colours, const QVariantMap &fallback) const {
        auto fb = [&](const char *token) {
            return parseHex(fallback.value(QString::fromLatin1(token)).toString());
        };
        auto hex = [](const QColor &c) { return c.isValid() ? c.name(QColor::HexRgb) : QString(); };

        const QColor primary = schemeColour(colours, "primary", fb("primary"));
        QColor onPrimary = schemeColour(colours, "onPrimary", fb("fgPrimary"));
        if (!onPrimary.isValid() || (primary.lightnessF() > 0.5 && onPrimary.lightnessF() > 0.5) || (primary.lightnessF() <= 0.5 && onPrimary.lightnessF() <= 0.5)) {
            onPrimary = (primary.lightnessF() > 0.5) ? QColor(QStringLiteral("#111111")) : QColor(QStringLiteral("#FFFFFF"));
        }
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
        const QColor errorContainer = schemeColour(colours, "errorContainer", fb("errorContainer"));
        const QColor onErrorContainer = schemeColour(colours, "onErrorContainer", fb("fgErrorContainer"));

        QVariantMap palette;
        palette.insert(QStringLiteral("primary"), hex(primary));
        palette.insert(QStringLiteral("fgPrimary"), hex(onPrimary));
        palette.insert(QStringLiteral("primaryContainer"), hex(primaryContainer));
        palette.insert(QStringLiteral("fgPrimaryContainer"), hex(onPrimaryContainer));
        palette.insert(QStringLiteral("secondaryContainer"), hex(secondaryContainer));
        palette.insert(QStringLiteral("fgSecondaryContainer"), hex(onSecondaryContainer));
        palette.insert(QStringLiteral("tertiary"), hex(primary));
        palette.insert(QStringLiteral("tertiaryContainer"), hex(primaryContainer));
        palette.insert(QStringLiteral("fgTertiaryContainer"), hex(onPrimaryContainer));
        palette.insert(QStringLiteral("surface"), hex(surface));
        palette.insert(QStringLiteral("fgSurface"), hex(onSurface));
        palette.insert(QStringLiteral("fgMuted"), hex(onSurfaceVariant));
        palette.insert(QStringLiteral("rail"), hex(surface));
        palette.insert(QStringLiteral("stage"), hex(surfaceContainer));
        palette.insert(QStringLiteral("stageHigh"), hex(surfaceContainerHigh));
        palette.insert(QStringLiteral("stageContent"), hex(surfaceContainerHighest));
        palette.insert(QStringLiteral("outline"), hex(outline));
        palette.insert(QStringLiteral("outlineVariant"), hex(outlineVariant));
        palette.insert(QStringLiteral("error"), hex(error));
        palette.insert(QStringLiteral("errorContainer"), hex(errorContainer));
        palette.insert(QStringLiteral("fgErrorContainer"), hex(onErrorContainer));
        return palette;
    }

    bool loadHyprPrimaryTriplet(QVariantMap *palette) {
        QString content;
        const QString hyprSchemeConf = QDir::homePath() + QStringLiteral("/.config/hypr/scheme/current.conf");
        const QString hyprSchemeLua = QDir::homePath() + QStringLiteral("/.config/hypr/scheme/current.lua");

        QFile fileLua(hyprSchemeLua);
        QFile fileConf(hyprSchemeConf);

        if (fileLua.exists() && (!fileConf.exists() || QFileInfo(fileLua).lastModified() >= QFileInfo(fileConf).lastModified())) {
            if (fileLua.open(QIODevice::ReadOnly))
                content = QString::fromUtf8(fileLua.readAll());
        }
        if (content.isEmpty() && fileConf.open(QIODevice::ReadOnly)) {
            content = QString::fromUtf8(fileConf.readAll());
        }
        if (content.isEmpty())
            return false;

        static const QRegularExpression primaryRe(QStringLiteral(R"((?:\$primary|primary)\s*=\s*"?([0-9a-fA-F]{6}))"));
        static const QRegularExpression onPrimaryRe(QStringLiteral(R"((?:\$onPrimary|onPrimary)\s*=\s*"?([0-9a-fA-F]{6}))"));
        static const QRegularExpression containerRe(QStringLiteral(R"((?:\$primary_container|primaryContainer)\s*=\s*"?([0-9a-fA-F]{6}))"));
        static const QRegularExpression onContainerRe(QStringLiteral(R"((?:\$on_primary_container|onPrimaryContainer)\s*=\s*"?([0-9a-fA-F]{6}))"));

        const auto mPrim = primaryRe.match(content);
        if (!mPrim.hasMatch())
            return false;

        const QString primHex = QStringLiteral("#") + mPrim.captured(1).toLower();
        const QColor primCol(primHex);
        palette->insert(QStringLiteral("primary"), primHex);
        palette->insert(QStringLiteral("tertiary"), primHex);

        const auto mOnPrim = onPrimaryRe.match(content);
        if (mOnPrim.hasMatch()) {
            palette->insert(QStringLiteral("fgPrimary"), QStringLiteral("#") + mOnPrim.captured(1).toLower());
        } else if (primCol.isValid()) {
            palette->insert(QStringLiteral("fgPrimary"), primCol.lightnessF() > 0.5 ? QStringLiteral("#111111") : QStringLiteral("#ffffff"));
        }

        const auto mCont = containerRe.match(content);
        if (mCont.hasMatch()) {
            const QString contHex = QStringLiteral("#") + mCont.captured(1).toLower();
            palette->insert(QStringLiteral("primaryContainer"), contHex);
            palette->insert(QStringLiteral("tertiaryContainer"), contHex);
        }

        const auto mOnCont = onContainerRe.match(content);
        if (mOnCont.hasMatch())
            palette->insert(QStringLiteral("fgPrimaryContainer"), QStringLiteral("#") + mOnCont.captured(1).toLower());

        return true;
    }

    void reload() {
        m_activeSchemePath = schemePath();
        m_wallpaperSource = currentColourSource();

        const QVariantMap fallback = paletteFallback();
        QVariantMap resolved = fallback;
        bool loadedFromScheme = false;

        QFile schemeFile(m_activeSchemePath);
        if (schemeFile.open(QIODevice::ReadOnly)) {
            const QJsonDocument doc = QJsonDocument::fromJson(schemeFile.readAll());
            if (doc.isObject()) {
                const QJsonObject root = doc.object();
                m_schemeName = root.value(QStringLiteral("scheme")).toString(QStringLiteral("scheme-tonal-spot"));
                m_schemeMode = root.value(QStringLiteral("mode")).toString(QStringLiteral("dark"));
                const QJsonObject colours = root.value(QStringLiteral("colours")).toObject();
                if (!colours.isEmpty()) {
                    resolved = paletteFromScheme(colours, fallback);
                    loadedFromScheme = true;
                }
            }
        }

        if (!loadedFromScheme) {
            loadHyprPrimaryTriplet(&resolved);
        }

        bool changed = false;
        for (int i = 0; i < kRoleCount; ++i) {
            const QString key = QString::fromLatin1(kRoles[i].token);
            const QColor newCol = parseHex(resolved.value(key).toString());
            if (colorAt(i) != newCol) {
                changed = true;
                break;
            }
        }

        if (changed) {
            applyColors(resolved);
            emit paletteChanged();
        }

        updateWatchedPaths();
    }

    void onPathChanged(const QString &) {
        m_debounce.start();
    }

    void updateWatchedPaths() {
        const QStringList needed = {
            m_activeSchemePath,
            colourSourceCachePath(),
            wallpaperPathCachePath(),
            QDir::homePath() + QStringLiteral("/.config/hypr/scheme/current.conf"),
        };

        const QStringList current = m_watcher.files();
        for (const auto &p : current) {
            if (!needed.contains(p))
                m_watcher.removePath(p);
        }
        for (const auto &p : needed) {
            if (!p.isEmpty() && QFileInfo::exists(p) && !m_watcher.files().contains(p))
                m_watcher.addPath(p);
        }
    }

    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
    QTimer m_poll;

    QString m_activeSchemePath;
    QString m_schemeName;
    QString m_schemeMode{QStringLiteral("dark")};
    QString m_wallpaperSource;

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
    { "primary",              "primary",                 "#d0bcff" },
    { "fgPrimary",            "onPrimary",               "#381e72" },
    { "primaryContainer",     "primaryContainer",        "#4f378b" },
    { "fgPrimaryContainer",   "onPrimaryContainer",      "#eaddff" },
    { "secondaryContainer",   "secondaryContainer",      "#4a4458" },
    { "fgSecondaryContainer", "onSecondaryContainer",    "#e8def8" },
    { "tertiary",             "",                        "#efb8c8" },
    { "tertiaryContainer",    "",                        "#633b48" },
    { "fgTertiaryContainer",  "",                        "#ffd8e4" },
    { "surface",              "surface",                 "#141218" },
    { "fgSurface",            "onSurface",               "#e6e0e9" },
    { "fgMuted",              "onSurfaceVariant",        "#cac4d0" },
    { "rail",                 "",                        "#1d1b20" },
    { "stage",                "surfaceContainer",        "#211f26" },
    { "stageHigh",            "surfaceContainerHigh",    "#2b2930" },
    { "stageContent",         "surfaceContainerHighest", "#36343b" },
    { "outline",              "outline",                 "#938f99" },
    { "outlineVariant",       "outlineVariant",          "#49454f" },
    { "error",                "error",                   "#f2b8b5" },
    { "errorContainer",       "errorContainer",          "#8c1d18" },
    { "fgErrorContainer",     "",                        "#f9dedc" },
};

class EmojiBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList recentEmojis READ recentEmojis NOTIFY recentEmojisChanged)
    Q_PROPERTY(QString skinTone READ skinTone WRITE setSkinTone NOTIFY skinToneChanged)
    Q_PROPERTY(QVariantList categories READ categories NOTIFY databaseUpdated)
    Q_PROPERTY(QVariantMap keywords READ keywords NOTIFY databaseUpdated)
    Q_PROPERTY(bool isUpdating READ isUpdating NOTIFY isUpdatingChanged)
    Q_PROPERTY(QString updateStatus READ updateStatus NOTIFY updateStatusChanged)

public:
    explicit EmojiBackend(QObject *parent = nullptr) : QObject(parent) {
        loadSettings();
        loadDatabase();
    }

    QStringList recentEmojis() const { return m_recentEmojis; }
    QString skinTone() const { return m_skinTone; }
    QVariantList categories() const { return m_categories; }
    QVariantMap keywords() const { return m_keywords; }
    bool isUpdating() const { return m_isUpdating; }
    QString updateStatus() const { return m_updateStatus; }

    void setSkinTone(const QString &tone) {
        if (m_skinTone == tone)
            return;
        m_skinTone = tone;
        saveSettings();
        emit skinToneChanged();
    }

    Q_INVOKABLE void saveSkinTone(const QString &tone) {
        setSkinTone(tone);
    }

    Q_INVOKABLE void copyEmoji(const QString &emojiText, const QString &baseEmoji = QString()) {
        if (emojiText.isEmpty())
            return;

        const QString recentTarget = baseEmoji.isEmpty() ? emojiText : baseEmoji;
        m_recentEmojis.removeAll(recentTarget);
        m_recentEmojis.prepend(recentTarget);
        while (m_recentEmojis.size() > 40)
            m_recentEmojis.removeLast();

        saveSettings();
        emit recentEmojisChanged();

        // Copy to Qt clipboard (both Clipboard and Selection)
        if (QClipboard *cb = QGuiApplication::clipboard()) {
            cb->setText(emojiText, QClipboard::Clipboard);
            cb->setText(emojiText, QClipboard::Selection);
        }

        // Also run wl-copy detached so Wayland retains clipboard even after process exits
        QProcess::startDetached(QStringLiteral("wl-copy"), QStringList() << QStringLiteral("--") << emojiText);

        // Immediate graceful quit
        QTimer::singleShot(30, qApp, &QCoreApplication::quit);
    }

    Q_INVOKABLE void quit() {
        qApp->quit();
    }

    Q_INVOKABLE void rebuildDatabase() {
        if (m_isUpdating)
            return;

        m_isUpdating = true;
        m_updateStatus = QStringLiteral("Updating…");
        emit isUpdatingChanged();
        emit updateStatusChanged();

        if (!m_updateProcess) {
            m_updateProcess = new QProcess(this);
            connect(m_updateProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                    this, [this](int exitCode, QProcess::ExitStatus exitStatus) {
                m_isUpdating = false;
                if (exitStatus == QProcess::NormalExit && exitCode == 0) {
                    loadDatabase();
                    m_updateStatus = QStringLiteral("Updated!");
                } else {
                    m_updateStatus = QStringLiteral("Failed");
                }
                emit isUpdatingChanged();
                emit updateStatusChanged();

                QTimer::singleShot(3000, this, [this]() {
                    m_updateStatus.clear();
                    emit updateStatusChanged();
                });
            });
        }

        const QString scriptPath = findUpdaterScript();
        if (!scriptPath.isEmpty()) {
            m_updateProcess->start(QStringLiteral("python3"), QStringList() << scriptPath);
        } else {
            m_isUpdating = false;
            m_updateStatus = QStringLiteral("Script missing");
            emit isUpdatingChanged();
            emit updateStatusChanged();
        }
    }

    Q_INVOKABLE QStringList search(const QString &query, int limit = 160) const {
        const QString trimmed = query.trimmed();
        if (trimmed.isEmpty())
            return QStringList();

        const QString q = trimmed.toLower();
        static const QRegularExpression wsRe(QStringLiteral("\\s+"));
        const QStringList queryTokens = q.split(wsRe, Qt::SkipEmptyParts);
        if (queryTokens.isEmpty())
            return QStringList();

        const int maxMatches = qMax(1, limit);
        QStringList exactMatches;
        QStringList prefixMatches;
        QStringList substringMatches;

        const bool singleToken = (queryTokens.size() == 1);
        const QString singleQ = singleToken ? queryTokens.first() : QString();

        for (const auto &entry : m_emojiIndex) {
            if (entry.emoji == trimmed) {
                exactMatches.prepend(entry.emoji);
                continue;
            }

            if (singleToken) {
                bool isExact = false;
                bool isPrefix = false;

                for (const auto &w : entry.words) {
                    if (w == singleQ) {
                        isExact = true;
                        break;
                    }
                    if (w.startsWith(singleQ)) {
                        isPrefix = true;
                    }
                }

                if (isExact) {
                    exactMatches.append(entry.emoji);
                } else if (isPrefix) {
                    prefixMatches.append(entry.emoji);
                } else if (entry.lowerKeywords.contains(singleQ)) {
                    substringMatches.append(entry.emoji);
                }
            } else {
                bool allMatch = true;
                bool allExact = true;
                bool allPrefix = true;

                for (const auto &t : queryTokens) {
                    bool tExact = false;
                    bool tPrefix = false;

                    for (const auto &w : entry.words) {
                        if (w == t) {
                            tExact = true;
                            break;
                        }
                        if (w.startsWith(t)) {
                            tPrefix = true;
                        }
                    }

                    if (tExact) {
                        // exact match for this token
                    } else if (tPrefix) {
                        allExact = false;
                    } else if (entry.lowerKeywords.contains(t)) {
                        allExact = false;
                        allPrefix = false;
                    } else {
                        allMatch = false;
                        break;
                    }
                }

                if (allMatch) {
                    if (allExact) {
                        exactMatches.append(entry.emoji);
                    } else if (allPrefix) {
                        prefixMatches.append(entry.emoji);
                    } else {
                        substringMatches.append(entry.emoji);
                    }
                }
            }
        }

        QStringList results;
        results.reserve(qMin(maxMatches, exactMatches.size() + prefixMatches.size() + substringMatches.size()));

        for (const auto &em : exactMatches) {
            if (results.size() >= maxMatches)
                return results;
            results.append(em);
        }
        for (const auto &em : prefixMatches) {
            if (results.size() >= maxMatches)
                return results;
            results.append(em);
        }
        for (const auto &em : substringMatches) {
            if (results.size() >= maxMatches)
                return results;
            results.append(em);
        }

        return results;
    }

signals:
    void recentEmojisChanged();
    void skinToneChanged();
    void databaseUpdated();
    void isUpdatingChanged();
    void updateStatusChanged();

private:
    QString configFilePath() const {
        const QString dirPath = QDir::homePath() + QStringLiteral("/.config/olvex");
        QDir().mkpath(dirPath);
        return dirPath + QStringLiteral("/recent-emojis.json");
    }

    QString databaseFilePath() const {
        return QDir::homePath() + QStringLiteral("/.config/olvex/emojis.json");
    }

    QString findUpdaterScript() const {
        const QString appDir = QCoreApplication::applicationDirPath();
        const QStringList candidates = {
            appDir + QStringLiteral("/update_emojis.py"),
            appDir + QStringLiteral("/../share/olvex/standalone/emoji/update_emojis.py"),
            QDir::homePath() + QStringLiteral("/.local/Olvex/standalone/emoji/update_emojis.py"),
            QDir::homePath() + QStringLiteral("/Projects/QS-Config/Github/Olvex/standalone/emoji/update_emojis.py"),
            QDir::homePath() + QStringLiteral("/.config/olvex/update_emojis.py"),
        };
        for (const auto &cand : candidates) {
            if (QFileInfo::exists(cand))
                return cand;
        }
        return QString();
    }

    struct EmojiEntry {
        QString emoji;
        QString lowerKeywords;
        QStringList words;
    };

    void buildSearchIndex() {
        m_emojiIndex.clear();
        m_emojiIndex.reserve(m_keywords.size());
        static const QRegularExpression wsRe(QStringLiteral("\\s+"));
        for (auto it = m_keywords.constBegin(); it != m_keywords.constEnd(); ++it) {
            EmojiEntry entry;
            entry.emoji = it.key();
            entry.lowerKeywords = it.value().toString().toLower();
            const QStringList rawWords = entry.lowerKeywords.split(wsRe, Qt::SkipEmptyParts);
            QSet<QString> seenWords;
            entry.words.reserve(rawWords.size());
            for (const auto &w : rawWords) {
                if (!seenWords.contains(w)) {
                    seenWords.insert(w);
                    entry.words.append(w);
                }
            }
            m_emojiIndex.append(std::move(entry));
        }
    }

    void loadDatabase() {
        bool loaded = false;
        QFile file(databaseFilePath());
        if (file.open(QIODevice::ReadOnly)) {
            const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
            if (doc.isObject()) {
                const QJsonObject obj = doc.object();
                m_categories = obj.value(QStringLiteral("categories")).toArray().toVariantList();
                m_keywords = obj.value(QStringLiteral("keywords")).toObject().toVariantMap();
                if (!m_categories.isEmpty() && !m_keywords.isEmpty())
                    loaded = true;
            }
        }

        if (!loaded) {
            const QStringList fallbackCandidates = {
                QStringLiteral(":/emojis.js"),
                QDir::homePath() + QStringLiteral("/.local/Olvex/standalone/emoji/emojis.js"),
                QDir::homePath() + QStringLiteral("/Projects/QS-Config/Github/Olvex/standalone/emoji/emojis.js"),
                QCoreApplication::applicationDirPath() + QStringLiteral("/emojis.js")
            };
            for (const auto &cand : fallbackCandidates) {
                QFile jsFile(cand);
                if (jsFile.open(QIODevice::ReadOnly)) {
                    const QString content = QString::fromUtf8(jsFile.readAll());
                    static const QRegularExpression re(
                        QStringLiteral("var\\s+categories\\s*=\\s*(\\[.*?\\]);\\s*var\\s+emojiKeywords\\s*=\\s*(\\{.*?\\});"),
                        QRegularExpression::DotMatchesEverythingOption
                    );
                    auto match = re.match(content);
                    if (match.hasMatch()) {
                        m_categories = QJsonDocument::fromJson(match.captured(1).toUtf8()).array().toVariantList();
                        m_keywords = QJsonDocument::fromJson(match.captured(2).toUtf8()).object().toVariantMap();
                        loaded = true;
                        break;
                    }
                }
            }
        }

        buildSearchIndex();
        emit databaseUpdated();
    }

    void loadSettings() {
        QFile file(configFilePath());
        if (file.open(QIODevice::ReadOnly)) {
            const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
            if (doc.isObject()) {
                const QJsonObject obj = doc.object();
                m_skinTone = obj.value(QStringLiteral("skinTone")).toString();
                const QJsonArray arr = obj.value(QStringLiteral("recents")).toArray();
                m_recentEmojis.clear();
                for (const auto &v : arr) {
                    if (v.isString())
                        m_recentEmojis.append(v.toString());
                }
            }
        }
    }

    void saveSettings() {
        QJsonObject obj;
        obj.insert(QStringLiteral("skinTone"), m_skinTone);
        QJsonArray arr;
        for (const auto &em : m_recentEmojis)
            arr.append(em);
        obj.insert(QStringLiteral("recents"), arr);

        QFile file(configFilePath());
        if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            file.write(QJsonDocument(obj).toJson(QJsonDocument::Indented));
        }
    }

    QStringList m_recentEmojis;
    QString m_skinTone;
    QVariantList m_categories;
    QVariantMap m_keywords;
    QVector<EmojiEntry> m_emojiIndex;
    bool m_isUpdating{false};
    QString m_updateStatus;
    QProcess *m_updateProcess{nullptr};
};

int main(int argc, char **argv) {
    qputenv("QSG_RENDER_LOOP", "threaded");
    QGuiApplication app(argc, argv);
    app.setOrganizationName(QStringLiteral("olvex"));
    app.setApplicationName(QStringLiteral("olvex-emoji"));
    app.setApplicationDisplayName(QStringLiteral("Olvex Emoji"));

    SystemAccent systemAccent;
    EmojiBackend emojiBackend;

    QQmlApplicationEngine engine;

    QObject::connect(&engine, &QQmlEngine::warnings, [](const QList<QQmlError> &warnings) {
        for (const auto &warning : warnings)
            qWarning().noquote() << warning.toString();
    });

    engine.rootContext()->setContextProperty(QStringLiteral("SystemAccent"), &systemAccent);
    engine.rootContext()->setContextProperty(QStringLiteral("EmojiBackend"), &emojiBackend);

    const QString qmlName = QStringLiteral("EmojiStandalone.qml");
    const QString appDir = QCoreApplication::applicationDirPath();

    const QStringList candidates = {
        QDir::home().filePath(QStringLiteral(".local/Olvex/standalone/emoji/") + qmlName),
        QDir::home().filePath(QStringLiteral("Projects/QS-Config/Github/Olvex/standalone/emoji/") + qmlName),
        QDir::home().filePath(QStringLiteral("Projects/QS-Config/Olvex/standalone/emoji/") + qmlName),
        QDir::home().filePath(QStringLiteral(".config/olvex/standalone/emoji/") + qmlName),
        QDir::home().filePath(QStringLiteral(".config/quickshell/olvex/standalone/emoji/") + qmlName),
        QDir(appDir).filePath(QStringLiteral("../../../standalone/emoji/") + qmlName),
        QDir(appDir).filePath(QStringLiteral("emoji/") + qmlName),
        QDir::current().filePath(qmlName),
        QDir(appDir).filePath(qmlName),
        QStringLiteral("qrc:/") + qmlName,
    };

    for (const auto &path : candidates) {
        const bool isQrc = path.startsWith(QStringLiteral("qrc:"));
        const QString cleaned = isQrc ? path : QDir::cleanPath(path);
        if (!isQrc && !QFileInfo::exists(cleaned))
            continue;

        if (qEnvironmentVariableIsSet("OLVEX_EMOJI_DEBUG"))
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
