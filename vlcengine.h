#ifndef VLCENGINE_H
#define VLCENGINE_H

#include <QObject>
#include <vlc/vlc.h>

class VlcEngine : public QObject {
    Q_OBJECT
public:
    static VlcEngine* instance();

    libvlc_instance_t* core() const;
    bool isReady() const;

signals:
    void engineReady();

private:
    explicit VlcEngine(QObject *parent = nullptr);
    ~VlcEngine();

    libvlc_instance_t *m_vlcInstance;
    bool m_ready;
};

#endif
