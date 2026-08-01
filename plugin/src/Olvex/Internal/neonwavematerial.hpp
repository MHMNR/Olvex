#pragma once

#include <array>
#include <qcolor.h>
#include <qsgmaterial.h>
#include <qsgmaterialshader.h>

namespace olvex::internal {

class NeonWaveMaterial : public QSGMaterial {
public:
    QSGMaterialType *type() const override;
    QSGMaterialShader *createShader(QSGRendererInterface::RenderMode) const override;
    int compare(const QSGMaterial *other) const override;

    float m_width = 0.0f;
    float m_height = 0.0f;
    float m_maxHeightRatio = 0.85f;
    float m_edgeFeather = 1.8f;
    float m_topFadeRatio = 0.0f;
    int m_bandCount = 32;
    QColor m_accentColor;
    QColor m_boostedColor;
    std::array<float, 32> m_values = {};
};

class NeonWaveMaterialShader : public QSGMaterialShader {
public:
    NeonWaveMaterialShader();
    bool updateUniformData(RenderState &state, QSGMaterial *newMaterial, QSGMaterial *oldMaterial) override;
};

} // namespace olvex::internal
