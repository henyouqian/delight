#include "spriteLoader.h"
#include "util.h"
#include "gifTexture.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

SptLoader* SptLoader::create(SptLoaderListener *listener, Node *gifActionParentNode) {
    auto sptLoader = new SptLoader(listener, gifActionParentNode);
    sptLoader->_thread = new std::thread(&SptLoader::loadingThreadMain, sptLoader);
    return sptLoader;
}

SptLoader::SptLoader(SptLoaderListener *listener, Node *gifActionParentNode) {
    _listener = listener;
    _gifActionParentNode = gifActionParentNode;
}

SptLoader::~SptLoader() {
    if (_thread) {
        delete _thread;
    }
    for (auto it = _requests.begin(); it != _requests.end(); ++it) {
        (*it)->release();
    }
}

struct AsyncLoader : public Object {
    std::string localPath;
    SptLoaderListener *listener;
    void onImageLoad(Object *obj);
};

void AsyncLoader::onImageLoad(Object *obj) {
    this->autorelease();
    auto tex = (Texture2D*)obj;
    auto spt = Sprite::createWithTexture(tex);
    listener->onSptLoaderLoad(localPath.c_str(), spt);
}

void SptLoader::loadingThreadMain() {
    while(1) {
        if (!_localPaths.empty()) {
            _mutex.lock();
            std::string localPath = _localPaths.front();
            _localPaths.pop_front();
            _mutex.unlock();
            
            //try gif first
            bool isGif = GifTexture::isGif(localPath.c_str());
            if (isGif) {
                int err = GIF_OK;
                LoadedGif loadedGif;
                loadedGif.gifFile = DGifOpenFileName(localPath.c_str(), &err);
                err = DGifSlurp(loadedGif.gifFile);
                if (err != GIF_OK) {
                    std::lock_guard<std::mutex> lock(_mutex);
                    _errorLocalPaths.push_back(localPath);
                    continue;
                }
                loadedGif.localPath = localPath;
                _loadedGifs.push_back(loadedGif);
            } else {
                auto al = new AsyncLoader();
                al->localPath = localPath;
                al->listener = _listener;
                TextureCache::getInstance()->addImageAsync(localPath, al, (SEL_CallFuncO)&AsyncLoader::onImageLoad);
            }
        } else {
            std::unique_lock<std::mutex> lock(_mutex);
            _cv.wait(lock);
        }
    }
}

void SptLoader::mainThreadUpdate() {
    std::lock_guard<std::mutex> lock(_mutex);
    if (!_loadedGifs.empty()) {
        for (auto it = _loadedGifs.begin(); it != _loadedGifs.end(); ++it) {
            auto texture = GifTexture::create(it->gifFile, _gifActionParentNode, false);
            auto sprite = Sprite::createWithTexture(texture);
            if (!sprite) {
                _errorLocalPaths.push_back(it->localPath);
            } else {
                _listener->onSptLoaderLoad(it->localPath.c_str(), sprite);
            }
        }
        _loadedGifs.clear();
    }
    if (!_errorLocalPaths.empty()) {
        for (auto it = _errorLocalPaths.begin(); it != _errorLocalPaths.end(); ++it) {
            _listener->onSptLoaderError(it->c_str());
        }
        _errorLocalPaths.clear();
    }
}

void SptLoader::load(const char* localPath) {
    std::lock_guard<std::mutex> lock(_mutex);
    _localPaths.push_back(localPath);
    _cv.notify_all();
}

//void SptLoader::load(const char* filename) {
//    auto al = new AsyncLoader();
//    al->filename = filename;
//    TextureCache::getInstance()->addImageAsync(filename, al, (SEL_CallFuncO)&AsyncLoader::onImageLoad);
//}

void SptLoader::download(const char *url) {
    std::string localPath;
    makeLocalImagePath(localPath, url);
    
    //check and download image
    if (FileUtils::getInstance()->isFileExist(localPath)) {
        load(localPath.c_str());
    } else {
        auto request = new HttpRequest();
        request->setUrl(url);
        request->setRequestType(HttpRequest::Type::GET);
        request->setCallback(std::bind(&SptLoader::onImageDownload, this, std::placeholders::_1, std::placeholders::_2, localPath));
        HttpClient::getInstance()->send(request);
        
        _requests.insert(request);
        request->retain();
    }
}

void SptLoader::onImageDownload(HttpClient* client, HttpResponse* response, std::string localPath) {
    auto request = response->getHttpRequest();
    request->release();
    _requests.erase(request);
    
    if (!response->isSucceed()) {
        if (_listener) {
            _listener->onSptLoaderError(localPath.c_str());
        }
        return;
    } else {
        //save to local
        auto f = fopen(localPath.c_str(), "wb");
        auto data = response->getResponseData();
        fwrite(data->data(), data->size(), 1, f);
        fclose(f);
        
        load(localPath.c_str());
    }
}



