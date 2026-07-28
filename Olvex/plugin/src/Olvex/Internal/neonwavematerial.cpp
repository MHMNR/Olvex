#include "neonwavematerial.hpp"

#include <cstring>

namespace olvex::internal {

QSGMaterialType *NeonWaveMaterial::type() const
{
    static QSGMaterialType s_type;
    return &s_type;
}

QSGMaterialShader *NeonWaveMaterial::createShader(QSGRendererInterface::RenderMode) const
{
    return new NeonWaveMaterialShader;
}

int NeonWaveMaterial::compare(const QSGMaterial *other) const
{
    if (this < other)
        return -1;
    if (this > other)
        return 1;
    return 0;
}

NeonWaveMaterialShader::NeonWaveMaterialShader()
{
    setShaderFileName(VertexStage, QStringLiteral(":/shaders/neonwave.vert.qsb"));
    setShaderFileName(FragmentStage, QStringLiteral(":/shaders/neonwave.frag.qsb"));
}

bool NeonWaveMaterialShader::updateUniformData(RenderState &state, QSGMaterial *newMaterial, QSGMaterial *oldMaterial)
{
    Q_UNUSED(oldMaterial);
    auto *mat = static_cast<NeonWaveMaterial *>(newMaterial);
    QByteArray *buf = state.uniformData();
    Q_ASSERT(buf->size() >= 272);

    if (state.isMatrixDirty()) {
        const QMatrix4x4 matrix = state.combinedMatrix();
        memcpy(buf->data(), matrix.constData(), 64);
    }

    if (state.isOpacityDirty()) {
        const float opacity = state.opacity();
        memcpy(buf->data() + 64, &opacity, 4);
    }

    memcpy(buf->data() + 68, &mat->m_width, 4);
    memcpy(buf->data() + 72, &mat->m_height, 4);
    memcpy(buf->data() + 76, &mat->m_maxHeightRatio, 4);
    memcpy(buf->data() + 80, &mat->m_edgeFeather, 4);
    memcpy(buf->data() + 84, &mat->m_topFadeRatio, 4);
    memcpy(buf->data() + 88, &mat->m_bandCount, 4);

    const float accent[4] = {
        static_cast<float>(mat->m_accentColor.redF()),
        static_cast<float>(mat->m_accentColor.greenF()),
        static_cast<float>(mat->m_accentColor.blueF()),
        static_cast<float>(mat->m_accentColor.alphaF()),
    };
    const float boosted[4] = {
        static_cast<float>(mat->m_boostedColor.redF()),
        static_cast<float>(mat->m_boostedColor.greenF()),
        static_cast<float>(mat->m_boostedColor.blueF()),
        static_cast<float>(mat->m_boostedColor.alphaF()),
    };

    memcpy(buf->data() + 112, accent, 16);
    memcpy(buf->data() + 128, boosted, 16);
    memcpy(buf->data() + 144, mat->m_values.data(), mat->m_values.size() * sizeof(float));

    return true;
}

} // namespace olvex::internal
