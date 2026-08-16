#pragma once

#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocalSocket>
#include <QObject>
#include <QRegularExpression>
#include <QString>
#include <QVector>
#include <qqmlintegration.h>

namespace olvex::internal::hypr {

struct WindowRule {
    QString name;
    QString matchType; // "titleContains", "titleRegex", "titleExact", "initialTitle"
    QString width;
    QString height;
    QStringList actions; // "float", "center", "pip"
};

class WindowResizer : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)

public:
    explicit WindowResizer(QObject* parent = nullptr);
    ~WindowResizer() override;

    [[nodiscard]] bool active() const { return m_active; }
    void setActive(bool active);

    Q_INVOKABLE void pipActiveWindow();
    Q_INVOKABLE void pipWindow(const QString& address);

signals:
    void activeChanged();

private slots:
    void onSocketStateChanged(QLocalSocket::LocalSocketState state);
    void onSocketError(QLocalSocket::LocalSocketError error);
    void readEvents();

private:
    bool m_active{true};
    QString m_requestSocket;
    QString m_eventSocket;
    QLocalSocket* m_socket{nullptr};
    QHash<QString, qint64> m_rateLimitTracker;
    QVector<WindowRule> m_rules;

    void initSocket();
    void loadDefaultRules();
    void handleEvent(const QString& event);
    void handleWindowEvent(const QString& address, const QString& title, const QString& initialTitle, const QString& windowClass);

    bool isRateLimited(const QString& key);
    const WindowRule* matchRule(const QString& title, const QString& initialTitle, const QString& windowClass) const;
    void applyActions(const QString& address, const WindowRule& rule);
    void applyPipAction(const QString& address);

    QByteArray sendRequest(const QString& request);
    QJsonDocument sendRequestJson(const QString& request);
};

} // namespace olvex::internal::hypr
