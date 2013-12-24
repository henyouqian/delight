#include "packLoader.h"
#include "http.h"
#include "jsonxx/jsonxx.h"
#include "crypto/sha.h"
#include <sys/stat.h>
#include <fstream>

USING_NS_CC;
USING_NS_CC_EXT;

namespace {
    PackLoader *g_packLoader = nullptr;
}

PackLoader* PackLoader::getInstance() {
    if (g_packLoader) {
        return g_packLoader;
    }
    g_packLoader = new PackLoader;
    return g_packLoader;
}

PackLoader::PackLoader() {
    listener = nullptr;
    imageDir = FileUtils::getInstance()->getWritablePath();
    imageDir += "images/";
    mkdir(imageDir.c_str(), S_IRWXU);
    
    auto packDir = FileUtils::getInstance()->getWritablePath();
    packDir += "packs/";
    mkdir(packDir.c_str(), S_IRWXU);
}

void PackLoader::load(unsigned int packId) {
    //local first
    std::string localPackPath;
    makeLocalPackPath(localPackPath, packId);
    if (FileUtils::getInstance()->isFileExist(localPackPath)) {
        std::ifstream is;
        is.open(localPackPath.c_str());
        parsePack(is);
        is.close();
    } else { //remote
        std::string url;
        char buf[256];
        snprintf(buf, 256, "{\"PackId\": %d}", packId);
        postHttpRequest("pack/getContent", buf, std::bind(&PackLoader::onPackLoad, this, std::placeholders::_1, std::placeholders::_2, packId));
        
        imageInfos.clear();
        localImgPaths.clear();
        errorStr.clear();
    }
    
}

void PackLoader::parsePack(std::istream &is) {
    imageInfos.clear();
    
    jsonxx::Object o;
    bool ok = o.parse(is);
    if (!ok) {
        return error("json parse error");
    }
    
    if (!o.has<jsonxx::Array>("Images")) {
        return error("json parse error: no array: Images");
    }
    auto images = o.get<jsonxx::Array>("Images");
    for (auto i = 0; i < images.size(); ++i) {
        auto image = images.get<jsonxx::Object>(i);
        ImageInfo imageInfo;
        if (!image.has<jsonxx::String>("Url")) {
            return error("json parse error: no string: Url");
        }
        if (!image.has<jsonxx::String>("Title")) {
            return error("json parse error: no string: Title");
        }
        if (!image.has<jsonxx::String>("Text")) {
            return error("json parse error: no string: Text");
        }
        imageInfo.url = image.get<jsonxx::String>("Url");
        imageInfo.title = image.get<jsonxx::String>("Title");
        imageInfo.text = image.get<jsonxx::String>("Text");
        imageInfos.push_back(imageInfo);
    }
    
    if (listener) {
        listener->onPackDownload();
    }
    
    _currImgIdx = 0;
    if (!imageInfos.empty()) {
        downloadImage(imageInfos[0].url.c_str());
    }
}

void PackLoader::onPackLoad(HttpClient* client, HttpResponse* response, unsigned int packId) {
    if (!response->isSucceed()) {
        return error("respons not succeed");
    }
    
    auto v = response->getResponseData();
    std::istringstream is(std::string(v->begin(), v->end()));
    
    parsePack(is);
    
    std::string localPackPath;
    makeLocalPackPath(localPackPath, packId);
    
    auto f = fopen(localPackPath.c_str(), "wb");
    auto data = response->getResponseData();
    fwrite(data->data(), data->size(), 1, f);
    fclose(f);
}

void PackLoader::error(const char *err) {
    errorStr = err;
    if (listener) {
        listener->onError(errorStr.c_str());
    }
}

void PackLoader::makeLocalPackPath(std::string &outPath, int packIdx) {
    outPath = FileUtils::getInstance()->getWritablePath();
    outPath += "packs/";
    char buf[64];
    snprintf(buf, 64, "%d.pack", packIdx);
    outPath += buf;
}

void PackLoader::makeLocalImagePath(std::string &outPath, const char *url) {
    Sha1 sha1;
    sha1.write(url, strlen(url));
    sha1.final();
    
    outPath = imageDir;
    outPath += sha1.getResult();
}

void PackLoader::downloadImage(const char* url) {
    //lookup local first
    std::string localPath;
    makeLocalImagePath(localPath, url);
    
    //local file exist or not
    if (FileUtils::getInstance()->isFileExist(localPath)) {
        if (listener) {
            listener->onImageReady(localPath.c_str());
        }
        localImgPaths.push_back(localPath);
        
        //load next
        if (_currImgIdx < imageInfos.size()-1) {
            ++_currImgIdx;
            downloadImage(imageInfos[_currImgIdx].url.c_str());
        }
    } else {
        getHttpRequest(url, std::bind(&PackLoader::onImageLoad, this, std::placeholders::_1, std::placeholders::_2));
    }
    
}

void PackLoader::onImageLoad(HttpClient* client, HttpResponse* response) {
    if (!response->isSucceed()) {
        error("respons not succeed");
    }
    
    //save file
    std::string path;
    makeLocalImagePath(path, response->getHttpRequest()->getUrl());
    auto f = fopen(path.c_str(), "wb");
    auto data = response->getResponseData();
    fwrite(data->data(), data->size(), 1, f);
    fclose(f);
    
    if (listener) {
        listener->onImageReady(path.c_str());
    }
    localImgPaths.push_back(path);
    
    //load next
    if (_currImgIdx < imageInfos.size()-1) {
        ++_currImgIdx;
        downloadImage(imageInfos[_currImgIdx].url.c_str());
    }
}




