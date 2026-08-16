#include "usbwatcher.hpp"
#include <QRegularExpression>

namespace olvex::services {

UsbWatcher::UsbWatcher(QObject* parent)
    : QObject(parent) {
    initUdev();
}

UsbWatcher::~UsbWatcher() {
    cleanupUdev();
}

bool UsbWatcher::active() const {
    return m_active;
}

void UsbWatcher::setActive(bool active) {
    if (m_active == active)
        return;

    m_active = active;
    if (m_active) {
        initUdev();
    } else {
        cleanupUdev();
    }
    emit activeChanged();
}

void UsbWatcher::initUdev() {
    if (m_udev)
        return;

    m_udev = udev_new();
    if (!m_udev)
        return;

    m_mon = udev_monitor_new_from_netlink(m_udev, "udev");
    if (!m_mon) {
        udev_unref(m_udev);
        m_udev = nullptr;
        return;
    }

    udev_monitor_filter_add_match_subsystem_devtype(m_mon, "usb", "usb_device");
    if (udev_monitor_enable_receiving(m_mon) < 0) {
        cleanupUdev();
        return;
    }

    int fd = udev_monitor_get_fd(m_mon);
    if (fd < 0) {
        cleanupUdev();
        return;
    }

    m_notifier = new QSocketNotifier(fd, QSocketNotifier::Read, this);
    connect(m_notifier, &QSocketNotifier::activated, this, &UsbWatcher::onSocketActivated);
}

void UsbWatcher::cleanupUdev() {
    if (m_notifier) {
        m_notifier->setEnabled(false);
        delete m_notifier;
        m_notifier = nullptr;
    }
    if (m_mon) {
        udev_monitor_unref(m_mon);
        m_mon = nullptr;
    }
    if (m_udev) {
        udev_unref(m_udev);
        m_udev = nullptr;
    }
    m_cache.clear();
}

QString UsbWatcher::cleanString(const QString& str) {
    if (str.isEmpty())
        return {};

    QString s = str;
    static const QRegularExpression hexRegex(QStringLiteral(R"(\\x([0-9a-fA-F]{2}))"));
    auto it = hexRegex.globalMatch(s);
    while (it.hasNext()) {
        auto match = it.next();
        bool ok = false;
        int val = match.captured(1).toInt(&ok, 16);
        if (ok) {
            s.replace(match.captured(0), QString(QChar(val)));
        }
    }

    s.replace(QLatin1Char('_'), QLatin1Char(' '));
    return s.simplified().trimmed();
}

QString UsbWatcher::simplifyName(const QString& str) {
    if (str.isEmpty())
        return {};

    QString s = str;
    // Remove parenthetical details e.g. (formerly Feiya Technology Corp.)
    static const QRegularExpression parenRegex(QStringLiteral(R"(\(.*?\))"));
    s.remove(parenRegex);

    // Remove corporate suffixes
    static const QRegularExpression corpRegex(QStringLiteral(R"(,?\s*(Inc\.|Corp\.|Ltd\.|Co\.|LLC|GmbH).*)"), QRegularExpression::CaseInsensitiveOption);
    s.remove(corpRegex);

    // Remove location suffixes e.g. - Taiwan
    static const QRegularExpression locRegex(QStringLiteral(R"(\s*-\s*.*)"));
    s.remove(locRegex);

    return cleanString(s);
}

QString UsbWatcher::getDeviceName(struct udev_device* dev) {
    const char* vendorId = udev_device_get_property_value(dev, "ID_VENDOR_ID");
    if (vendorId && qstrcmp(vendorId, "1d6b") == 0) // Linux root hub
        return {};

    const char* rawVendor = udev_device_get_property_value(dev, "ID_VENDOR_FROM_DATABASE");
    if (!rawVendor) rawVendor = udev_device_get_property_value(dev, "ID_VENDOR_ENC");
    if (!rawVendor) rawVendor = udev_device_get_property_value(dev, "ID_VENDOR");
    if (!rawVendor) rawVendor = udev_device_get_property_value(dev, "ID_USB_VENDOR");

    const char* rawModel = udev_device_get_property_value(dev, "ID_MODEL_FROM_DATABASE");
    if (!rawModel) rawModel = udev_device_get_property_value(dev, "ID_MODEL_ENC");
    if (!rawModel) rawModel = udev_device_get_property_value(dev, "ID_MODEL");
    if (!rawModel) rawModel = udev_device_get_property_value(dev, "ID_USB_MODEL");

    QString vendor = simplifyName(rawVendor ? QString::fromUtf8(rawVendor) : QString());
    QString model = simplifyName(rawModel ? QString::fromUtf8(rawModel) : QString());

    if (vendor.contains(QStringLiteral("Linux"), Qt::CaseInsensitive) &&
        model.contains(QStringLiteral("root hub"), Qt::CaseInsensitive)) {
        return {};
    }

    if (!model.isEmpty() && !vendor.isEmpty()) {
        if (model.contains(vendor, Qt::CaseInsensitive))
            return model;
        return QStringLiteral("%1 %2").arg(vendor, model);
    }
    if (!model.isEmpty())
        return model;
    if (!vendor.isEmpty())
        return QStringLiteral("%1 Device").arg(vendor);

    return QStringLiteral("USB Device");
}

void UsbWatcher::onSocketActivated() {
    if (!m_mon)
        return;

    struct udev_device* dev = udev_monitor_receive_device(m_mon);
    if (!dev)
        return;

    const char* action = udev_device_get_action(dev);
    const char* devpath = udev_device_get_devpath(dev);

    if (action && devpath) {
        QString act = QString::fromUtf8(action);
        QString path = QString::fromUtf8(devpath);

        if (act == QLatin1String("add")) {
            QString name = getDeviceName(dev);
            if (!name.isEmpty()) {
                m_cache.insert(path, name);
                emit deviceConnected(QStringLiteral("USB device connected"), name, QStringLiteral("usb"));
            }
        } else if (act == QLatin1String("remove")) {
            QString name = m_cache.take(path);
            if (!name.isEmpty()) {
                emit deviceDisconnected(QStringLiteral("USB device removed"), name, QStringLiteral("usb_off"));
            }
        }
    }

    udev_device_unref(dev);
}

} // namespace olvex::services
