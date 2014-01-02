#include "spriteLoader.h"
#include "util.h"
#include "gifTexture.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

static SptLoader *g_currSptLoader = nullptr;

SptLoader* SptLoader::create(SptLoaderListener *listener, Node *gifActionParentNode) {
    auto sptLoader = new SptLoader(listener, gifActionParentNode);
    sptLoader->_thread = new std::thread(&SptLoader::loadingThread, sptLoader);
    g_currSptLoader = sptLoader;
    return sptLoader;
}

SptLoader::SptLoader(SptLoaderListener *listener, Node *gifActionParentNode) {
    _listener = listener;
    _gifActionParentNode = gifActionParentNode;
}

void SptLoader::destroy() {
    std::lock_guard<std::mutex> lock(_mutex);
    _done = true;
    _cv.notify_all();
    g_currSptLoader = nullptr;
}

SptLoader::~SptLoader() {
    std::lock_guard<std::mutex> lock(_mutex);
    
    if (_thread) {
        _thread->detach();
        delete _thread;
    }
    for (auto it = _requests.begin(); it != _requests.end(); ++it) {
        (*it)->release();
    }
    
    for (auto it = _loadedGifs.begin(); it != _loadedGifs.end(); ++it) {
        DGifCloseFile(it->gifFile);
    }
}

struct AsyncLoader : public Object {
    std::string localPath;
    SptLoader *loader;
    void onImageLoad(Object *obj);
};

void AsyncLoader::onImageLoad(Object *obj) {
    this->autorelease();
    auto tex = (Texture2D*)obj;
    if (loader == g_currSptLoader) {
        loader->onTextureCreated(localPath.c_str(), tex);
    }
}

void SptLoader::onTextureCreated(const char *localPath, Texture2D *texture) {
    LoadedTexture lt;
    lt.localPath = localPath;
    lt.texture = texture;
    texture->retain();
    std::lock_guard<std::mutex> lock(_mutex);
    _loadedTextures.push_back(lt);
}

void SptLoader::loadingThread() {
    _done = false;
    while(!_done) {
        if (!_localPaths.empty()) {
            _mutex.lock();
            std::string localPath = _localPaths.front();
            _localPaths.pop_front();
            _mutex.unlock();
            
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
            std::lock_guard<std::mutex> lock(_mutex);
            _loadedGifs.push_back(loadedGif);
        } else {
            std::unique_lock<std::mutex> lock(_mutex);
            _cv.wait(lock);
        }
    }
    delete this;
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
    if (!_loadedTextures.empty()) {
        for (auto it = _loadedTextures.begin(); it != _loadedTextures.end(); ++it) {
            auto sprite = Sprite::createWithTexture(it->texture);
            if (!sprite) {
                _errorLocalPaths.push_back(it->localPath);
            } else {
                _listener->onSptLoaderLoad(it->localPath.c_str(), sprite);
            }
            it->texture->release();
        }
        _loadedTextures.clear();
    }
    if (!_errorLocalPaths.empty()) {
        for (auto it = _errorLocalPaths.begin(); it != _errorLocalPaths.end(); ++it) {
            _listener->onSptLoaderError(it->c_str());
        }
        _errorLocalPaths.clear();
    }
}

void SptLoader::load(const char* localPath) {
    bool isGif = GifTexture::isGif(localPath);
    if (isGif) {
        std::lock_guard<std::mutex> lock(_mutex);
        _localPaths.push_back(localPath);
        _cv.notify_all();
    } else {
        auto al = new AsyncLoader();
        al->localPath = localPath;
        al->loader = this;
        TextureCache::getInstance()->addImageAsync(localPath, al, (SEL_CallFuncO)&AsyncLoader::onImageLoad);
    }
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



