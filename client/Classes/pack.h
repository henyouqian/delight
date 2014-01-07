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
    int id;
    std::string date;
    std::string title;
    std::string icon;
    std::string cover;
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
    
public:
    static Pack* create(int id);
    void init(const char *date, const char *title, const char *icon,
              const char *cover, const char *text, const char *images,
              PackListener *listerner);
    ~Pack();
    void startDownload();
    
private:
    bool parsePack(std::istream &is);
    void onGetContent(HttpClient* client, HttpResponse* response, unsigned int packId);
    void onImageDownload(HttpClient* client, HttpResponse* response, unsigned int imgIdx);
    
    unsigned int _localNum;
};

struct PackManager {
    static PackManager* getInstance();
    static void destroyInstance();
    std::map<int, Pack*> packs;
};

#endif // __PACK_DOWNLOADER_H__
