#ifndef __PACKS_LIST_SCENE_H__
#define __PACKS_LIST_SCENE_H__

#include "pack.h"
#include "cocos2d.h"
#include "cocos-ext.h"
#include <future>

USING_NS_CC;
USING_NS_CC_EXT;

class GifTexture;

class PacksListScene : public LayerColor, public PackListener {
public:
    static cocos2d::Scene* createScene();
    CREATE_FUNC(PacksListScene);
    virtual bool init();
    virtual ~PacksListScene();
    
    void onPackList(HttpClient* client, HttpResponse* response);
    
    //PackListener
    virtual void onPackParseComplete();
    virtual void onError();
    virtual void onImageDownload();
    virtual void onComplete();
    
    virtual void onTouchesBegan(const std::vector<Touch*>& touches, Event *event);
    
private:
    struct PackInfo {
        int id;
        std::string date;
        std::string title;
        std::string cover;
        std::string text;
        Sprite *sprite;
    };
    std::vector<PackInfo> _packInfos;
    HttpRequest *_packListRequest;
    
    GifTexture *_loadingTexture;
    Pack *_pack;
    
    struct SptPair {
        Sprite *loadingSpt;
        Sprite *spt;
    };
    std::vector<std::future<SptPair>> _coverLoaders;
};

#endif // __PACKS_LIST_SCENE_H__
