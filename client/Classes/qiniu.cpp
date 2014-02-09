#include "qiniu.h"

USING_NS_CC;
USING_NS_CC_EXT;

static Qiniu_Client _qiniuClient;

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
                    _listener->onQiniuUploadSuccess(fi.key.c_str());
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










