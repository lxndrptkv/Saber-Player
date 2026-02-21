#include "vlcengine.h"
#include <QThreadPool>

VlcEngine* VlcEngine::instance() {
    static VlcEngine _instance;
    return &_instance;
}

VlcEngine::VlcEngine(QObject *parent) : QObject(parent), m_vlcInstance(nullptr), m_ready(false) {
    // Push the heavy VLC module scanning to a background thread
    QThreadPool::globalInstance()->start([this]() {
        const char * const vlc_args[] = {
            "--intf=dummy",
            "--ignore-config",
            "--quiet",
            "--no-video",
            "--no-sub-autodetect-file"
        };

        libvlc_instance_t *vlc = libvlc_new(sizeof(vlc_args) / sizeof(vlc_args[0]), vlc_args);

        // Safely hand the loaded engine back to the main UI thread
        QMetaObject::invokeMethod(this, [this, vlc]() {
            m_vlcInstance = vlc;
            m_ready = true;
            emit engineReady();
        });
    });
}

VlcEngine::~VlcEngine() {
    if (m_vlcInstance) {
        libvlc_release(m_vlcInstance);
    }
}

libvlc_instance_t* VlcEngine::core() const {
    return m_vlcInstance;
}

bool VlcEngine::isReady() const {
    return m_ready;
}
