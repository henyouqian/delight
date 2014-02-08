#ifndef __UTIL_H__
#define __UTIL_H__

#include "cocos2d.h"
#include "cocos-ext.h"

#include "qiniu/io.h"

USING_NS_CC;
USING_NS_CC_EXT;

void makeLocalDir();
void makeLocalPackPath(std::string &outPath, int packIdx);
void makeLocalImagePath(std::string &outPath, const char *url);
void makeLocalGifPath(std::string &outPath, const char *fullPath);

ControlButton *createButton(const char *text, float fontSize, float bgScale);
ControlButton *createRingButton(const char *text, float fontSize, float bgScale, const Color3B &color);
ControlButton *createColorButton(const char *text, float fontSize, float bgScale, const Color3B &labelColor, const Color3B &bgColor, GLubyte bgOpacity);

const char* getUploadPackDir();

//qiniu
void qiniuInit();
void qiniuQuit();
Qiniu_Client* qiniuGetClient();

class QiniuUploaderListener {
public:
    virtual void onQiniuUploadSuccess() {};
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


#endif // __UTIL_H__
