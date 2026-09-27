#pragma once

#include <qhash.h>
#include <qjsonarray.h>
#include <qjsondocument.h>
#include <qjsonobject.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qstring.h>
#include <qvariant.h>

namespace olvex {

class KeybindManager : public QObject {
    Q_OBJECT
    QML_ELEMENT

public:
    explicit KeybindManager(QObject* parent = nullptr);

    Q_INVOKABLE [[nodiscard]] QVariantList getBinds();
    Q_INVOKABLE bool saveKeybind(const QString& action,
                                const QString& oldMods,
                                const QString& oldKey,
                                const QString& newMods,
                                const QString& newKey,
                                const QString& newDispatcher,
                                const QString& newArg,
                                const QString& newFlag = QStringLiteral("bind"),
                                const QString& desc = QString());
    Q_INVOKABLE bool deleteKeybind(const QString& mods, const QString& key, const QString& flag = QStringLiteral("bind"));

signals:
    void bindsChanged();

private:
    [[nodiscard]] QString getHyprConfigDir() const;
    [[nodiscard]] bool isLuaHyprland() const;
    QByteArray hyprRequest(const QString& command) const;
    [[nodiscard]] QHash<QString, QString> parseLuaVariables(const QString& varsFilePath) const;
    [[nodiscard]] QHash<QPair<int, QString>, QVariantMap> parseAllLuaBinds(const QString& hyprDir, const QHash<QString, QString>& varsMap) const;
    [[nodiscard]] int getModmask(const QString& modStr) const;
    [[nodiscard]] QString normalizeKey(const QString& key) const;
    [[nodiscard]] QString formatLuaBind(const QString& mods, const QString& key, const QString& dispatcher, const QString& arg, const QString& flag, const QString& desc) const;
    [[nodiscard]] bool matchesLuaBindLine(const QString& line, const QString& oldMods, const QString& oldKey, const QHash<QString, QString>& varsMap) const;
    [[nodiscard]] bool matchesConfBindLine(const QString& line, const QString& oldMods, const QString& oldKey) const;
    [[nodiscard]] QList<std::tuple<QString, QString, QString>> extractBindCalls(const QString& content) const;
    [[nodiscard]] std::tuple<QString, QString, QString> resolveDispExpr(const QString& dispExpr, const QHash<QString, QString>& varsMap) const;
};

} // namespace olvex
