#include "pack.h"
#include "http.h"
#include "jsonxx/jsonxx.h"
#include "crypto/sha.h"
#include "lw/lwLog.h"
#include <sys/stat.h>
#include <fstream>

USING_NS_CC;
USING_NS_CC_EXT;

namespace {
    std::string _imageDir;
    std::string _packDir;
}

void makePackDownloadDir() {
    _imageDir = FileUtils::getInstance()->getWritablePath();
    _imageDir += "images/";
    mkdir(_imageDir.c_str(), S_IRWXU);
    
    _packDir = FileUtils::getInstance()->getWritablePath();
    _packDir += "packs/";
    mkdir(_packDir.c_str(), S_IRWXU);
}


void Pack::init(unsigned int packId, PackListener *listerner) {
    this->listener = listerner;
    progress = 0.f;
    
    std::string localPackFile;
    makeLocalPackPath(localPackFile, packId);
    
    //local
    if (FileUtils::getInstance()->isFileExist(localPackFile)) {
        std::ifstream is;
        is.open(localPackFile.c_str());
        parsePack(is);
        is.close();
    }
    //remote
    else {
        std::string url;
        char buf[256];
        snprintf(buf, 256, "{\"PackId\": %d}", packId);
        _packRequest = postHttpRequest("pack/getContent", buf, std::bind(&Pack::onGetContent, this, std::placeholders::_1, std::placeholders::_2, packId));
        _packRequest->retain();
    }
}

Pack::~Pack() {
    if (_packRequest) {
        _packRequest->release();
    }
    for (auto it = imgs.begin(); it != imgs.end(); ++it) {
        if (it->_request) {
            it->_request->release();
        }
    }
}

void Pack::download() {
    for (auto it = imgs.begin(); it != imgs.end(); ++it) {
        if (it->_request) {
            HttpClient::getInstance()->send(it->_request);
        }
    }
}

void Pack::makeLocalPackPath(std::string &outPath, int packIdx) {
    outPath = _packDir;
    char buf[64];
    snprintf(buf, 64, "%d.pack", packIdx);
    outPath += buf;
}

void Pack::makeLocalImagePath(std::string &outPath, const char *url) {
    Sha1 sha1;
    sha1.write(url, strlen(url));
    sha1.final();
    
    outPath = _imageDir;
    outPath += sha1.getResult();
}

bool Pack::parsePack(std::istream &is) {
    jsonxx::Object o;
    bool ok = o.parse(is);
    if (!ok) {
        lwerror("json parse error");
        return false;
    }
    
    if (!o.has<jsonxx::Array>("Images")) {
        lwerror("json parse error: no array: Images");
        return false;
    }
    auto images = o.get<jsonxx::Array>("Images");
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
        
        //check and download image
        if (FileUtils::getInstance()->isFileExist(local)) {
            _localNum++;
            img.isLocal = true;
            img._request = false;
        } else {
            img.isLocal = false;
            auto request = new HttpRequest();
            request->setUrl(img.url.c_str());
            request->setRequestType(HttpRequest::Type::GET);
            request->setCallback(std::bind(&Pack::onImageDownload, this, std::placeholders::_1, std::placeholders::_2, imgIdx));
            imgIdx++;
            img._request = request;
        }
        
        //
        imgs.push_back(img);
    }
    
    if (listener) {
        listener->onPackParseComplete();
    }
    
    progress = (float)_localNum / imgs.size();
    if (progress == 1.f && listener) {
        listener->onComplete();
    }
    
    return true;
}

void Pack::onGetContent(HttpClient* client, HttpResponse* response, unsigned int packId) {
    if (!response->isSucceed()) {
        if (listener) {
            listener->onError();
        }
        return;
    }
    
    //parse
    auto v = response->getResponseData();
    std::istringstream is(std::string(v->begin(), v->end()));
    bool ok = parsePack(is);
    
    if (ok) {
        //save local
        std::string localPackPath;
        makeLocalPackPath(localPackPath, packId);
        
        auto f = fopen(localPackPath.c_str(), "wb");
        auto data = response->getResponseData();
        fwrite(data->data(), data->size(), 1, f);
        fclose(f);
    } else {
        if (listener) {
            listener->onError();
        }
    }
}

void Pack::onImageDownload(HttpClient* client, HttpResponse* response, unsigned int imgIdx) {
    CCASSERT(imgIdx < imgs.size(), "imgIdx out of range");
    if (!response->isSucceed()) {
        lwerror("image download response failed");
        if (listener) {
            listener->onError();
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
        listener->onImageDownload();
        if (progress == 1.f) {
            listener->onComplete();
        }
    }
}

