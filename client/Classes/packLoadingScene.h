#ifndef __PACK_LOADING_SCENE_H__
#define __PACK_LOADING_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"
#include "pack.h"

USING_NS_CC;
USING_NS_CC_EXT;

class PackLoadingLayer : public LayerColor, public PackDownloadListener {
public:
    static PackLoadingLayer* create(PackInfo &packInfo, Scene *enterScene);
    bool init(PackInfo &packInfo, Scene *enterScene);
    ~PackLoadingLayer();
    PackInfo& getPackInfo();
    
    virtual void onPackImageDownload();
    virtual void onPackDownloadComplete();

private:
    static PackInfo _packInfo;
    Scene *_enterScene;
    PackDownloader *_packDownloader;
    LabelTTF *_progressLabel;
};

#endif // __PACK_LOADING_SCENE_H__
