#ifndef __PACK_DOWNLOADER_H__
#define __PACK_DOWNLOADER_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

void makePackDownloadDir();

class PackListener {
public:
    virtual void onPackParseComplete() {};
    virtual void onError() {};
    virtual void onImageDownload() {};
    virtual void onComplete() {};
};

struct Pack {
    PackListener *listener;
    std::string title;
    std::string test;
    float progress;
    std::string errorStr;
    
    struct Img {
        std::string url;
        std::string local;
        std::string title;
        std::string text;
        bool isLocal;
    
        HttpRequest *_request;
    };
    std::vector<Img> imgs;
    
    void init(unsigned int packId, PackListener *listerner);
    ~Pack();
    void download();
    
private:
    void makeLocalPackPath(std::string &outPath, int packIdx);
    void makeLocalImagePath(std::string &outPath, const char *url);
    bool parsePack(std::istream &is);
    void onGetContent(HttpClient* client, HttpResponse* response, unsigned int packId);
    void onImageDownload(HttpClient* client, HttpResponse* response, unsigned int imgIdx);
    
    HttpRequest *_packRequest;
    unsigned int _localNum;
};

#endif // __PACK_DOWNLOADER_H__
