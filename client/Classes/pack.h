#ifndef __PACK_H__
#define __PACK_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

struct PackInfo {
    int id;
    std::string date;
    std::string title;
    std::string text;
    std::string icon;
    std::string cover;
    
    struct Image {
        std::string url;
        std::string title;
        std::string text;
    };
    std::vector<Image> images;
};

class PackListener {
public:
    virtual void onPackError() {};
    virtual void onPackImageDownload() {};
    virtual void onPackDownloadComplete() {};
};

struct Pack {
    int id;
    std::string date;
    std::string title;
    std::string icon;
    std::string cover;
    std::string text;
    std::string images;
    float progress;
    PackListener *listener;
    
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
    void init(PackInfo *packInfo, PackListener *listerner);
    ~Pack();
    void startDownload();
    
private:
    bool parsePack(std::istream &is);
    void onImageDownload(HttpClient* client, HttpResponse* response, unsigned int imgIdx);
    
    unsigned int _localNum;
};

struct PackManager {
    static PackManager* getInstance();
    static void destroyInstance();
    ~PackManager();
    
    std::map<int, Pack*> packs;
};

#endif // __PACK_H__
