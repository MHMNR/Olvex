qml_module(olvex-blobs
    URI Olvex.Blobs
    SOURCES
        blobgroup.cpp
        blobshape.cpp
        blobrect.cpp
        blobinvertedrect.cpp
        blobmaterial.cpp
    LIBRARIES
        Qt::Quick
)

qt_add_shaders(olvex-blobs "blob_shaders"
    BATCHABLE OPTIMIZED NOHLSL NOMSL
    PREFIX "/"
    FILES
        shaders/blob.frag
        shaders/blob.vert
)
