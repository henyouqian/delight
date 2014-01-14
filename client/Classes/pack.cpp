#include "pack.h"
#include "http.h"
#include "util.h"
#include "jsonxx/jsonxx.h"
#include "crypto/sha.h"
#include "lw/lwLog.h"
#include <fstream>

USING_NS_CC;
USING_NS_CC_EXT;

Pack* Pack::create(int id) {
    auto &packs = PackManager::getInstance()->packs;
    auto it = packs.find(id);
    if (it == packs.end()) {
        auto pack = new Pack;
        packs[id] = pack;
        return pack;
    } else {
        return it->second;
    }
}

void Pack::init(const char *date, const char *title, const char *icon,
                const char *cover, const char *text, const char *images,
                PackListener *listerner) {
    CCASSERT(title && text && images && listerner, "null check");
    this->listener = listerner;
    this->progress = 0.f;
    this->title = title;
    this->text = text;
    
    std::istringstream is(images);
    bool ok = parsePack(is);
    if (!ok) {
        listener->onPackError();
    }
}

void Pack::init(PackInfo *packInfo, PackListener *listerner) {
    this->listener = listerner;
    this->progress = 0.f;
    this->title = packInfo->title;
    this->text = packInfo->text;
    
    _localNum = 0;
    unsigned int imgIdx = 0;
    for (auto i = 0; i < packInfo->images.size(); ++i) {
        auto &image = packInfo->images[i];
        Img img;
        img.url = image.url;
        img.title = image.title;
        img.text = image.text;
        std::string local;
        makeLocalImagePath(local, img.url.c_str());
        img.local = local;
        
        //check file exist and download image
        if (FileUtils::getInstance()->isFileExist(local)) {
            _localNum++;
            img.isLocal = true;
            img._request = nullptr;
        } else {
            img.isLocal = false;
            auto request = new HttpRequest();
            request->setUrl(img.url.c_str());
            request->setRequestType(HttpRequest::Type::GET);
            request->setCallback(std::bind(&Pack::onImageDownload, this, std::placeholders::_1, std::placeholders::_2, imgIdx));
            img._request = request;
        }
        
        //
        imgs.push_back(img);
        imgIdx++;
    }
    
    progress = (float)_localNum / imgs.size();
    if (progress == 1.f && listener) {
        listener->onPackDownloadComplete();
    }
}

Pack::~Pack() {
    for (auto it = imgs.begin(); it != imgs.end(); ++it) {
        if (it->_request) {
            it->_request->release();
        }
    }
}

void Pack::startDownload() {
    for (auto it = imgs.begin(); it != imgs.end(); ++it) {
        if (it->_request) {
            HttpClient::getInstance()->send(it->_request);
        }
    }
}

bool Pack::parsePack(std::istream &is) {
    jsonxx::Array images;
    bool ok = images.parse(is);
    if (!ok) {
        lwerror("json parse error");
        return false;
    }
    _localNum = 0;
    unsigned int imgIdx = 0;
    for (auto i = 0; i < images.size(); ++i) {
        auto image = images.get<jsonxx::Object>(i);
        Img img;
        if (!image.has<jsonxx::String>("Url")) {
            lwerror("json parse error: no string: Url");
            return false;
        }
        if (!image.has<jsonxx::String>("Title")) {
            lwerror("json parse error: no string: Title");
            return false;
        }
        if (!image.has<jsonxx::String>("Text")) {
            lwerror("json parse error: no string: Text");
            return false;
        }
        img.url = image.get<jsonxx::String>("Url");
        img.title = image.get<jsonxx::String>("Title");
        img.text = image.get<jsonxx::String>("Text");
        std::string local;
        makeLocalImagePath(local, img.url.c_str());
        img.local = local;
        
        //check file exist and download image
        if (FileUtils::getInstance()->isFileExist(local)) {
            _localNum++;
            img.isLocal = true;
            img._request = nullptr;
        } else {
            img.isLocal = false;
            auto request = new HttpRequest();
            request->setUrl(img.url.c_str());
            request->setRequestType(HttpRequest::Type::GET);
            request->setCallback(std::bind(&Pack::onImageDownload, this, std::placeholders::_1, std::placeholders::_2, imgIdx));
            img._request = request;
        }
        
        //
        imgs.push_back(img);
        imgIdx++;
    }
    
    progress = (float)_localNum / imgs.size();
    if (progress == 1.f && listener) {
        listener->onPackDownloadComplete();
    }
    
    return true;
}

void Pack::onImageDownload(HttpClient* client, HttpResponse* response, unsigned int imgIdx) {
    CCASSERT(imgIdx < imgs.size(), "imgIdx out of range");
    if (!response->isSucceed()) {
        lwerror("image download response failed");
        if (listener) {
            listener->onPackError();
        }
        return;
    }
    
    //save local
    Img &img = imgs[imgIdx];
    auto f = fopen(img.local.c_str(), "wb");
    auto data = response->getResponseData();
    fwrite(data->data(), data->size(), 1, f);
    fclose(f);
    _localNum++;
    
    progress = (float)_localNum / imgs.size();
    
    if (listener) {
        listener->onPackImageDownload();
        if (progress == 1.f) {
            listener->onPackDownloadComplete();
        }
    }
}

static PackManager *g_packManager = nullptr;

PackManager* PackManager::getInstance() {
    if (!g_packManager) {
        g_packManager = new PackManager();
    }
    return g_packManager;
}

void PackManager::destroyInstance() {
    if (g_packManager) {
        delete g_packManager;
        g_packManager = nullptr;
    }
}

PackManager::~PackManager() {
    for (auto it = packs.begin(); it != packs.end(); ++it) {
        delete it->second;
    }
}

namespace {
    class PackManagerDestroyer {
    public:
        ~PackManagerDestroyer() {
            PackManager::destroyInstance();
        }
    };
    PackManagerDestroyer _packManagerDestroyer;
}

