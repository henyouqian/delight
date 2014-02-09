#ifndef __QINIU_H__
#define __QINIU_H__

#include "cocos2d.h"
#include "cocos-ext.h"

#include "qiniu/io.h"

USING_NS_CC;
USING_NS_CC_EXT;

void qiniuInit();
void qiniuQuit();
Qiniu_Client* qiniuGetClient();

class QiniuUploaderListener {
public:
    virtual void onQiniuUploadSuccess(const char* key) {};
    virtual void onQiniuUploadError() {};
};

class QiniuUploader {
public:
    QiniuUploader(QiniuUploaderListener *listener);
    void destroy();
    
    void addFile(const char* uptoken, const char* key, const char* localFilePath);
    
private:
    ~QiniuUploader();
    void threadFunc();
    QiniuUploaderListener *_listener;
    
    std::thread *_thread;
    std::mutex _mutex;
    std::condition_variable _cv;
    
    bool _done;
    
    struct FileInfo {
        std::string uptoken;
        std::string key;
        std::string localFilePath;
    };
    std::list<FileInfo> _files;
};


#endif // __QINIU_H__
