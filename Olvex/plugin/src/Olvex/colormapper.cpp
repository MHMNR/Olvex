#include "colormapper.hpp"

#include <QJsonDocument>
#include <QRegularExpression>
#include <QSet>

namespace olvex {

static const QSet<QString> PALETTE_PROPS = {
    "m3primary", "m3onPrimary", "m3primaryContainer", "m3onPrimaryContainer",
    "m3secondary", "m3onSecondary", "m3secondaryContainer", "m3onSecondaryContainer",
    "m3tertiary", "m3onTertiary", "m3tertiaryContainer", "m3onTertiaryContainer",
    "m3error", "m3onError", "m3errorContainer", "m3onErrorContainer",
    "m3background", "m3onBackground", "m3surface", "m3onSurface",
    "m3surfaceVariant", "m3onSurfaceVariant", "m3surfaceDim", "m3surfaceBright",
    "m3surfaceContainerLowest", "m3surfaceContainerLow", "m3surfaceContainer",
    "m3surfaceContainerHigh", "m3surfaceContainerHighest",
    "m3inverseSurface", "m3inverseOnSurface", "m3inversePrimary",
    "m3outline", "m3outlineVariant", "m3shadow", "m3scrim", "m3surfaceTint",
    "m3success", "m3onSuccess", "m3successContainer", "m3onSuccessContainer"
};

static const QSet<QString> KONSOLE_PROPS = {
    "klink", "klinkSelection", "kvisited", "kvisitedSelection",
    "knegative", "knegativeSelection", "kneutral", "kneutralSelection",
    "kpositive", "kpositiveSelection"
};

M3ColorMapper::M3ColorMapper(QObject* parent)
    : QObject(parent) {}

QString M3ColorMapper::hexColour(const QString& value) {
    if (value.isEmpty()) return {};
    const QString raw = value.trimmed();
    if (raw.startsWith('#')) return raw;
    return "#" + raw;
}

QString M3ColorMapper::snakeToM3Prop(const QString& name) {
    QString camel;
    bool capNext = false;
    for (const QChar c : name) {
        if (c == '_') {
            capNext = true;
        } else if (capNext) {
            camel += c.toUpper();
            capNext = false;
        } else {
            camel += c;
        }
    }
    if (camel.startsWith("term") || camel.startsWith("k")) {
        return camel;
    }
    return "m3" + (camel.startsWith("m3") ? camel.mid(2) : camel);
}

bool M3ColorMapper::mapsToPalette(const QString& name) {
    if (KONSOLE_PROPS.contains(name)) return true;
    return PALETTE_PROPS.contains(snakeToM3Prop(name));
}

QJsonObject M3ColorMapper::filterScheme(const QJsonObject& scheme) {
    if (scheme.isEmpty() || !scheme.contains("colours")) {
        return scheme;
    }

    const QJsonObject rawColours = scheme.value("colours").toObject();
    QJsonObject filteredColours;

    for (auto it = rawColours.constBegin(); it != rawColours.constEnd(); ++it) {
        if (mapsToPalette(it.key())) {
            filteredColours.insert(it.key(), it.value());
        }
    }

    QJsonObject res = scheme;
    res.insert("colours", filteredColours);
    return res;
}

QJsonObject M3ColorMapper::parseSchemePayloadRaw(const QString& data) {
    if (data.trimmed().isEmpty()) return {};

    const QString trimmed = data.trimmed();
    if (trimmed.startsWith('{')) {
        const auto doc = QJsonDocument::fromJson(trimmed.toUtf8());
        if (doc.isObject()) return doc.object();
    }

    static const QRegularExpression regex("\\{[\\s\\S]*\\}");
    const auto match = regex.match(trimmed);
    if (match.hasMatch()) {
        const auto doc = QJsonDocument::fromJson(match.captured(0).toUtf8());
        if (doc.isObject()) return doc.object();
    }

    return {};
}

QJsonObject M3ColorMapper::parseSchemePayload(const QString& data) const {
    const auto scheme = parseSchemePayloadRaw(data);
    return scheme.isEmpty() ? QJsonObject{} : filterScheme(scheme);
}

QString M3ColorMapper::stringifySchemePayload(const QString& data) const {
    const auto scheme = parseSchemePayload(data);
    if (scheme.isEmpty()) return {};
    return QString::fromUtf8(QJsonDocument(scheme).toJson(QJsonDocument::Compact));
}

QString M3ColorMapper::extractPrimaryColour(const QJsonObject& scheme) const {
    const auto colours = scheme.value("colours").toObject();
    if (colours.isEmpty()) return {};

    QString raw = colours.value("primary").toString();
    if (raw.isEmpty()) raw = colours.value("m3primary").toString();
    if (raw.isEmpty()) return {};
    return hexColour(raw);
}

QString M3ColorMapper::schemeColour(const QJsonObject& scheme, const QStringList& keys) const {
    const auto colours = scheme.value("colours").toObject();
    if (colours.isEmpty()) return {};

    for (const auto& key : keys) {
        const auto val = colours.value(key);
        if (!val.isUndefined() && !val.isNull() && !val.toString().isEmpty()) {
            return hexColour(val.toString());
        }
    }
    return {};
}

bool M3ColorMapper::applySchemeToPalette(QObject* palette, const QJsonObject& scheme) const {
    if (!palette || scheme.isEmpty() || !scheme.contains("colours")) return false;

    const auto colours = scheme.value("colours").toObject();
    for (auto it = colours.constBegin(); it != colours.constEnd(); ++it) {
        const QString prop = snakeToM3Prop(it.key());
        const QString val = hexColour(it.value().toString());
        palette->setProperty(prop.toUtf8().constData(), val);
    }
    return true;
}

QJsonObject M3ColorMapper::fallbackScheme() const {
    QJsonObject colours;
    colours.insert("m3primary", "#CFBCFF");
    colours.insert("m3onPrimary", "#381E72");
    colours.insert("m3primaryContainer", "#4F378A");
    colours.insert("m3onPrimaryContainer", "#E9DDFF");
    colours.insert("m3secondary", "#CCC2DC");
    colours.insert("m3onSecondary", "#332D41");
    colours.insert("m3secondaryContainer", "#4A4458");
    colours.insert("m3onSecondaryContainer", "#E8DEF8");
    colours.insert("m3tertiary", "#EFB8C8");
    colours.insert("m3onTertiary", "#492532");
    colours.insert("m3tertiaryContainer", "#633B48");
    colours.insert("m3onTertiaryContainer", "#FFD8E4");
    colours.insert("m3error", "#F2B8B5");
    colours.insert("m3onError", "#601410");
    colours.insert("m3errorContainer", "#8C1D18");
    colours.insert("m3onErrorContainer", "#F9DEDC");
    colours.insert("m3background", "#141218");
    colours.insert("m3onBackground", "#E6E1E5");
    colours.insert("m3surface", "#141218");
    colours.insert("m3onSurface", "#E6E1E5");
    colours.insert("m3surfaceVariant", "#49454F");
    colours.insert("m3onSurfaceVariant", "#CAC4D0");
    colours.insert("m3surfaceDim", "#141218");
    colours.insert("m3surfaceBright", "#3B383E");
    colours.insert("m3surfaceContainerLowest", "#0F0D13");
    colours.insert("m3surfaceContainerLow", "#1D1B20");
    colours.insert("m3surfaceContainer", "#211F26");
    colours.insert("m3surfaceContainerHigh", "#2B2930");
    colours.insert("m3surfaceContainerHighest", "#36343B");
    colours.insert("m3inverseSurface", "#E6E1E5");
    colours.insert("m3inverseOnSurface", "#313033");
    colours.insert("m3inversePrimary", "#6750A4");
    colours.insert("m3outline", "#938F99");
    colours.insert("m3outlineVariant", "#49454F");
    colours.insert("m3shadow", "#000000");
    colours.insert("m3scrim", "#000000");
    colours.insert("m3surfaceTint", "#CFBCFF");

    QJsonObject scheme;
    scheme.insert("name", "fallback");
    scheme.insert("mode", "dark");
    scheme.insert("colours", colours);
    return scheme;
}

} // namespace olvex
