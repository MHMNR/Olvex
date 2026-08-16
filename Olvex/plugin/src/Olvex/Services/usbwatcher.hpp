#pragma once

#include <libudev.h>
#include <QHash>
#include <QObject>
#include <QSocketNotifier>
#include <QString>
#include <qqmlintegration.h>

namespace olvex::services {

class UsbWatcher : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)

public:
    explicit UsbWatcher(QObject* parent = nullptr);
    ~UsbWatcher() override;

    [[nodiscard]] bool active() const;
    void setActive(bool active);

signals:
    void activeChanged();
    void deviceConnected(const QString& title, const QString& message, const QString& icon);
    void deviceDisconnected(const QString& title, const QString& message, const QString& icon);

private slots:
    void onSocketActivated();

private:
    void initUdev();
    void cleanupUdev();
    void enumerateExistingDevices();
    static QString cleanString(const QString& str);
    static QString simplifyName(const QString& str);
    static QString getDeviceName(struct udev_device* dev);

    bool m_active{true};
    struct udev* m_udev{nullptr};
    struct udev_monitor* m_mon{nullptr};
    QSocketNotifier* m_notifier{nullptr};
    QHash<QString, QString> m_cache;
};

} // namespace olvex::services
