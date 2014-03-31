#ifndef __PACK_LOADING_SCENE_H__
#define __PACK_LOADING_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"
#include "pack.h"

USING_NS_CC;
USING_NS_CC_EXT;

class PackLoadingLayer : public LayerColor, public PackDownloadListener {
public:
    static PackLoadingLayer* createWithScene(PackInfo &packInfo, Scene *enterScene);
    static PackLoadingLayer* createWithScene(uint64_t packId, Scene *enterScene);
    bool init(PackInfo &packInfo, Scene *enterScene);
    bool init(uint64_t packId, Scene *enterScene);
    ~PackLoadingLayer();
    PackInfo& getPackInfo();
    
    //PackDownloadListener delegate
    virtual void onPackImageDownload();
    virtual void onPackDownloadComplete();
    
    //http callback
    void onHttpGetPack(HttpClient* cli, HttpResponse* resp);
    
    //
//    virtual void onEnterTransitionDidFinish();

private:
    static PackInfo _packInfo;
    Scene *_enterScene;
    PackDownloader *_packDownloader;
    LabelTTF *_progressLabel;
};

#endif // __PACK_LOADING_SCENE_H__
