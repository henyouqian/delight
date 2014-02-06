#ifndef __PACK_H__
#define __PACK_H__

#include "jsonxx/jsonxx.h"
#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

struct PackInfo {
    uint32_t id;
    std::string date;
    std::string title;
    std::string text;
    std::string icon;
    std::string cover;
    uint32_t star;
    uint32_t starTime1;
    uint32_t starTime2;
    uint32_t starTime3;
    
    struct Image {
        std::string url;
        std::string title;
        std::string text;
    };
    std::vector<Image> images;
    std::vector<int> imageIndices;
    
    void init(jsonxx::Object& packJs);
    void shuffleImageIndices();
};

class PackListener {
public:
    virtual void onPackError() {};
    virtual void onPackImageDownload() {};
    virtual void onPackDownloadComplete() {};
};

struct PackDownloader : cocos2d::Object{
    PackInfo *pack;
    float progress;
    PackListener *listener;
    std::map<HttpRequest*, std::string> requestMapLocal;
    int downloadedNum;
    
    void init(PackInfo *pack, PackListener *listener);
    void destroy();
    virtual ~PackDownloader();
    void startDownload();
    void onImageDownload(HttpClient* client, HttpResponse* response);
};

#endif // __PACK_H__
