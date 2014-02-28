#include "pack.h"
#include "http.h"
#include "util.h"
#include "crypto/sha.h"
#include "lw/lwLog.h"
#include <fstream>
#include <random>
#include <chrono>
#include <algorithm>

USING_NS_CC;
USING_NS_CC_EXT;

void PackInfo::init(jsonxx::Object& packJs) {
    if (!packJs.has<jsonxx::Number>("Id")) {
        lwerror("json parse error: no Id");
        return;
    }
    if (!packJs.has<jsonxx::String>("Time")) {
        lwerror("json parse error: no Time");
        return;
    }
    if (!packJs.has<jsonxx::String>("Title")) {
        lwerror("json parse error: no Title");
        return;
    }
    if (!packJs.has<jsonxx::String>("Text")) {
        lwerror("json parse error: no string: Text");
        return;
    }
    if (!packJs.has<jsonxx::String>("Thumb")) {
        lwerror("json parse error: no Thumb");
        return;
    }
    if (!packJs.has<jsonxx::String>("Cover")) {
        lwerror("json parse error: no Cover");
        return;
    }
    if (!packJs.has<jsonxx::Array>("Images")) {
        lwerror("json parse error: no Images");
        return;
    }
    
    this->id = (int)(packJs.get<jsonxx::Number>("Id"));
    this->time = packJs.get<jsonxx::String>("Time");
    this->thumb = packJs.get<jsonxx::String>("Thumb");
    this->cover = packJs.get<jsonxx::String>("Cover");
    this->title = packJs.get<jsonxx::String>("Title");
    this->text = packJs.get<jsonxx::String>("Text");
    
    if (!packJs.has<jsonxx::Array>("SliderNum")) {
        this->sliderNum = 6;
    } else {
        this->sliderNum = MIN(12, (int)(packJs.get<jsonxx::Number>("Id")));
    }
    
    auto imagesJs = packJs.get<jsonxx::Array>("Images");
    for (auto j = 0; j < imagesJs.size(); ++j) {
        auto imageJs = imagesJs.get<jsonxx::Object>(j);
        if (!imageJs.has<jsonxx::String>("Key")) {
            lwerror("json parse error: no Key");
            return;
        }
        if (!imageJs.has<jsonxx::String>("Title")) {
            lwerror("json parse error: no Title");
            return;
        }
        if (!imageJs.has<jsonxx::String>("Text")) {
            lwerror("json parse error: no Text");
            return;
        }
        PackInfo::Image image;
        image.key = imageJs.get<jsonxx::String>("Key");
        image.title = imageJs.get<jsonxx::String>("Title");
        image.text = imageJs.get<jsonxx::String>("Text");
        this->images.push_back(image);
    }
}

int myrandom (int i) {
    return std::rand()%i;
}

void PackInfo::shuffleImageIndices() {
    imageIndices.clear();
    for (auto i = 0; i < images.size(); ++i) {
        imageIndices.push_back(i);
    }

    unsigned seed = std::chrono::system_clock::now().time_since_epoch().count();
    std::shuffle(imageIndices.begin(), imageIndices.end(), std::default_random_engine(seed));
}

void PackDownloader::init(PackInfo *pack, PackListener *listener) {
    this->pack = pack;
    progress = 0.f;
    this->listener = listener;
    
    //local count
    downloadedNum = 0;
    for (auto i = 0; i < pack->images.size(); ++i) {
        auto &image = pack->images[i];
        std::string local;
        makeLocalImagePath(local, image.key.c_str());
        
        //check file exist and download image
        if (FileUtils::getInstance()->isFileExist(local)) {
            downloadedNum++;
        } else {
            auto request = new HttpRequest();
            std::string url;
            makeUrl(url, image.key.c_str());
            request->setUrl(url.c_str());
            request->setRequestType(HttpRequest::Type::GET);
            request->setResponseCallback(this, (SEL_HttpResponse)(&PackDownloader::onImageDownload));
            requestMapLocal[request] = local;
        }
    }
    
    progress = (float)downloadedNum / pack->images.size();
}

void PackDownloader::destroy() {
    listener = nullptr;
    for (auto it = requestMapLocal.begin(); it != requestMapLocal.end(); ++it) {
        it->first->release();
    }
    this->release();
    //HttpClient::getInstance()->cancelAllRequest();
}

PackDownloader::~PackDownloader() {

}

void PackDownloader::startDownload() {
    for (auto it = requestMapLocal.begin(); it != requestMapLocal.end(); ++it) {
        HttpClient::getInstance()->send(it->first);
    }
}

void PackDownloader::onImageDownload(HttpClient* client, HttpResponse* response) {
    if (!response->isSucceed()) {
        lwerror("image download failed");
        if (listener)
            listener->onPackError();
    } else {
        auto it = requestMapLocal.find(response->getHttpRequest());
        if (it == requestMapLocal.end()) {
            lwerror("request not found");
        } else {
            //save local
            auto f = fopen(it->second.c_str(), "wb");
            auto data = response->getResponseData();
            fwrite(data->data(), data->size(), 1, f);
            fclose(f);
            downloadedNum++;
            
            progress = (float)downloadedNum / pack->images.size();
            
            if (listener) {
                listener->onPackImageDownload();
                if (progress == 1.f) {
                    listener->onPackDownloadComplete();
                }
            }
        }
    }
}

std::vector<PackInfo> _packs;

std::vector<PackInfo>& getPacks() {
    return _packs;
}

