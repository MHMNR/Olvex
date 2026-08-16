#include "windowresizer.hpp"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLoggingCategory>

Q_LOGGING_CATEGORY(lcResizer, "olvex.internal.resizer", QtInfoMsg)

namespace olvex::internal::hypr {

WindowResizer::WindowResizer(QObject* parent)
    : QObject(parent) {
    loadDefaultRules();
    initSocket();
}

WindowResizer::~WindowResizer() {
    if (m_socket) {
        m_socket->close();
        m_socket->deleteLater();
    }
}

void WindowResizer::setActive(bool active) {
    if (m_active == active) return;
    m_active = active;
    emit activeChanged();
}

void WindowResizer::loadDefaultRules() {
    m_rules.clear();
    // Default Bitwarden rule: float, 20% x 54%, center
    m_rules.append(WindowRule{
        .name = "(Bitwarden",
        .matchType = "titleContains",
        .width = "20%",
        .height = "54%",
        .actions = {"float", "center"}
    });
    // Default PiP rule: Picture-in-Picture regex
    m_rules.append(WindowRule{
        .name = "^[Pp]icture(-| )in(-| )[Pp]icture$",
        .matchType = "titleRegex",
        .width = "",
        .height = "",
        .actions = {"pip"}
    });
}

void WindowResizer::initSocket() {
    const auto his = qEnvironmentVariable("HYPRLAND_INSTANCE_SIGNATURE");
    if (his.isEmpty()) {
        qCWarning(lcResizer) << "$HYPRLAND_INSTANCE_SIGNATURE is unset.";
        return;
    }

    auto hyprDir = QString("%1/hypr/%2").arg(qEnvironmentVariable("XDG_RUNTIME_DIR"), his);
    if (!QDir(hyprDir).exists()) {
        hyprDir = "/tmp/hypr/" + his;
        if (!QDir(hyprDir).exists()) {
            qCWarning(lcResizer) << "Hyprland socket directory not found:" << hyprDir;
            return;
        }
    }

    m_requestSocket = hyprDir + "/.socket.sock";
    m_eventSocket = hyprDir + "/.socket2.sock";

    m_socket = new QLocalSocket(this);
    connect(m_socket, &QLocalSocket::stateChanged, this, &WindowResizer::onSocketStateChanged);
    connect(m_socket, &QLocalSocket::errorOccurred, this, &WindowResizer::onSocketError);
    connect(m_socket, &QLocalSocket::readyRead, this, &WindowResizer::readEvents);

    m_socket->connectToServer(m_eventSocket, QLocalSocket::ReadOnly);
}

void WindowResizer::onSocketStateChanged(QLocalSocket::LocalSocketState state) {
    if (state == QLocalSocket::ConnectedState) {
        qCDebug(lcResizer) << "Connected to Hyprland event socket";
    }
}

void WindowResizer::onSocketError(QLocalSocket::LocalSocketError error) {
    qCWarning(lcResizer) << "Hyprland socket error:" << error;
}

void WindowResizer::readEvents() {
    while (m_socket && m_socket->canReadLine()) {
        const auto line = QString::fromUtf8(m_socket->readLine()).trimmed();
        if (!line.isEmpty()) {
            handleEvent(line);
        }
    }
}

void WindowResizer::handleEvent(const QString& event) {
    if (!m_active) return;

    if (event.startsWith("openwindow>>") || event.startsWith("openwindow>>>")) {
        const auto idx = event.indexOf(">>");
        const QString data = event.mid(event.indexOf(">>", idx) == idx ? (event.startsWith("openwindow>>>") ? 14 : 12) : 12);
        const auto parts = data.split(',');
        if (parts.size() >= 4) {
            const QString addr = "0x" + parts[0].trimmed().replace(">", "");
            const QString windowClass = parts[2].trimmed();
            const QString title = parts.mid(3).join(',');
            handleWindowEvent(addr, title, title, windowClass);
        }
    } else if (event.startsWith("windowtitle>>") || event.startsWith("windowtitle>>>")) {
        const int prefixLen = event.startsWith("windowtitle>>>") ? 15 : 13;
        const QString data = event.mid(prefixLen);
        const auto commaIdx = data.indexOf(',');
        if (commaIdx > 0) {
            const QString rawId = data.left(commaIdx).trimmed().replace(">", "");
            const QString addr = "0x" + rawId;
            const QString title = data.mid(commaIdx + 1);
            handleWindowEvent(addr, title, "", "");
        }
    }
}

void WindowResizer::handleWindowEvent(const QString& address, const QString& title, const QString& initialTitle, const QString& windowClass) {
    const WindowRule* rule = matchRule(title, initialTitle, windowClass);
    if (!rule) return;

    if (isRateLimited(address)) return;

    qCInfo(lcResizer) << "Matched window rule" << rule->name << "for" << address << "title:" << title;
    applyActions(address, *rule);
}

bool WindowResizer::isRateLimited(const QString& key) {
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const qint64 last = m_rateLimitTracker.value(key, 0);
    if (now - last < 800) {
        return true;
    }
    m_rateLimitTracker.insert(key, now);
    return false;
}

const WindowRule* WindowResizer::matchRule(const QString& title, const QString& initialTitle, const QString& /*windowClass*/) const {
    for (const auto& rule : m_rules) {
        if (rule.matchType == "initialTitle" && !initialTitle.isEmpty()) {
            if (initialTitle == rule.name) return &rule;
        } else if (rule.matchType == "titleContains") {
            if (title.contains(rule.name)) return &rule;
        } else if (rule.matchType == "titleExact") {
            if (title == rule.name) return &rule;
        } else if (rule.matchType == "titleRegex") {
            QRegularExpression re(rule.name);
            if (re.match(title).hasMatch()) return &rule;
        }
    }
    return nullptr;
}

void WindowResizer::applyActions(const QString& address, const WindowRule& rule) {
    if (rule.actions.contains("pip")) {
        applyPipAction(address);
        return;
    }

    QStringList cmds;
    if (rule.actions.contains("float")) {
        cmds.append(QString("dispatch togglefloating address:%1").arg(address));
    }
    if (!rule.width.isEmpty() && !rule.height.isEmpty()) {
        cmds.append(QString("dispatch resizewindowpixel exact %1 %2,address:%3").arg(rule.width, rule.height, address));
    }
    if (rule.actions.contains("center")) {
        cmds.append("dispatch centerwindow");
    }

    if (!cmds.isEmpty()) {
        sendRequest("[[BATCH]]" + cmds.join(';'));
    }
}

void WindowResizer::applyPipAction(const QString& address) {
    // 1. Get client info
    const auto clientsDoc = sendRequestJson("j/clients");
    if (!clientsDoc.isArray()) return;

    QJsonObject client;
    for (const auto& cVal : clientsDoc.array()) {
        const auto obj = cVal.toObject();
        if (obj.value("address").toString() == address) {
            client = obj;
            break;
        }
    }
    if (client.isEmpty()) return;

    // 2. Workspace & Monitor info
    const auto wsObj = client.value("workspace").toObject();
    const QString wsName = wsObj.value("name").toString();

    const auto workspacesDoc = sendRequestJson("j/workspaces");
    int monitorId = -1;
    if (workspacesDoc.isArray()) {
        for (const auto& wVal : workspacesDoc.array()) {
            const auto obj = wVal.toObject();
            if (obj.value("name").toString() == wsName) {
                monitorId = obj.value("monitorID").toInt(-1);
                break;
            }
        }
    }

    const auto monitorsDoc = sendRequestJson("j/monitors");
    QJsonObject monitor;
    if (monitorsDoc.isArray()) {
        for (const auto& mVal : monitorsDoc.array()) {
            const auto obj = mVal.toObject();
            if (monitorId >= 0 && obj.value("id").toInt(-1) == monitorId) {
                monitor = obj;
                break;
            } else if (monitorId < 0 && obj.value("focused").toBool()) {
                monitor = obj;
                break;
            }
        }
    }
    if (monitor.isEmpty() && monitorsDoc.isArray() && !monitorsDoc.array().isEmpty()) {
        monitor = monitorsDoc.array().first().toObject();
    }
    if (monitor.isEmpty()) return;

    const auto sizeArr = client.value("size").toArray();
    if (sizeArr.size() < 2) return;

    double winW = sizeArr.at(0).toDouble(320);
    double winH = sizeArr.at(1).toDouble(180);
    if (winH <= 0) winH = 180;

    const double monW = monitor.value("width").toDouble(1920) / monitor.value("scale").toDouble(1.0);
    const double monH = monitor.value("height").toDouble(1080) / monitor.value("scale").toDouble(1.0);
    const double monX = monitor.value("x").toDouble(0);
    const double monY = monitor.value("y").toDouble(0);

    const double targetH = monH / 4.0;
    const double scaleFactor = targetH / winH;
    int scaledW = qMax(200, static_cast<int>(winW * scaleFactor));
    int scaledH = qMax(150, static_cast<int>(winH * scaleFactor));

    const double offset = qMin(monW, monH) * 0.03;
    const int moveX = static_cast<int>(monX + monW - scaledW - offset);
    const int moveY = static_cast<int>(monY + monH - scaledH - offset);

    QStringList cmds;
    if (!client.value("floating").toBool()) {
        cmds.append(QString("dispatch togglefloating address:%1").arg(address));
    }
    cmds.append(QString("dispatch resizewindowpixel exact %1 %2,address:%3").arg(QString::number(scaledW), QString::number(scaledH), address));
    cmds.append(QString("dispatch movewindowpixel exact %1 %2,address:%3").arg(QString::number(moveX), QString::number(moveY), address));
    cmds.append(QString("dispatch pin address:%1").arg(address));

    sendRequest("[[BATCH]]" + cmds.join(';'));
    qCInfo(lcResizer) << "Applied native C++ PiP to" << address << scaledW << "x" << scaledH << "at (" << moveX << "," << moveY << ")";
}

void WindowResizer::pipActiveWindow() {
    const auto activeDoc = sendRequestJson("j/activewindow");
    if (activeDoc.isObject()) {
        const QString addr = activeDoc.object().value("address").toString();
        if (!addr.isEmpty()) {
            applyPipAction(addr);
        }
    }
}

void WindowResizer::pipWindow(const QString& address) {
    applyPipAction(address);
}

QByteArray WindowResizer::sendRequest(const QString& request) {
    if (m_requestSocket.isEmpty()) return {};

    QLocalSocket socket;
    socket.connectToServer(m_requestSocket);
    if (!socket.waitForConnected(200)) {
        return {};
    }

    socket.write(request.toUtf8());
    socket.flush();

    QByteArray response;
    if (socket.waitForReadyRead(500)) {
        response = socket.readAll();
    }
    socket.close();
    return response;
}

QJsonDocument WindowResizer::sendRequestJson(const QString& request) {
    const auto data = sendRequest(request);
    if (data.isEmpty()) return {};
    return QJsonDocument::fromJson(data);
}

} // namespace olvex::internal::hypr
