#ifndef __PACK_LOADER_H__
#define __PACK_LOADER_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

struct PackLoader;

class PackLoaderListener {
public:
    virtual ~PackLoaderListener() {};
    virtual void onError(const char* error) {};
    virtual void onPackDownload() {};
    virtual void onImageReady(const char* path) {};
};

struct PackLoader {
public:
    static PackLoader* getInstance();
    
    PackLoader();
    void load(unsigned int packId);
    void onPackLoad(HttpClient* client, HttpResponse* response, unsigned int packId);
    void onImageLoad(HttpClient* client, HttpResponse* response);
    
    struct ImageInfo {
        std::string url;
        std::string title;
        std::string text;
    };
    
    std::vector<ImageInfo> imageInfos;
    std::vector<std::string> localImgPaths;
    std::string errorStr;
    std::string imageDir;
    PackLoaderListener *listener;
    
    
private:
    void error(const char *err);
    void makeLocalPackPath(std::string &outPath, int packIdx);
    void makeLocalImagePath(std::string &outPath, const char *url);
    void downloadImage(const char* url);
    void parsePack(std::istream &is);
    
    int _currImgIdx;
};


#endif // __PACK_LOADER_H__
