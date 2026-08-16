#pragma once

#include <QJsonObject>
#include <QObject>
#include <QString>
#include <QStringList>
#include <qqmlintegration.h>

namespace olvex {

class M3ColorMapper : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit M3ColorMapper(QObject* parent = nullptr);
    ~M3ColorMapper() override = default;

    Q_INVOKABLE QJsonObject parseSchemePayload(const QString& data) const;
    Q_INVOKABLE QString stringifySchemePayload(const QString& data) const;
    Q_INVOKABLE QString extractPrimaryColour(const QJsonObject& scheme) const;
    Q_INVOKABLE QString schemeColour(const QJsonObject& scheme, const QStringList& keys) const;
    Q_INVOKABLE bool applySchemeToPalette(QObject* palette, const QJsonObject& scheme) const;
    Q_INVOKABLE QJsonObject fallbackScheme() const;

    Q_INVOKABLE static QString hexColour(const QString& value);
    Q_INVOKABLE static QString snakeToM3Prop(const QString& name);
    Q_INVOKABLE static bool mapsToPalette(const QString& name);
    Q_INVOKABLE static QJsonObject filterScheme(const QJsonObject& scheme);

private:
    static QJsonObject parseSchemePayloadRaw(const QString& data);
};

} // namespace olvex
