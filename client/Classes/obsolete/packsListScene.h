#ifndef __PACKS_LIST_SCENE_H__
#define __PACKS_LIST_SCENE_H__

#include "pack.h"
#include "spriteLoader.h"
#include "cocos2d.h"
#include "cocos-ext.h"
#include <chrono>

USING_NS_CC;
USING_NS_CC_EXT;

class GifTexture;
class SptLoader;

class PacksListScene : public LayerColor, public PackListener, public SptLoaderListener {
public:
    static cocos2d::Scene* createScene();
    CREATE_FUNC(PacksListScene);
    virtual bool init();
    virtual ~PacksListScene();
    
    virtual void update(float delta);
    
    void onPackListDownloaded(HttpClient* client, HttpResponse* response, int fromId);
    void loadPackListLocal();
    
    //PackListener
    virtual void onPackError();
    virtual void onPackImageDownload();
    virtual void onPackDownloadComplete();
    
    //SptLoaderListener
    virtual void onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData);
    virtual void onSptLoaderError(const char *localPath, void *userData);
    
    //touch
    virtual void onTouchesBegan(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesMoved(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesEnded(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesCancelled(const std::vector<Touch*>&touches, Event *event);
    
    //
    void back(Object *sender, Control::EventType controlEvent);
    
public:
    SptLoader *sptLoader;
    
    Pack *selPack;
    
private:
    HttpRequest *_packListRequest;
    
    GifTexture *_loadingTexture;
    
    std::multimap<std::string, Sprite*> _loadingSpts;

    float _thumbWidth;
    
    //
    bool _dragging;
    float _touchBeginY;
    Node *_sptParent;
    float _parentY;
    float _parentTouchY;
    struct DragPointInfo {
        float y;
        std::chrono::steady_clock::time_point t;
    };
    std::list<DragPointInfo> _dragPointInfos;
    float _rollSpeed;
    void updateRoll();
    
    long long _ll;
};

#endif // __PACKS_LIST_SCENE_H__
