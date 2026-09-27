#include "keybindmanager.hpp"

#include <qdir.h>
#include <qdiriterator.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qlocalsocket.h>
#include <qloggingcategory.h>
#include <qprocess.h>
#include <qregularexpression.h>
#include <qstandardpaths.h>
#include <qtextstream.h>

Q_LOGGING_CATEGORY(lcKeybinds, "olvex.keybinds", QtInfoMsg)

namespace olvex {

KeybindManager::KeybindManager(QObject* parent)
    : QObject(parent) {}

QString KeybindManager::getHyprConfigDir() const {
    const auto xdg = qEnvironmentVariable("XDG_CONFIG_HOME");
    if (!xdg.isEmpty()) {
        return xdg + QStringLiteral("/hypr");
    }
    return QDir::homePath() + QStringLiteral("/.config/hypr");
}

QByteArray KeybindManager::hyprRequest(const QString& command) const {
    const auto his = qEnvironmentVariable("HYPRLAND_INSTANCE_SIGNATURE");
    if (!his.isEmpty()) {
        auto hyprDir = QStringLiteral("%1/hypr/%2").arg(qEnvironmentVariable("XDG_RUNTIME_DIR"), his);
        if (!QDir(hyprDir).exists()) {
            hyprDir = QStringLiteral("/tmp/hypr/") + his;
        }

        const auto sockPath = hyprDir + QStringLiteral("/.socket.sock");
        if (QFile::exists(sockPath)) {
            QLocalSocket socket;
            socket.connectToServer(sockPath);
            if (socket.waitForConnected(300)) {
                socket.write(command.toUtf8());
                socket.flush();
                QByteArray response;
                while (socket.waitForReadyRead(300) || socket.bytesAvailable() > 0) {
                    response.append(socket.readAll());
                    if (socket.state() == QLocalSocket::UnconnectedState && socket.bytesAvailable() == 0) {
                        break;
                    }
                }
                if (!response.isEmpty()) {
                    return response;
                }
            }
        }
    }

    // Fallback to hyprctl process
    QProcess proc;
    QStringList args;
    if (command == QStringLiteral("j/binds")) {
        args << QStringLiteral("binds") << QStringLiteral("-j");
    } else if (command == QStringLiteral("j/systeminfo")) {
        args << QStringLiteral("systeminfo") << QStringLiteral("-j");
    } else if (command == QStringLiteral("reload") || command == QStringLiteral("dispatch reload")) {
        args << QStringLiteral("reload");
    } else {
        args = command.split(QLatin1Char(' '), Qt::SkipEmptyParts);
    }

    proc.start(QStringLiteral("hyprctl"), args);
    if (proc.waitForFinished(2000)) {
        return proc.readAllStandardOutput();
    }
    return QByteArray();
}

bool KeybindManager::isLuaHyprland() const {
    const auto hyprDir = getHyprConfigDir();
    if (QFile::exists(hyprDir + QStringLiteral("/hyprland.lua"))) {
        return true;
    }

    const auto sysinfo = hyprRequest(QStringLiteral("j/systeminfo"));
    if (!sysinfo.isEmpty()) {
        const auto doc = QJsonDocument::fromJson(sysinfo);
        if (doc.isObject()) {
            const auto obj = doc.object();
            if (obj.value(QStringLiteral("configProvider")).toString().contains(QStringLiteral("lua"), Qt::CaseInsensitive)) {
                return true;
            }
        } else if (QString::fromUtf8(sysinfo).contains(QStringLiteral("configProvider: lua"), Qt::CaseInsensitive)) {
            return true;
        }
    }

    QDir dir(hyprDir);
    if (!dir.entryList(QStringList() << QStringLiteral("*.lua"), QDir::Files, QDir::NoSort).isEmpty()) {
        return true;
    }

    return false;
}

int KeybindManager::getModmask(const QString& modStr) const {
    int mask = 0;
    const auto parts = modStr.split(QRegularExpression(QStringLiteral("[\\s\\+,_]+")), Qt::SkipEmptyParts);
    for (const auto& p : parts) {
        const auto u = p.trimmed().toUpper();
        if (u == QStringLiteral("SUPER") || u == QStringLiteral("WIN") || u == QStringLiteral("LOGO") ||
            u == QStringLiteral("MOD4") || u == QStringLiteral("$MAINMOD") || u == QStringLiteral("MOD")) {
            mask |= 64;
        } else if (u == QStringLiteral("CTRL") || u == QStringLiteral("CONTROL")) {
            mask |= 4;
        } else if (u == QStringLiteral("ALT") || u == QStringLiteral("MOD1")) {
            mask |= 8;
        } else if (u == QStringLiteral("SHIFT")) {
            mask |= 1;
        }
    }
    return mask;
}

QString KeybindManager::normalizeKey(const QString& key) const {
    const auto k = key.trimmed();
    static const QHash<QString, QString> keyMap = {
        {QStringLiteral("Return"), QStringLiteral("return")},
        {QStringLiteral("Enter"), QStringLiteral("return")},
        {QStringLiteral("Escape"), QStringLiteral("escape")},
        {QStringLiteral("Esc"), QStringLiteral("escape")},
        {QStringLiteral("BackSpace"), QStringLiteral("backspace")},
        {QStringLiteral("Backspace"), QStringLiteral("backspace")},
        {QStringLiteral("Delete"), QStringLiteral("delete")},
        {QStringLiteral("Del"), QStringLiteral("delete")},
        {QStringLiteral("Space"), QStringLiteral("space")},
        {QStringLiteral("space"), QStringLiteral("space")},
        {QStringLiteral("Tab"), QStringLiteral("tab")},
        {QStringLiteral("Left"), QStringLiteral("left")},
        {QStringLiteral("Right"), QStringLiteral("right")},
        {QStringLiteral("Up"), QStringLiteral("up")},
        {QStringLiteral("Down"), QStringLiteral("down")},
        {QStringLiteral("Minus"), QStringLiteral("minus")},
        {QStringLiteral("Equal"), QStringLiteral("equal")},
        {QStringLiteral("Comma"), QStringLiteral("comma")},
        {QStringLiteral("Period"), QStringLiteral("period")},
        {QStringLiteral("Slash"), QStringLiteral("slash")},
        {QStringLiteral("Backslash"), QStringLiteral("backslash")},
        {QStringLiteral("Semicolon"), QStringLiteral("semicolon")},
        {QStringLiteral("Print"), QStringLiteral("print")},
        {QStringLiteral("SUPER_L"), QStringLiteral("super_l")},
        {QStringLiteral("SUPER_R"), QStringLiteral("super_r")}
    };

    if (keyMap.contains(k)) {
        return keyMap.value(k);
    }
    return k.toLower();
}

QHash<QString, QString> KeybindManager::parseLuaVariables(const QString& varsFilePath) const {
    QHash<QString, QString> varsMap;
    varsMap.insert(QStringLiteral("mod"), QStringLiteral("SUPER"));
    varsMap.insert(QStringLiteral("mainMod"), QStringLiteral("SUPER"));

    QStringList filesToCheck;
    if (!varsFilePath.isEmpty() && QFile::exists(varsFilePath)) {
        filesToCheck << varsFilePath;
    }

    const auto hyprDir = getHyprConfigDir();
    QDirIterator it(hyprDir, QStringList() << QStringLiteral("*.lua"), QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const auto path = it.next();
        if (path.contains(QStringLiteral("var"), Qt::CaseInsensitive) || path.endsWith(QStringLiteral("hyprland.lua"))) {
            if (!filesToCheck.contains(path)) {
                filesToCheck << path;
            }
        }
    }

    static const QRegularExpression varRegex(QStringLiteral("^\\s*([a-zA-Z0-9_]+)\\s*=\\s*(.+?)\\s*,?\\s*$"), QRegularExpression::MultilineOption);

    for (const auto& fpath : filesToCheck) {
        QFile file(fpath);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
            continue;
        const QString content = QString::fromUtf8(file.readAll());
        auto matches = varRegex.globalMatch(content);
        while (matches.hasNext()) {
            auto m = matches.next();
            const auto k = m.captured(1).trimmed();
            QString v = m.captured(2).trimmed();
            if (v.endsWith(QLatin1Char(',')))
                v.chop(1);
            v = v.trimmed();
            if ((v.startsWith(QLatin1Char('"')) && v.endsWith(QLatin1Char('"'))) ||
                (v.startsWith(QLatin1Char('\'')) && v.endsWith(QLatin1Char('\'')))) {
                varsMap.insert(k, v.mid(1, v.length() - 2));
            } else if (v.startsWith(QLatin1Char('{')) && v.endsWith(QLatin1Char('}'))) {
                // Table of strings
                static const QRegularExpression itemRegex(QStringLiteral("[\"']([^\"']+)[\"']"));
                auto itm = itemRegex.globalMatch(v);
                QStringList items;
                while (itm.hasNext()) {
                    items << itm.next().captured(1);
                }
                varsMap.insert(k, items.join(QLatin1Char(',')));
            } else {
                varsMap.insert(k, v);
            }
        }
    }

    return varsMap;
}

QList<std::tuple<QString, QString, QString>> KeybindManager::extractBindCalls(const QString& content) const {
    QList<std::tuple<QString, QString, QString>> calls;
    static const QRegularExpression callStart(QStringLiteral("\\b(?:create_bind|hl\\.bind)\\s*\\("));
    auto it = callStart.globalMatch(content);

    while (it.hasNext()) {
        auto m = it.next();
        qsizetype startIdx = m.capturedEnd();
        int depth = 1;
        int inTable = 0;
        QChar inString = QChar::Null;
        QString currentArg;
        QStringList args;

        for (qsizetype i = startIdx; i < content.length(); ++i) {
            QChar c = content.at(i);
            if (!inString.isNull()) {
                currentArg.append(c);
                if (c == inString && (i == 0 || content.at(i - 1) != QLatin1Char('\\'))) {
                    inString = QChar::Null;
                }
            } else if (c == QLatin1Char('"') || c == QLatin1Char('\'')) {
                inString = c;
                currentArg.append(c);
            } else if (c == QLatin1Char('{')) {
                inTable++;
                currentArg.append(c);
            } else if (c == QLatin1Char('}')) {
                inTable = qMax(0, inTable - 1);
                currentArg.append(c);
            } else if (c == QLatin1Char('(')) {
                depth++;
                currentArg.append(c);
            } else if (c == QLatin1Char(')')) {
                depth--;
                if (depth == 0) {
                    if (!currentArg.trimmed().isEmpty()) {
                        args << currentArg.trimmed();
                    }
                    break;
                } else {
                    currentArg.append(c);
                }
            } else if (c == QLatin1Char(',') && depth == 1 && inTable == 0) {
                args << currentArg.trimmed();
                currentArg.clear();
            } else {
                currentArg.append(c);
            }
        }

        if (args.size() >= 2) {
            const QString keyExpr = args.at(0);
            const QString dispExpr = args.at(1);
            const QString flagsExpr = args.size() > 2 ? args.at(2) : QString();
            calls.append(std::make_tuple(keyExpr, dispExpr, flagsExpr));
        }
    }

    return calls;
}

std::tuple<QString, QString, QString> KeybindManager::resolveDispExpr(const QString& dispExpr, const QHash<QString, QString>& varsMap) const {
    QString disp = QStringLiteral("exec");
    QString arg;
    QString desc;

    if (dispExpr.contains(QStringLiteral("hl.dsp.exec_cmd"))) {
        disp = QStringLiteral("exec");
        static const QRegularExpression regex(QStringLiteral("hl\\.dsp\\.exec_cmd\\s*\\(\\s*(.+?)\\s*\\)$"), QRegularExpression::DotMatchesEverythingOption);
        auto m = regex.match(dispExpr);
        if (m.hasMatch()) {
            const auto inner = m.captured(1).trimmed();
            const auto parts = inner.split(QStringLiteral(".."));
            QString resolved;
            for (auto p : parts) {
                p = p.trimmed();
                if (p.startsWith(QStringLiteral("vars."))) {
                    const auto varName = p.mid(5);
                    resolved += varsMap.value(varName, p);
                } else {
                    p.remove(QRegularExpression(QStringLiteral("^[\"']|[\"']$")));
                    resolved += p;
                }
            }
            arg = resolved;
        }
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.global"))) {
        disp = QStringLiteral("global");
        static const QRegularExpression regex(QStringLiteral("hl\\.dsp\\.global\\s*\\(\\s*[\"']([^\"']+)[\"']\\s*\\)"));
        auto m = regex.match(dispExpr);
        if (m.hasMatch()) {
            arg = m.captured(1);
        }
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.window.close")) || dispExpr.contains(QStringLiteral("hl.dsp.window.kill"))) {
        disp = QStringLiteral("killactive");
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.window.float"))) {
        disp = QStringLiteral("togglefloating");
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.window.fullscreen"))) {
        disp = QStringLiteral("fullscreen");
        arg = dispExpr.contains(QStringLiteral("maximized")) ? QStringLiteral("1") : QStringLiteral("0");
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.window.pseudo"))) {
        disp = QStringLiteral("pseudo");
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.window.pin"))) {
        disp = QStringLiteral("pin");
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.window.center"))) {
        disp = QStringLiteral("centerwindow");
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.window.drag"))) {
        disp = QStringLiteral("mouse");
        arg = QStringLiteral("move");
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.window.resize"))) {
        disp = QStringLiteral("mouse");
        arg = QStringLiteral("resize");
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.window.cycle_next"))) {
        disp = QStringLiteral("cyclenext");
        arg = dispExpr.contains(QStringLiteral("next = false")) ? QStringLiteral("prev") : QString();
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.layout"))) {
        static const QRegularExpression regex(QStringLiteral("hl\\.dsp\\.layout\\s*\\(\\s*[\"']([^\"']+)[\"']\\s*\\)"));
        auto m = regex.match(dispExpr);
        disp = m.hasMatch() ? m.captured(1) : QStringLiteral("togglesplit");
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.group.toggle"))) {
        disp = QStringLiteral("togglegroup");
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.group.next"))) {
        disp = QStringLiteral("changegroupactive");
        arg = QStringLiteral("f");
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.group.prev"))) {
        disp = QStringLiteral("changegroupactive");
        arg = QStringLiteral("b");
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.group.lock_active"))) {
        disp = QStringLiteral("lockactivegroup");
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.window.move"))) {
        disp = QStringLiteral("movewindow");
        static const QRegularExpression mDir(QStringLiteral("direction\\s*=\\s*[\"']([^\"']+)[\"']"));
        static const QRegularExpression mWs(QStringLiteral("workspace\\s*=\\s*[\"']?([^\"'\\}]+)[\"']?"));
        auto md = mDir.match(dispExpr);
        auto mw = mWs.match(dispExpr);
        if (md.hasMatch()) {
            arg = md.captured(1);
        } else if (mw.hasMatch()) {
            disp = QStringLiteral("movetoworkspace");
            arg = mw.captured(1).trimmed();
        } else if (dispExpr.contains(QStringLiteral("out_of_group"))) {
            disp = QStringLiteral("moveoutofgroup");
        }
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.window.swap"))) {
        disp = QStringLiteral("swapwindow");
        static const QRegularExpression mDir(QStringLiteral("direction\\s*=\\s*[\"']([^\"']+)[\"']"));
        auto md = mDir.match(dispExpr);
        if (md.hasMatch()) {
            arg = md.captured(1);
        }
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.focus"))) {
        disp = QStringLiteral("movefocus");
        static const QRegularExpression mDir(QStringLiteral("direction\\s*=\\s*[\"']([^\"']+)[\"']"));
        static const QRegularExpression mWs(QStringLiteral("workspace\\s*=\\s*[\"']?([^\"'\\}]+)[\"']?"));
        auto md = mDir.match(dispExpr);
        auto mw = mWs.match(dispExpr);
        if (md.hasMatch()) {
            arg = md.captured(1);
        } else if (mw.hasMatch()) {
            disp = QStringLiteral("workspace");
            arg = mw.captured(1).trimmed();
        }
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.workspace.toggle_special")) || dispExpr.contains(QStringLiteral("fn.toggle"))) {
        disp = QStringLiteral("togglespecialworkspace");
        static const QRegularExpression regex(QStringLiteral("(?:hl\\.dsp\\.workspace\\.toggle_special|fn\\.toggle)\\s*\\(\\s*[\"']([^\"']+)[\"']\\s*\\)"));
        auto m = regex.match(dispExpr);
        if (m.hasMatch()) {
            arg = m.captured(1);
        }
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.workspace.move"))) {
        disp = QStringLiteral("movetoworkspace");
        static const QRegularExpression mWs(QStringLiteral("workspace\\s*=\\s*[\"']?([^\"'\\}]+)[\"']?"));
        auto mw = mWs.match(dispExpr);
        if (mw.hasMatch()) {
            arg = mw.captured(1).trimmed();
        }
    } else if (dispExpr.contains(QStringLiteral("hl.dsp.exit"))) {
        disp = QStringLiteral("exit");
    } else if (dispExpr.contains(QStringLiteral("fn.resize_active_window"))) {
        disp = QStringLiteral("resizeactive");
        static const QRegularExpression regex(QStringLiteral("fn\\.resize_active_window\\s*\\(\\s*([-\\d]+)\\s*,\\s*([-\\d]+)\\s*\\)"));
        auto m = regex.match(dispExpr);
        if (m.hasMatch()) {
            arg = QStringLiteral("%1 %2").arg(m.captured(1), m.captured(2));
        }
    } else if (dispExpr.contains(QStringLiteral("fn.wsaction"))) {
        static const QRegularExpression regex(QStringLiteral("fn\\.wsaction\\s*\\(\\s*[\"']([^\"']+)[\"']\\s*,\\s*[\"']([^\"']+)[\"']\\s*,\\s*([^\\)]+)\\)"));
        auto m = regex.match(dispExpr);
        if (m.hasMatch()) {
            const auto act = m.captured(1);
            const auto target = m.captured(2);
            const auto num = m.captured(3).trimmed();
            disp = (act == QStringLiteral("move")) ? QStringLiteral("movetoworkspace") : QStringLiteral("workspace");
            arg = (target == QStringLiteral("group")) ? QStringLiteral("group:%1").arg(num) : num;
        }
    } else if (dispExpr.contains(QStringLiteral("function"))) {
        disp = QStringLiteral("exec");
        arg = QStringLiteral("Lua Callback Function");
        desc = QStringLiteral("Hyprland Lua Callback");
    } else {
        disp = QStringLiteral("exec");
        arg = dispExpr;
    }

    return std::make_tuple(disp, arg, desc);
}

QHash<QPair<int, QString>, QVariantMap> KeybindManager::parseAllLuaBinds(const QString& hyprDir, const QHash<QString, QString>& varsMap) const {
    QHash<QPair<int, QString>, QVariantMap> parsedMap;

    // 1. Standard Workspaces (1-10)
    for (int i = 1; i <= 10; ++i) {
        const auto key = QString::number(i % 10);
        const auto normK = normalizeKey(key);

        static const struct {
            const char* vname;
            const char* disp;
            const char* prefix;
            const char* dLabel;
        } wsDefs[] = {
            {"kbGoToWs", "workspace", "", "Switch to Workspace"},
            {"kbGoToWsGroup", "workspace", "group:", "Switch to Workspace Group"},
            {"kbMoveWinToWs", "movetoworkspace", "", "Move Window to Workspace"},
            {"kbMoveWinToWsGroup", "movetoworkspace", "group:", "Move Window to Workspace Group"},
        };

        for (const auto& w : wsDefs) {
            const auto vname = QString::fromLatin1(w.vname);
            if (varsMap.contains(vname)) {
                int m = getModmask(varsMap.value(vname));
                QVariantMap info;
                info.insert(QStringLiteral("dispatcher"), QString::fromLatin1(w.disp));
                info.insert(QStringLiteral("arg"), QStringLiteral("%1%2").arg(QString::fromLatin1(w.prefix), QString::number(i)));
                info.insert(QStringLiteral("description"), QStringLiteral("%1 %2").arg(QString::fromLatin1(w.dLabel), QString::number(i)));
                parsedMap.insert(qMakePair(m, normK), info);
            }
        }
    }

    // 2. Directional arrows
    static const char* dirs[] = {"left", "right", "up", "down"};
    for (const auto* dStr : dirs) {
        const auto d = QString::fromLatin1(dStr);
        QVariantMap infoF;
        infoF.insert(QStringLiteral("dispatcher"), QStringLiteral("movefocus"));
        infoF.insert(QStringLiteral("arg"), d);
        infoF.insert(QStringLiteral("description"), QStringLiteral("Focus Window (%1)").arg(d));
        parsedMap.insert(qMakePair(64, d), infoF);

        QVariantMap infoM;
        infoM.insert(QStringLiteral("dispatcher"), QStringLiteral("movewindow"));
        infoM.insert(QStringLiteral("arg"), d);
        infoM.insert(QStringLiteral("description"), QStringLiteral("Move Window (%1)").arg(d));
        parsedMap.insert(qMakePair(65, d), infoM);
    }

    // 3. Scan all .lua files recursively
    QDirIterator it(hyprDir, QStringList() << QStringLiteral("*.lua"), QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const auto filePath = it.next();
        QFile file(filePath);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
            continue;

        const auto content = QString::fromUtf8(file.readAll());
        const auto calls = extractBindCalls(content);

        for (const auto& call : calls) {
            const auto& keyExpr = std::get<0>(call);
            const auto& dispExpr = std::get<1>(call);
            const auto& flagsExpr = std::get<2>(call);

            if ((keyExpr == QStringLiteral("key") || keyExpr == QStringLiteral("k")) && dispExpr == QStringLiteral("dispatcher"))
                continue;

            QStringList keysList;
            if (keyExpr.contains(QStringLiteral(".."))) {
                const auto parts = keyExpr.split(QStringLiteral(".."));
                QString fullKey;
                for (auto p : parts) {
                    p = p.trimmed();
                    if (p.startsWith(QStringLiteral("vars."))) {
                        fullKey += varsMap.value(p.mid(5), p);
                    } else if (p == QStringLiteral("mod") || p == QStringLiteral("mainMod")) {
                        fullKey += QStringLiteral("SUPER");
                    } else {
                        p.remove(QRegularExpression(QStringLiteral("^[\"']|[\"']$")));
                        fullKey += p;
                    }
                }
                if (!fullKey.trimmed().isEmpty()) {
                    keysList << fullKey.trimmed();
                }
            } else if (keyExpr.startsWith(QLatin1Char('{')) && keyExpr.endsWith(QLatin1Char('}'))) {
                const auto inner = keyExpr.mid(1, keyExpr.length() - 2);
                const auto parts = inner.split(QLatin1Char(','));
                for (auto rk : parts) {
                    rk = rk.trimmed();
                    if (rk.startsWith(QStringLiteral("vars."))) {
                        const auto val = varsMap.value(rk.mid(5), rk);
                        keysList << val.split(QLatin1Char(','));
                    } else {
                        rk.remove(QRegularExpression(QStringLiteral("^[\"']|[\"']$")));
                        if (!rk.isEmpty()) keysList << rk;
                    }
                }
            } else if (keyExpr.startsWith(QStringLiteral("vars."))) {
                const auto val = varsMap.value(keyExpr.mid(5), keyExpr);
                keysList << val.split(QLatin1Char(','));
            } else {
                QString kClean = keyExpr;
                kClean.remove(QRegularExpression(QStringLiteral("^[\"']|[\"']$")));
                if (!kClean.isEmpty()) keysList << kClean;
            }

            auto [disp, arg, desc] = resolveDispExpr(dispExpr, varsMap);
            if (flagsExpr.contains(QStringLiteral("description"))) {
                static const QRegularExpression regex(QStringLiteral("description\\s*=\\s*[\"']([^\"']+)[\"']"));
                auto md = regex.match(flagsExpr);
                if (md.hasMatch()) {
                    desc = md.captured(1);
                }
            }

            for (const auto& k : keysList) {
                const auto parts = k.split(QLatin1Char('+'));
                const auto keyName = parts.last().trimmed();
                QString modStr;
                if (parts.size() > 1) {
                    QStringList modParts = parts;
                    modParts.removeLast();
                    modStr = modParts.join(QStringLiteral(" + "));
                }
                const int mask = getModmask(modStr);
                const auto normK = normalizeKey(keyName);

                QVariantMap info;
                info.insert(QStringLiteral("dispatcher"), disp);
                info.insert(QStringLiteral("arg"), arg);
                info.insert(QStringLiteral("description"), desc);
                parsedMap.insert(qMakePair(mask, normK), info);
            }
        }
    }

    return parsedMap;
}

QVariantList KeybindManager::getBinds() {
    const auto rawJson = hyprRequest(QStringLiteral("j/binds"));
    if (rawJson.isEmpty()) {
        return QVariantList();
    }

    const auto doc = QJsonDocument::fromJson(rawJson);
    if (!doc.isArray()) {
        return QVariantList();
    }

    const auto hyprDir = getHyprConfigDir();
    const auto varsMap = parseLuaVariables(hyprDir + QStringLiteral("/variables.lua"));
    const auto parsedLuaMap = parseAllLuaBinds(hyprDir, varsMap);

    const auto jsonArr = doc.array();
    QVariantList results;
    QSet<QString> seenIds;

    for (const auto& val : jsonArr) {
        if (!val.isObject()) continue;
        auto obj = val.toObject();

        const int modmask = obj.value(QStringLiteral("modmask")).toInt();
        const QString key = obj.value(QStringLiteral("key")).toString();
        const QString normK = normalizeKey(key);
        QString disp = obj.value(QStringLiteral("dispatcher")).toString();
        QString arg = obj.value(QStringLiteral("arg")).toString();
        QString desc = obj.value(QStringLiteral("description")).toString();

        if (disp == QStringLiteral("__lua") || disp.isEmpty() || arg.isEmpty()) {
            const auto pairKey = qMakePair(modmask, normK);
            if (parsedLuaMap.contains(pairKey)) {
                const auto& info = parsedLuaMap.value(pairKey);
                disp = info.value(QStringLiteral("dispatcher")).toString();
                arg = info.value(QStringLiteral("arg")).toString();
                if (!info.value(QStringLiteral("description")).toString().isEmpty()) {
                    desc = info.value(QStringLiteral("description")).toString();
                }
            } else if (disp == QStringLiteral("__lua")) {
                disp = QStringLiteral("exec");
                arg = QStringLiteral("Lua Callback (%1)").arg(key);
                desc = QStringLiteral("Hyprland Lua Callback (%1)").arg(key);
            }
        }

        const QString bindId = QStringLiteral("%1:%2:%3:%4").arg(QString::number(modmask), key, disp, arg);
        if (!seenIds.contains(bindId)) {
            seenIds.insert(bindId);

            QVariantMap item = obj.toVariantMap();
            item.insert(QStringLiteral("dispatcher"), disp);
            item.insert(QStringLiteral("arg"), arg);
            item.insert(QStringLiteral("description"), desc);
            results.append(item);
        }
    }

    return results;
}

QString KeybindManager::formatLuaBind(const QString& mods, const QString& key, const QString& dispatcher, const QString& arg, const QString& flag, const QString& desc) const {
    const QString modStr = mods.trimmed();
    const QString keyStr = key.trimmed();
    const QString fullKey = modStr.isEmpty() ? keyStr : QStringLiteral("%1 + %2").arg(modStr, keyStr);

    const QString disp = dispatcher.trimmed().isEmpty() ? QStringLiteral("exec") : dispatcher.trimmed();
    const QString a = arg.trimmed();

    QString dispExpr;
    if (disp == QStringLiteral("exec")) {
        QString safeA = a;
        safeA.replace(QLatin1Char('\\'), QStringLiteral("\\\\")).replace(QLatin1Char('"'), QStringLiteral("\\\""));
        dispExpr = QStringLiteral("hl.dsp.exec_cmd(\"%1\")").arg(safeA);
    } else if (disp == QStringLiteral("global")) {
        dispExpr = QStringLiteral("hl.dsp.global(\"%1\")").arg(a);
    } else if (disp == QStringLiteral("killactive")) {
        dispExpr = QStringLiteral("hl.dsp.window.close()");
    } else if (disp == QStringLiteral("togglefloating")) {
        dispExpr = QStringLiteral("hl.dsp.window.float({ action = \"toggle\" })");
    } else if (disp == QStringLiteral("fullscreen")) {
        dispExpr = (a == QStringLiteral("1")) ? QStringLiteral("hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\" })")
                                             : QStringLiteral("hl.dsp.window.fullscreen({ mode = \"fullscreen\", action = \"toggle\" })");
    } else if (disp == QStringLiteral("pseudo")) {
        dispExpr = QStringLiteral("hl.dsp.window.pseudo()");
    } else if (disp == QStringLiteral("pin")) {
        dispExpr = QStringLiteral("hl.dsp.window.pin()");
    } else if (disp == QStringLiteral("centerwindow")) {
        dispExpr = QStringLiteral("hl.dsp.window.center()");
    } else if (disp == QStringLiteral("togglesplit")) {
        dispExpr = QStringLiteral("hl.dsp.layout(\"togglesplit\")");
    } else if (disp == QStringLiteral("togglegroup")) {
        dispExpr = QStringLiteral("hl.dsp.group.toggle()");
    } else if (disp == QStringLiteral("changegroupactive")) {
        dispExpr = (a == QStringLiteral("b")) ? QStringLiteral("hl.dsp.group.prev()") : QStringLiteral("hl.dsp.group.next()");
    } else if (disp == QStringLiteral("lockactivegroup")) {
        dispExpr = QStringLiteral("hl.dsp.group.lock_active()");
    } else if (disp == QStringLiteral("moveoutofgroup")) {
        dispExpr = QStringLiteral("hl.dsp.window.move({ out_of_group = true })");
    } else if (disp == QStringLiteral("movefocus")) {
        dispExpr = QStringLiteral("hl.dsp.focus({ direction = \"%1\" })").arg(a);
    } else if (disp == QStringLiteral("movewindow")) {
        dispExpr = QStringLiteral("hl.dsp.window.move({ direction = \"%1\" })").arg(a);
    } else if (disp == QStringLiteral("swapwindow")) {
        dispExpr = QStringLiteral("hl.dsp.window.swap({ direction = \"%1\" })").arg(a);
    } else if (disp == QStringLiteral("workspace")) {
        bool isNum = false;
        a.toInt(&isNum);
        dispExpr = isNum ? QStringLiteral("hl.dsp.focus({ workspace = %1 })").arg(a)
                         : QStringLiteral("hl.dsp.focus({ workspace = \"%1\" })").arg(a);
    } else if (disp == QStringLiteral("movetoworkspace")) {
        bool isNum = false;
        a.toInt(&isNum);
        dispExpr = isNum ? QStringLiteral("hl.dsp.window.move({ workspace = %1 })").arg(a)
                         : QStringLiteral("hl.dsp.window.move({ workspace = \"%1\" })").arg(a);
    } else if (disp == QStringLiteral("togglespecialworkspace")) {
        dispExpr = QStringLiteral("hl.dsp.workspace.toggle_special(\"%1\")").arg(a);
    } else if (disp == QStringLiteral("mouse")) {
        dispExpr = a.contains(QStringLiteral("resize")) ? QStringLiteral("hl.dsp.window.resize()") : QStringLiteral("hl.dsp.window.drag()");
    } else if (disp == QStringLiteral("exit")) {
        dispExpr = QStringLiteral("hl.dsp.exit()");
    } else {
        QString safeA = a;
        safeA.replace(QLatin1Char('\\'), QStringLiteral("\\\\")).replace(QLatin1Char('"'), QStringLiteral("\\\""));
        dispExpr = QStringLiteral("hl.dsp.exec_cmd(\"%1 %2\")").arg(disp, safeA).trimmed();
    }

    QStringList flagsList;
    if (flag == QStringLiteral("bindl") || flag.contains(QStringLiteral("locked"))) flagsList << QStringLiteral("locked = true");
    if (flag == QStringLiteral("bindr") || flag.contains(QStringLiteral("release"))) flagsList << QStringLiteral("release = true");
    if (flag == QStringLiteral("binde") || flag.contains(QStringLiteral("repeat"))) flagsList << QStringLiteral("repeating = true");
    if (flag == QStringLiteral("bindm") || flag.contains(QStringLiteral("mouse")) || fullKey.contains(QStringLiteral("mouse"), Qt::CaseInsensitive)) flagsList << QStringLiteral("mouse = true");
    if (!desc.trimmed().isEmpty()) {
        QString safeD = desc.trimmed();
        safeD.replace(QLatin1Char('\\'), QStringLiteral("\\\\")).replace(QLatin1Char('"'), QStringLiteral("\\\""));
        flagsList << QStringLiteral("description = \"%1\"").arg(safeD);
    }

    if (!flagsList.isEmpty()) {
        return QStringLiteral("hl.bind(\"%1\", %2, { %3 })").arg(fullKey, dispExpr, flagsList.join(QStringLiteral(", ")));
    }
    return QStringLiteral("hl.bind(\"%1\", %2)").arg(fullKey, dispExpr);
}

bool KeybindManager::matchesLuaBindLine(const QString& line, const QString& oldMods, const QString& oldKey, const QHash<QString, QString>& varsMap) const {
    const QString stripped = line.trimmed();
    if (stripped.startsWith(QStringLiteral("--")) || (!stripped.contains(QStringLiteral("bind(")) && !stripped.contains(QStringLiteral("create_bind(")))) {
        return false;
    }

    const int targetMask = getModmask(oldMods);
    const QString targetNormK = normalizeKey(oldKey);

    const auto calls = extractBindCalls(line);
    if (calls.isEmpty()) {
        const auto lLow = stripped.toLower();
        if (!oldKey.isEmpty() && (lLow.contains(QStringLiteral("\"%1\"").arg(oldKey.toLower())) || lLow.contains(QStringLiteral("'%1'").arg(oldKey.toLower())))) {
            return getModmask(stripped) == targetMask;
        }
        return false;
    }

    for (const auto& call : calls) {
        const auto& keyExpr = std::get<0>(call);
        QStringList resolvedKeys;
        if (keyExpr.contains(QStringLiteral(".."))) {
            const auto parts = keyExpr.split(QStringLiteral(".."));
            QString fullKey;
            for (auto p : parts) {
                p = p.trimmed();
                if (p.startsWith(QStringLiteral("vars."))) {
                    fullKey += varsMap.value(p.mid(5), p);
                } else if (p == QStringLiteral("mod") || p == QStringLiteral("mainMod")) {
                    fullKey += QStringLiteral("SUPER");
                } else {
                    p.remove(QRegularExpression(QStringLiteral("^[\"']|[\"']$")));
                    fullKey += p;
                }
            }
            resolvedKeys << fullKey.trimmed();
        } else if (keyExpr.startsWith(QStringLiteral("vars."))) {
            const auto val = varsMap.value(keyExpr.mid(5), keyExpr);
            resolvedKeys << val.split(QLatin1Char(','));
        } else {
            QString kClean = keyExpr;
            kClean.remove(QRegularExpression(QStringLiteral("^[\"']|[\"']$")));
            resolvedKeys << kClean.trimmed();
        }

        for (const auto& rk : resolvedKeys) {
            const auto parts = rk.split(QLatin1Char('+'));
            const auto kName = parts.last().trimmed();
            QString mStr;
            if (parts.size() > 1) {
                QStringList modParts = parts;
                modParts.removeLast();
                mStr = modParts.join(QStringLiteral(" + "));
            }
            const int mask = getModmask(mStr);
            const QString normK = normalizeKey(kName);
            if (mask == targetMask && normK == targetNormK) {
                return true;
            }
        }
    }

    return false;
}

bool KeybindManager::matchesConfBindLine(const QString& line, const QString& oldMods, const QString& oldKey) const {
    const QString stripped = line.trimmed();
    if (stripped.startsWith(QLatin1Char('#')) || !stripped.contains(QStringLiteral("bind")) || !stripped.contains(QLatin1Char('='))) {
        return false;
    }

    const auto parts = stripped.split(QLatin1Char('='));
    if (parts.size() < 2) return false;

    const auto commaParts = parts.at(1).split(QLatin1Char(','));
    if (commaParts.size() >= 2) {
        const QString lMods = commaParts.at(0).trimmed();
        const QString lKey = commaParts.at(1).trimmed();

        const int targetMask = getModmask(oldMods);
        const int lineMask = getModmask(lMods);
        const QString targetNormK = normalizeKey(oldKey);
        const QString lineNormK = normalizeKey(lKey);

        return (targetMask == lineMask && targetNormK == lineNormK);
    }
    return false;
}

bool KeybindManager::saveKeybind(const QString& action,
                                const QString& oldMods,
                                const QString& oldKey,
                                const QString& newMods,
                                const QString& newKey,
                                const QString& newDispatcher,
                                const QString& newArg,
                                const QString& newFlag,
                                const QString& desc) {
    const QString hyprDir = getHyprConfigDir();
    const bool isLua = isLuaHyprland();

    QString targetFilePath;
    if (isLua) {
        static const char* candidates[] = {
            "/hyprland/keybinds.lua",
            "/lua/binds.lua",
            "/keybinds.lua",
            "/binds.lua",
            "/hyprland.lua"
        };
        for (const auto* c : candidates) {
            const auto p = hyprDir + QString::fromLatin1(c);
            if (QFile::exists(p)) {
                targetFilePath = p;
                break;
            }
        }
        if (targetFilePath.isEmpty()) {
            targetFilePath = hyprDir + (QDir(hyprDir + QStringLiteral("/hyprland")).exists() ? QStringLiteral("/hyprland/keybinds.lua") : QStringLiteral("/keybinds.lua"));
        }
    } else {
        static const char* candidates[] = {
            "/hyprland/keybinds.conf",
            "/keybinds.conf",
            "/binds.conf",
            "/hyprland.conf"
        };
        for (const auto* c : candidates) {
            const auto p = hyprDir + QString::fromLatin1(c);
            if (QFile::exists(p)) {
                targetFilePath = p;
                break;
            }
        }
        if (targetFilePath.isEmpty()) {
            targetFilePath = hyprDir + (QDir(hyprDir + QStringLiteral("/hyprland")).exists() ? QStringLiteral("/hyprland/keybinds.conf") : QStringLiteral("/hyprland.conf"));
        }
    }

    QFileInfo fi(targetFilePath);
    QDir().mkpath(fi.absolutePath());

    QStringList lines;
    if (QFile::exists(targetFilePath)) {
        QFile file(targetFilePath);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream stream(&file);
            while (!stream.atEnd()) {
                lines << stream.readLine();
            }
        }
    }

    const auto varsMap = parseLuaVariables(hyprDir + QStringLiteral("/variables.lua"));
    const QString flag = newFlag.trimmed().isEmpty() ? QStringLiteral("bind") : newFlag.trimmed();

    if (isLua) {
        const QString newLine = formatLuaBind(newMods, newKey, newDispatcher, newArg, flag, desc);
        bool found = false;
        QStringList newLines;

        for (const auto& line : lines) {
            if (matchesLuaBindLine(line, oldMods, oldKey, varsMap)) {
                found = true;
                if (action == QStringLiteral("delete")) {
                    continue;
                } else if (action == QStringLiteral("update")) {
                    newLines << newLine;
                    continue;
                }
            }
            newLines << line;
        }

        if ((action == QStringLiteral("add") || (action == QStringLiteral("update") && !found)) && !newLine.isEmpty()) {
            newLines << QStringLiteral("\n-- Custom Keybinding via Olvex\n") + newLine;
        }

        QFile outFile(targetFilePath);
        if (outFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream outStream(&outFile);
            for (const auto& l : newLines) {
                outStream << l << QLatin1Char('\n');
            }
        }

        // Trigger live reload
        hyprRequest(QStringLiteral("reload"));

    } else {
        const QString newLine = QStringLiteral("%1 = %2, %3, %4, %5").arg(flag, newMods, newKey, newDispatcher, newArg);
        bool found = false;
        QStringList newLines;

        for (const auto& line : lines) {
            if (matchesConfBindLine(line, oldMods, oldKey)) {
                found = true;
                if (action == QStringLiteral("delete")) {
                    continue;
                } else if (action == QStringLiteral("update")) {
                    newLines << newLine;
                    continue;
                }
            }
            newLines << line;
        }

        if ((action == QStringLiteral("add") || (action == QStringLiteral("update") && !found)) && !newLine.isEmpty()) {
            newLines << QStringLiteral("\n# Custom Keybinding via Olvex\n") + newLine;
        }

        QFile outFile(targetFilePath);
        if (outFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream outStream(&outFile);
            for (const auto& l : newLines) {
                outStream << l << QLatin1Char('\n');
            }
        }

        // Live unbind & bind
        if ((action == QStringLiteral("delete") || action == QStringLiteral("update")) && !oldKey.isEmpty()) {
            const QString unbindFlag = flag.startsWith(QStringLiteral("bind")) ? QString(flag).replace(QStringLiteral("bind"), QStringLiteral("unbind")) : QStringLiteral("unbind");
            const QString oldFormatted = oldMods.isEmpty() ? QStringLiteral(", ") : QStringLiteral("%1, ").arg(oldMods);
            hyprRequest(QStringLiteral("keyword %1 %2%3").arg(unbindFlag, oldFormatted, oldKey));
        }
        if ((action == QStringLiteral("add") || action == QStringLiteral("update")) && !newKey.isEmpty()) {
            const QString newFormatted = newMods.isEmpty() ? QStringLiteral(", ") : QStringLiteral("%1, ").arg(newMods);
            hyprRequest(QStringLiteral("keyword %1 %2%3, %4, %5").arg(flag, newFormatted, newKey, newDispatcher, newArg));
        }
    }

    emit bindsChanged();
    return true;
}

bool KeybindManager::deleteKeybind(const QString& mods, const QString& key, const QString& flag) {
    return saveKeybind(QStringLiteral("delete"), mods, key, QString(), QString(), QString(), QString(), flag, QString());
}

} // namespace olvex
