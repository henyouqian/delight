#ifndef __PACK_H__
#define __PACK_H__

#include "jsonxx/jsonxx.h"
#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

struct PackInfo {
    uint64_t id;
    std::string time;
    std::string title;
    std::string text;
    std::string thumb;
    std::string cover;
    int sliderNum;
    
    struct Image {
        std::string key;
        std::string title;
        std::string text;
    };
    std::vector<Image> images;
    std::vector<int> imageIndices;
    
    void init(jsonxx::Object& packJs);
    void shuffleImageIndices();
};

class PackDownloadListener {
public:
    virtual void onPackError() {};
    virtual void onPackImageDownload() {};
    virtual void onPackDownloadComplete() {};
};

struct PackDownloader : cocos2d::Object{
    PackInfo *pack;
    float progress;
    PackDownloadListener *listener;
    std::map<HttpRequest*, std::string> requestMapLocal;
    int downloadedNum;
    
    void init(PackInfo *pack, PackDownloadListener *listener);
    void destroy();
    virtual ~PackDownloader();
    void startDownload();
    void onImageDownload(HttpClient* client, HttpResponse* response);
};

bool isPackDownloaded(PackInfo &pack);


std::vector<PackInfo>& getPacks();


#endif // __PACK_H__
