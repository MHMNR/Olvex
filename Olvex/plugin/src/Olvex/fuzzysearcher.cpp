#include "fuzzysearcher.hpp"

#include <QChar>
#include <QRegularExpression>
#include <algorithm>
#include <vector>

namespace olvex {

FuzzySearcher::FuzzySearcher(QObject* parent)
    : QObject(parent) {}

QString FuzzySearcher::extractValue(const QVariant& item, const QString& key) {
    if (item.canConvert<QObject*>()) {
        auto* obj = item.value<QObject*>();
        if (obj) {
            return obj->property(key.toUtf8().constData()).toString();
        }
    }
    if (item.typeId() == QMetaType::QVariantMap) {
        return item.toMap().value(key).toString();
    }
    return item.toString();
}

int FuzzySearcher::fuzzyScore(const QString& pattern, const QString& target) {
    if (pattern.isEmpty()) return 1000;
    if (target.isEmpty()) return -10000;

    const qsizetype pLen = pattern.length();
    const qsizetype tLen = target.length();
    if (pLen > tLen) return -10000;

    qsizetype pIdx = 0;
    qsizetype tIdx = 0;
    int score = 0;
    int consecutive = 0;
    qsizetype lastMatch = -1;

    const QString pLower = pattern.toLower();
    const QString tLower = target.toLower();

    // Exact match bonus
    if (tLower == pLower) {
        return static_cast<int>(10000 - tLen);
    }

    // Prefix match bonus
    if (tLower.startsWith(pLower)) {
        return static_cast<int>(5000 + (1000 - tLen));
    }

    while (pIdx < pLen && tIdx < tLen) {
        const QChar pChar = pLower.at(pIdx);
        const QChar tChar = tLower.at(tIdx);

        if (pChar == tChar) {
            int charScore = 10;

            // Beginning of string bonus
            if (tIdx == 0) {
                charScore += 32;
            } else {
                const QChar prevChar = target.at(tIdx - 1);
                // Word boundary bonus
                if (prevChar == ' ' || prevChar == '-' || prevChar == '_' || prevChar == '.' || prevChar == '/') {
                    charScore += 32;
                } else if (target.at(tIdx).isUpper() && prevChar.isLower()) {
                    // camelCase boundary
                    charScore += 24;
                }
            }

            // Consecutive match bonus
            if (consecutive > 0) {
                charScore += consecutive * 16;
            }

            // Gap penalty
            if (lastMatch >= 0) {
                const qsizetype gap = tIdx - lastMatch - 1;
                if (gap > 0) {
                    charScore -= static_cast<int>(gap * 3);
                }
            }

            score += charScore;
            consecutive++;
            lastMatch = tIdx;
            pIdx++;
        } else {
            consecutive = 0;
        }
        tIdx++;
    }

    // Did not match all pattern characters
    if (pIdx < pLen) {
        return -10000;
    }

    // Shorter target length bonus
    score -= static_cast<int>(tLen - pLen);

    return score;
}

bool FuzzySearcher::fuzzyMatch(const QString& pattern, const QString& target) {
    return fuzzyScore(pattern, target) > -10000;
}

QVariantList FuzzySearcher::query(
    const QString& search,
    const QVariantList& catalog,
    const QString& defaultKey,
    const QStringList& keys,
    const QList<qreal>& weights) const {
    if (catalog.isEmpty()) return {};

    const QString queryTrimmed = search.trimmed();
    if (queryTrimmed.isEmpty()) {
        return catalog;
    }

    const QStringList searchKeys = keys.isEmpty() ? QStringList{defaultKey} : keys;
    const qsizetype numKeys = searchKeys.size();

    struct ScoredItem {
        QVariant item;
        int score;
        qsizetype length;
    };

    std::vector<ScoredItem> matches;
    matches.reserve(static_cast<size_t>(catalog.size()));

    for (const auto& entry : catalog) {
        int bestScore = -10000;
        int totalWeightedScore = 0;
        bool anyMatch = false;

        for (qsizetype k = 0; k < numKeys; ++k) {
            const QString val = extractValue(entry, searchKeys.at(k));
            const int s = fuzzyScore(queryTrimmed, val);
            if (s > -10000) {
                anyMatch = true;
                const qreal w = (k < weights.size()) ? weights.at(k) : 1.0;
                totalWeightedScore += static_cast<int>(s * w);
                if (s > bestScore) {
                    bestScore = s;
                }
            }
        }

        if (anyMatch) {
            const QString primaryVal = extractValue(entry, defaultKey);
            matches.push_back({entry, totalWeightedScore > 0 ? totalWeightedScore : bestScore, primaryVal.length()});
        }
    }

    std::sort(matches.begin(), matches.end(), [](const ScoredItem& a, const ScoredItem& b) {
        if (a.score != b.score) {
            return a.score > b.score;
        }
        return a.length < b.length;
    });

    QVariantList result;
    result.reserve(static_cast<qsizetype>(matches.size()));
    for (const auto& m : matches) {
        result.append(m.item);
    }

    return result;
}

} // namespace olvex
