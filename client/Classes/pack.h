#ifndef __PACK_DOWNLOADER_H__
#define __PACK_DOWNLOADER_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class PackListener {
public:
    virtual void onPackError() {};
    virtual void onPackImageDownload() {};
    virtual void onPackDownloadComplete() {};
};

struct Pack {
    PackListener *listener;
    std::string title;
    std::string text;
    float progress;
    
    struct Img {
        std::string url;
        std::string local;
        std::string title;
        std::string text;
        bool isLocal;
    
        HttpRequest *_request;
    };
    std::vector<Img> imgs;
    
    void init(const char *title, const char *text, const char *images, PackListener *listerner);
    ~Pack();
    void startDownload();
    
private:
    bool parsePack(std::istream &is);
    void onGetContent(HttpClient* client, HttpResponse* response, unsigned int packId);
    void onImageDownload(HttpClient* client, HttpResponse* response, unsigned int imgIdx);
    
    HttpRequest *_packRequest;
    unsigned int _localNum;
};

#endif // __PACK_DOWNLOADER_H__
