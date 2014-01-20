#include "pack.h"
#include "http.h"
#include "util.h"
#include "crypto/sha.h"
#include "lw/lwLog.h"
#include <fstream>

USING_NS_CC;
USING_NS_CC_EXT;

void PackInfo::init(jsonxx::Object& packJs) {
    if (!packJs.has<jsonxx::Number>("Id")) {
        lwerror("json parse error: no Id");
        return;
    }
    if (!packJs.has<jsonxx::String>("Date")) {
        lwerror("json parse error: no Date");
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
    if (!packJs.has<jsonxx::String>("Icon")) {
        lwerror("json parse error: no Icon");
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
    this->date = packJs.get<jsonxx::String>("Date");
    this->icon = packJs.get<jsonxx::String>("Icon");
    this->cover = packJs.get<jsonxx::String>("Cover");
    this->title = packJs.get<jsonxx::String>("Title");
    this->text = packJs.get<jsonxx::String>("Text");
    
    auto imagesJs = packJs.get<jsonxx::Array>("Images");
    for (auto j = 0; j < imagesJs.size(); ++j) {
        auto imageJs = imagesJs.get<jsonxx::Object>(j);
        if (!imageJs.has<jsonxx::String>("Url")) {
            lwerror("json parse error: no Url");
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
        image.url = imageJs.get<jsonxx::String>("Url");
        image.title = imageJs.get<jsonxx::String>("Title");
        image.text = imageJs.get<jsonxx::String>("Text");
        this->images.push_back(image);
    }
}

void PackInfo::shuffleImageIndices() {
    imageIndices.clear();
    for (auto i = 0; i < images.size(); ++i) {
        imageIndices.push_back(i);
    }
    std::random_shuffle(imageIndices.begin(), imageIndices.end());
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
        makeLocalImagePath(local, image.url.c_str());
        
        //check file exist and download image
        if (FileUtils::getInstance()->isFileExist(local)) {
            downloadedNum++;
        } else {
            auto request = new HttpRequest();
            request->setUrl(image.url.c_str());
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
    HttpClient::getInstance()->cancelAllRequest();
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


