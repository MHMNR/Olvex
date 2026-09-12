#include "cutils.hpp"

#include <QtConcurrent/qtconcurrentrun.h>
#include <QtQuick/qquickitemgrabresult.h>
#include <QtQuick/qquickwindow.h>
#include <QtGui/qfont.h>
#include <QtGui/qfontmetrics.h>
#include <QtGui/qrawfont.h>
#include <QtGui/qpainterpath.h>
#include <qdir.h>
#include <qfileinfo.h>
#include <qfuturewatcher.h>
#include <qloggingcategory.h>
#include <qqmlengine.h>

Q_LOGGING_CATEGORY(lcCUtils, "olvex.cutils", QtInfoMsg)

namespace olvex {

void CUtils::saveItem(QQuickItem* target, const QUrl& path) {
    this->saveItem(target, path, QRect(), QJSValue(), QJSValue());
}

void CUtils::saveItem(QQuickItem* target, const QUrl& path, const QRect& rect) {
    this->saveItem(target, path, rect, QJSValue(), QJSValue());
}

void CUtils::saveItem(QQuickItem* target, const QUrl& path, QJSValue onSaved) {
    this->saveItem(target, path, QRect(), onSaved, QJSValue());
}

void CUtils::saveItem(QQuickItem* target, const QUrl& path, QJSValue onSaved, QJSValue onFailed) {
    this->saveItem(target, path, QRect(), onSaved, onFailed);
}

void CUtils::saveItem(QQuickItem* target, const QUrl& path, const QRect& rect, QJSValue onSaved) {
    this->saveItem(target, path, rect, onSaved, QJSValue());
}

void CUtils::saveItem(QQuickItem* target, const QUrl& path, const QRect& rect, QJSValue onSaved, QJSValue onFailed) {
    if (!target) {
        qCWarning(lcCUtils) << "saveItem: a target is required";
        return;
    }

    if (!path.isLocalFile()) {
        qCWarning(lcCUtils) << "saveItem:" << path << "is not a local file";
        return;
    }

    if (!target->window()) {
        qCWarning(lcCUtils) << "saveItem: unable to save target" << target << "without a window";
        return;
    }

    auto scaledRect = rect;
    const qreal scale = target->window()->devicePixelRatio();
    if (rect.isValid() && !qFuzzyCompare(scale + 1.0, 2.0)) {
        scaledRect =
            QRectF(rect.left() * scale, rect.top() * scale, rect.width() * scale, rect.height() * scale).toRect();
    }

    const QSharedPointer<const QQuickItemGrabResult> grabResult = target->grabToImage();

    QObject::connect(grabResult.data(), &QQuickItemGrabResult::ready, this,
        [grabResult, scaledRect, path, onSaved, onFailed, this]() {
            const auto future = QtConcurrent::run([=]() {
                QImage image = grabResult->image();

                if (scaledRect.isValid()) {
                    image = image.copy(scaledRect);
                }

                const QString file = path.toLocalFile();
                const QString parent = QFileInfo(file).absolutePath();
                return QDir().mkpath(parent) && image.save(file);
            });

            auto* watcher = new QFutureWatcher<bool>(this);
            auto* engine = qmlEngine(this);

            QObject::connect(watcher, &QFutureWatcher<bool>::finished, this, [=]() {
                if (watcher->result()) {
                    if (onSaved.isCallable()) {
                        QJSValueList args = { QJSValue(path.toLocalFile()) };
                        if (engine) {
                            args << engine->toScriptValue(QVariant::fromValue(path));
                        }
                        onSaved.call(args);
                    }
                } else {
                    qCWarning(lcCUtils) << "saveItem: failed to save" << path;
                    if (onFailed.isCallable()) {
                        if (engine) {
                            onFailed.call({ engine->toScriptValue(QVariant::fromValue(path)) });
                        } else {
                            onFailed.call();
                        }
                    }
                }
                watcher->deleteLater();
            });
            watcher->setFuture(future);
        });
}

bool CUtils::copyFile(const QUrl& source, const QUrl& target, bool overwrite) const {
    if (!source.isLocalFile()) {
        qCWarning(lcCUtils) << "copyFile: source" << source << "is not a local file";
        return false;
    }
    if (!target.isLocalFile()) {
        qCWarning(lcCUtils) << "copyFile: target" << target << "is not a local file";
        return false;
    }

    if (overwrite && QFile::exists(target.toLocalFile())) {
        if (!QFile::remove(target.toLocalFile())) {
            qCWarning(lcCUtils) << "copyFile: overwrite was specified but failed to remove" << target.toLocalFile();
            return false;
        }
    }

    return QFile::copy(source.toLocalFile(), target.toLocalFile());
}

bool CUtils::deleteFile(const QUrl& path) const {
    if (!path.isLocalFile()) {
        qCWarning(lcCUtils) << "deleteFile: path" << path << "is not a local file";
        return false;
    }

    return QFile::remove(path.toLocalFile());
}

QString CUtils::toLocalFile(const QUrl& url) const {
    if (!url.isLocalFile()) {
        qCWarning(lcCUtils) << "toLocalFile: given url is not a local file" << url;
        return QString();
    }

    return url.toLocalFile();
}

qreal CUtils::clamp(qreal value, qreal min, qreal max) {
    return qBound(min, value, max);
}

bool CUtils::fileExists(const QString& path) const {
    if (path.isEmpty()) return false;
    return QFileInfo::exists(path);
}

bool CUtils::writeTextFile(const QString& path, const QString& content) const {
    if (path.isEmpty()) return false;
    QFileInfo fi(path);
    QDir().mkpath(fi.absolutePath());
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        qCWarning(lcCUtils) << "writeTextFile: failed to open" << path << "for writing:" << file.errorString();
        return false;
    }
    QTextStream out(&file);
    out << content;
    return true;
}

QString CUtils::readTextFile(const QString& path) const {
    if (path.isEmpty()) return {};
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }
    return QString::fromUtf8(file.readAll());
}

QString CUtils::distroGlyph(const QString& id, const QStringList& idLike, const QString& name) const {
    static const QHash<QString, QString> distroMap = {
        // Arch and Arch-based distros (distinct native glyphs)
        { QStringLiteral("arch"), QString::fromUtf8("\uf303") },
        { QStringLiteral("archlinux"), QString::fromUtf8("\uf303") },
        { QStringLiteral("endeavouros"), QString::fromUtf8("\uf322") },
        { QStringLiteral("endeavour"), QString::fromUtf8("\uf322") },
        { QStringLiteral("garuda"), QString::fromUtf8("\uf337") },
        { QStringLiteral("cachyos"), QString::fromUtf8("\uf385") },
        { QStringLiteral("archcraft"), QString::fromUtf8("\uf345") },
        { QStringLiteral("arcolinux"), QString::fromUtf8("\uf346") },
        { QStringLiteral("artix"), QString::fromUtf8("\uf31f") },
        { QStringLiteral("biglinux"), QString::fromUtf8("\uf347") },
        { QStringLiteral("xerolinux"), QString::fromUtf8("\uf34a") },
        { QStringLiteral("blackarch"), QString::fromUtf8("\uf303") },
        { QStringLiteral("rebornos"), QString::fromUtf8("\uf303") },
        { QStringLiteral("manjaro"), QString::fromUtf8("\uf312") },

        // NixOS
        { QStringLiteral("nixos"), QString::fromUtf8("\uf313") },

        // Fedora / Red Hat family
        { QStringLiteral("fedora"), QString::fromUtf8("\uf30a") },
        { QStringLiteral("nobara"), QString::fromUtf8("\uf380") },
        { QStringLiteral("ultramarine"), QString::fromUtf8("\uf30a") },
        { QStringLiteral("rhel"), QString::fromUtf8("\uf316") },
        { QStringLiteral("redhat"), QString::fromUtf8("\uf316") },
        { QStringLiteral("centos"), QString::fromUtf8("\uf304") },
        { QStringLiteral("rocky"), QString::fromUtf8("\uf32b") },
        { QStringLiteral("almalinux"), QString::fromUtf8("\uf31d") },
        { QStringLiteral("oracle"), QString::fromUtf8("\uf316") },

        // Debian
        { QStringLiteral("debian"), QString::fromUtf8("\uf306") },
        { QStringLiteral("raspbian"), QString::fromUtf8("\uf315") },
        { QStringLiteral("raspberry"), QString::fromUtf8("\uf315") },
        { QStringLiteral("raspberrypi"), QString::fromUtf8("\uf315") },
        { QStringLiteral("tails"), QString::fromUtf8("\uf343") },
        { QStringLiteral("kali"), QString::fromUtf8("\uf327") },
        { QStringLiteral("kalilinux"), QString::fromUtf8("\uf327") },
        { QStringLiteral("devuan"), QString::fromUtf8("\uf307") },
        { QStringLiteral("parrot"), QString::fromUtf8("\uf329") },
        { QStringLiteral("qubesos"), QString::fromUtf8("\uf342") },
        { QStringLiteral("mxlinux"), QString::fromUtf8("\uf33f") },
        { QStringLiteral("puppy"), QString::fromUtf8("\uf341") },

        // Ubuntu family
        { QStringLiteral("ubuntu"), QString::fromUtf8("\uf31b") },
        { QStringLiteral("zorin"), QString::fromUtf8("\uf32f") },
        { QStringLiteral("pop"), QString::fromUtf8("\uf32a") },
        { QStringLiteral("pop-os"), QString::fromUtf8("\uf32a") },
        { QStringLiteral("pop_os"), QString::fromUtf8("\uf32a") },
        { QStringLiteral("mint"), QString::fromUtf8("\uf30e") },
        { QStringLiteral("linuxmint"), QString::fromUtf8("\uf30e") },
        { QStringLiteral("elementary"), QString::fromUtf8("\uf309") },
        { QStringLiteral("elementaryos"), QString::fromUtf8("\uf309") },
        { QStringLiteral("neon"), QString::fromUtf8("\uf331") },
        { QStringLiteral("kubuntu"), QString::fromUtf8("\uf333") },
        { QStringLiteral("budgie"), QString::fromUtf8("\uf320") },

        // Independent / Other Distros & OS
        { QStringLiteral("void"), QString::fromUtf8("\uf32e") },
        { QStringLiteral("voidlinux"), QString::fromUtf8("\uf32e") },
        { QStringLiteral("alpine"), QString::fromUtf8("\uf300") },
        { QStringLiteral("alpinelinux"), QString::fromUtf8("\uf300") },
        { QStringLiteral("gentoo"), QString::fromUtf8("\uf30d") },
        { QStringLiteral("opensuse"), QString::fromUtf8("\uf314") },
        { QStringLiteral("opensuse-tumbleweed"), QString::fromUtf8("\uf37d") },
        { QStringLiteral("tumbleweed"), QString::fromUtf8("\uf37d") },
        { QStringLiteral("opensuse-leap"), QString::fromUtf8("\uf37e") },
        { QStringLiteral("leap"), QString::fromUtf8("\uf37e") },
        { QStringLiteral("suse"), QString::fromUtf8("\uf314") },
        { QStringLiteral("slackware"), QString::fromUtf8("\uf318") },
        { QStringLiteral("solus"), QString::fromUtf8("\uf32d") },
        { QStringLiteral("mageia"), QString::fromUtf8("\uf310") },
        { QStringLiteral("freebsd"), QString::fromUtf8("\uf30c") },
        { QStringLiteral("openbsd"), QString::fromUtf8("\uf328") },
        { QStringLiteral("netbsd"), QString::fromUtf8("\uf30c") },
        { QStringLiteral("chimera"), QString::fromUtf8("\uf31a") },
        { QStringLiteral("vanilla"), QString::fromUtf8("\uf366") },
        { QStringLiteral("postmarketos"), QString::fromUtf8("\uf374") },
        { QStringLiteral("linux"), QString::fromUtf8("\uf31a") },
        { QStringLiteral("tux"), QString::fromUtf8("\uf31a") },
        { QStringLiteral("apple"), QString::fromUtf8("\uf302") },
        { QStringLiteral("macos"), QString::fromUtf8("\uf302") },
        { QStringLiteral("windows"), QString::fromUtf8("\uf17a") },
        { QStringLiteral("android"), QString::fromUtf8("\uf17b") },

        // Tech, Tools, Developer & Community Icons
        { QStringLiteral("hyprland"), QString::fromUtf8("\uf359") },
        { QStringLiteral("wayland"), QString::fromUtf8("\uf367") },
        { QStringLiteral("terminal"), QString::fromUtf8("\uf120") },
        { QStringLiteral("code"), QString::fromUtf8("\uf121") },
        { QStringLiteral("git"), QString::fromUtf8("\uf1d3") },
        { QStringLiteral("github"), QString::fromUtf8("\uf09b") },
        { QStringLiteral("docker"), QString::fromUtf8("\uf308") },
        { QStringLiteral("neovim"), QString::fromUtf8("\uf36f") },
        { QStringLiteral("rust"), QString::fromUtf8("\uf323") },
        { QStringLiteral("python"), QString::fromUtf8("\ue73c") },
        { QStringLiteral("flathub"), QString::fromUtf8("\uf324") },
        { QStringLiteral("qt"), QString::fromUtf8("\uf375") },
        { QStringLiteral("gnome"), QString::fromUtf8("\uf361") },
        { QStringLiteral("plasma"), QString::fromUtf8("\uf332") },
        { QStringLiteral("rocket"), QString::fromUtf8("\uf135") },
        { QStringLiteral("fire"), QString::fromUtf8("\uf06d") },
        { QStringLiteral("sparkles"), QString::fromUtf8("\ue28e") },
        { QStringLiteral("lightning"), QString::fromUtf8("\uf0e7") },
        { QStringLiteral("heart"), QString::fromUtf8("\uf004") },
        { QStringLiteral("star"), QString::fromUtf8("\uf005") },
        { QStringLiteral("coffee"), QString::fromUtf8("\uf0f4") },
        { QStringLiteral("diamond"), QString::fromUtf8("\uf219") },
        { QStringLiteral("ghost"), QString::fromUtf8("\uf1e0") },
        { QStringLiteral("music"), QString::fromUtf8("\uf001") },
        { QStringLiteral("gamepad"), QString::fromUtf8("\uf11b") }
    };

    const auto fallbackGlyph = QString::fromUtf8("\uf31a");

    if (!id.isEmpty()) {
        const QString cleanId = id.trimmed().toLower();
        auto it = distroMap.constFind(cleanId);
        if (it != distroMap.constEnd()) {
            return it.value();
        }
    }

    for (const QString& like : idLike) {
        const QString cleanLike = like.trimmed().toLower();
        if (!cleanLike.isEmpty()) {
            auto it = distroMap.constFind(cleanLike);
            if (it != distroMap.constEnd()) {
                return it.value();
            }
        }
    }

    if (!name.isEmpty()) {
        const QString cleanName = name.toLower();
        for (auto it = distroMap.constBegin(); it != distroMap.constEnd(); ++it) {
            if (cleanName.contains(it.key())) {
                return it.value();
            }
        }
    }

    return fallbackGlyph;
}

qreal CUtils::glyphHOffset(const QString& glyph, int pixelSize, const QString& family) const {
    if (glyph.isEmpty()) return 0.0;

    QStringList candidates;
    if (!family.isEmpty()) candidates << family;
    candidates << QStringLiteral("CaskaydiaCove NF")
               << QStringLiteral("CaskaydiaCove Nerd Font")
               << QStringLiteral("CaskaydiaCove Nerd Font Mono")
               << QStringLiteral("Symbols Nerd Font")
               << QStringLiteral("monospace");
    candidates.removeDuplicates();

    for (const auto& fam : candidates) {
        QFont font(fam);
        font.setPixelSize(pixelSize > 0 ? pixelSize : 24);
        QRawFont raw = QRawFont::fromFont(font);
        auto indexes = raw.glyphIndexesForString(glyph);
        if (!indexes.isEmpty() && indexes.first() != 0) {
            QPainterPath path = raw.pathForGlyph(indexes.first());
            QRectF br = path.boundingRect();
            if (!br.isEmpty()) {
                QFontMetrics fm(font);
                qreal glyphCenterX = br.x() + br.width() / 2.0;
                qreal textCenterX = fm.horizontalAdvance(glyph) / 2.0;
                return -(glyphCenterX - textCenterX);
            }
        }
    }
    return 0.0;
}

qreal CUtils::glyphVOffset(const QString& glyph, int pixelSize, const QString& family) const {
    if (glyph.isEmpty()) return 0.0;

    QStringList candidates;
    if (!family.isEmpty()) candidates << family;
    candidates << QStringLiteral("CaskaydiaCove NF")
               << QStringLiteral("CaskaydiaCove Nerd Font")
               << QStringLiteral("CaskaydiaCove Nerd Font Mono")
               << QStringLiteral("Symbols Nerd Font")
               << QStringLiteral("monospace");
    candidates.removeDuplicates();

    for (const auto& fam : candidates) {
        QFont font(fam);
        font.setPixelSize(pixelSize > 0 ? pixelSize : 24);
        QRawFont raw = QRawFont::fromFont(font);
        auto indexes = raw.glyphIndexesForString(glyph);
        if (!indexes.isEmpty() && indexes.first() != 0) {
            QPainterPath path = raw.pathForGlyph(indexes.first());
            QRectF br = path.boundingRect();
            if (!br.isEmpty()) {
                QFontMetrics fm(font);
                qreal glyphCenterY = fm.ascent() + br.y() + br.height() / 2.0;
                qreal textCenterY = fm.height() / 2.0;
                return -(glyphCenterY - textCenterY);
            }
        }
    }
    return 0.0;
}

} // namespace olvex
