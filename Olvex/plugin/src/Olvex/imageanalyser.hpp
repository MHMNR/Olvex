#pragma once

#include <QtQuick/qquickitem.h>
#include <qfuture.h>
#include <qfuturewatcher.h>
#include <qobject.h>
#include <qpointer.h>
#include <qqmlintegration.h>

namespace olvex {

class ImageAnalyser : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(QQuickItem* sourceItem READ sourceItem WRITE setSourceItem NOTIFY sourceItemChanged)
    Q_PROPERTY(int rescaleSize READ rescaleSize WRITE setRescaleSize NOTIFY rescaleSizeChanged)
    // "wallpaper" = wallpaper picker scoring; "albumArt" = music thumbnail (saturation-first)
    Q_PROPERTY(QString profile READ profile WRITE setProfile NOTIFY profileChanged)
    Q_PROPERTY(QColor dominantColour READ dominantColour NOTIFY dominantColourChanged)
    Q_PROPERTY(qreal luminance READ luminance NOTIFY luminanceChanged)

public:
    explicit ImageAnalyser(QObject* parent = nullptr);

    [[nodiscard]] QString source() const;
    void setSource(const QString& source);

    [[nodiscard]] QQuickItem* sourceItem() const;
    void setSourceItem(QQuickItem* sourceItem);

    [[nodiscard]] int rescaleSize() const;
    void setRescaleSize(int rescaleSize);

    [[nodiscard]] QString profile() const;
    void setProfile(const QString& profile);

    [[nodiscard]] QColor dominantColour() const;
    [[nodiscard]] qreal luminance() const;

    Q_INVOKABLE void requestUpdate();

signals:
    void sourceChanged();
    void sourceItemChanged();
    void rescaleSizeChanged();
    void profileChanged();
    void dominantColourChanged();
    void luminanceChanged();

private:
    using AnalyseResult = QPair<QColor, qreal>;

    QFutureWatcher<AnalyseResult>* const m_futureWatcher;

    QString m_source;
    QPointer<QQuickItem> m_sourceItem;
    int m_rescaleSize;
    QString m_profile;

    QColor m_dominantColour;
    qreal m_luminance;

    void update();
    static void analyse(QPromise<AnalyseResult>& promise, const QImage& image, int rescaleSize, const QString& profile);
};

} // namespace olvex
