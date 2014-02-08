#include "util.h"
#include "crypto/sha.h"
#include <sys/stat.h>

USING_NS_CC;
USING_NS_CC_EXT;

namespace {
    std::string _imageDir;
    std::string _packDir;
    std::string _localGifDir;
    std::string _uploadPack;
    Qiniu_Client _qiniuClient;
}

void makeLocalDir() {
    auto wpath = FileUtils::getInstance()->getWritablePath();
    _imageDir = wpath;
    _imageDir += "images/";
    mkdir(_imageDir.c_str(), S_IRWXU);
    
    _packDir = wpath;
    _packDir += "packs/";
    mkdir(_packDir.c_str(), S_IRWXU);
    
    _localGifDir = wpath;
    _localGifDir += "localGif/";
    mkdir(_localGifDir.c_str(), S_IRWXU);
    
    _uploadPack = wpath;
    _uploadPack += "uploadPack/";
    mkdir(_uploadPack.c_str(), S_IRWXU);
}

const char* getUploadPackDir() {
    return _uploadPack.c_str();
}

void makeLocalPackPath(std::string &outPath, int packIdx) {
    outPath = _packDir;
    char buf[64];
    snprintf(buf, 64, "%d.pack", packIdx);
    outPath += buf;
}

void makeLocalImagePath(std::string &outPath, const char *url) {
    Sha1 sha1;
    sha1.write(url, strlen(url));
    sha1.final();
    
    outPath = _imageDir;
    outPath += sha1.getResult();
}

void makeLocalGifPath(std::string &outPath, const char *fullPath) {
    Sha1 sha1;
    sha1.write(fullPath, strlen(fullPath));
    sha1.final();
    
    outPath = _localGifDir;
    outPath += sha1.getResult();
}

ControlButton *createButton(const char *text, float fontSize, float bgScale) {
    auto label = LabelTTF::create(text, "HelveticaNeue", fontSize);
    auto spr = Scale9Sprite::create("ui/btnBg.png");
    spr->setScale(bgScale);
    spr->setOpacity(180);
    auto button = ControlButton::create(label, spr);
    button->setAdjustBackgroundImage(false);
    return button;
}

ControlButton *createRingButton(const char *text, float fontSize, float bgScale, const Color3B &color) {
    auto label = LabelTTF::create(text, "HelveticaNeue", fontSize);
    label->setColor(color);
    auto spr = Scale9Sprite::create("ui/whiteRing96.png");
    spr->setScale(bgScale);
    spr->setColor(color);
    auto button = ControlButton::create(label, spr);
    button->setAdjustBackgroundImage(false);
    return button;
}

ControlButton *createColorButton(const char *text, float fontSize, float bgScale, const Color3B &labelColor, const Color3B &bgColor, GLubyte bgOpacity) {
    auto label = LabelTTF::create(text, "HelveticaNeue", fontSize);
    label->setColor(labelColor);
    auto spr = Scale9Sprite::create("ui/btnBgWhite.png");
    spr->setScale(bgScale);
    spr->setColor(bgColor);
    spr->setOpacity(bgOpacity);
    auto button = ControlButton::create(label, spr);
    button->setAdjustBackgroundImage(false);
    return button;
}

void qiniuInit() {
    Qiniu_Global_Init(-1);
    Qiniu_Client_InitNoAuth(&_qiniuClient, 1024);
}

void qiniuQuit() {
    Qiniu_Client_Cleanup(&_qiniuClient);
    Qiniu_Global_Cleanup();
}

Qiniu_Client* qiniuGetClient() {
    return &_qiniuClient;
}

QiniuUploader::QiniuUploader(QiniuUploaderListener *listener) {
    _listener = listener;
    _thread = new std::thread(&QiniuUploader::threadFunc, this);
    _done = false;
}

QiniuUploader::~QiniuUploader() {
    delete _thread;
}

void QiniuUploader::destroy() {
    std::lock_guard<std::mutex> lock(_mutex);
    _done = true;
    _listener = nullptr;
    _cv.notify_all();
    
    _thread->join();
    delete this;
}

void QiniuUploader::threadFunc() {
    while(!_done) {
        if (_files.empty()) {
            std::unique_lock<std::mutex> lock(_mutex);
            _cv.wait(lock);
        } else {
            _mutex.lock();
            FileInfo fi = _files.front();
            _files.pop_front();
            _mutex.unlock();
            
            Qiniu_Error err = Qiniu_Io_PutFile(qiniuGetClient(), nullptr, fi.uptoken.c_str(), fi.key.c_str(), fi.localFilePath.c_str(), NULL);
            
            _mutex.lock();
            if (_listener) {
                if (err.code == 200) {
                    _listener->onQiniuUploadSuccess();
                } else {
                    _listener->onQiniuUploadError();
                }
            }
            _mutex.unlock();
        }
    }
}

void QiniuUploader::addFile(const char* uptoken, const char* key, const char* localFile) {
    std::lock_guard<std::mutex> lock(_mutex);
    FileInfo info = {uptoken, key, localFile};
    _files.push_back(info);
    _cv.notify_one();
}










