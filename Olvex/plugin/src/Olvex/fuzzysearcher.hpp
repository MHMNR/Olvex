#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <qqmlintegration.h>

namespace olvex {

class FuzzySearcher : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit FuzzySearcher(QObject* parent = nullptr);
    ~FuzzySearcher() override = default;

    Q_INVOKABLE QVariantList query(
        const QString& search,
        const QVariantList& catalog,
        const QString& defaultKey = "name",
        const QStringList& keys = {},
        const QList<qreal>& weights = {}) const;

    Q_INVOKABLE static int fuzzyScore(const QString& pattern, const QString& target);
    Q_INVOKABLE static bool fuzzyMatch(const QString& pattern, const QString& target);

private:
    static QString extractValue(const QVariant& item, const QString& key);
};

} // namespace olvex
