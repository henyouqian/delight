#ifndef __PACK_BOOK_SCENE_H__
#define __PACK_BOOK_SCENE_H__

#include "spriteLoader.h"
#include "pack.h"
#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class GifTexture;

class PacksBookScene : public LayerColor, public SptLoaderListener{
public:
    static cocos2d::Scene* createScene();
    CREATE_FUNC(PacksBookScene);
    virtual bool init();
    virtual ~PacksBookScene();
    
    void back(Object *sender, Control::EventType controlEvent);
    void onHttpGetCount(HttpClient* client, HttpResponse* response);
    void onHttpGetPage(HttpClient* client, HttpResponse* response);
    
    //SptLoaderListener
    virtual void onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData);
    virtual void onSptLoaderError(const char *localPath, void *userData);
    
    //touch
    virtual void onTouchesBegan(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesMoved(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesEnded(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesCancelled(const std::vector<Touch*>&touches, Event *event);
    
private:
    //page: zero based
    void loadPage(int page);
    
    LabelTTF *_pageLabel;
    int _packCount;
    int _pageCount;
    int _currPage;
    bool _isOffline;
    
    GifTexture *_loadingTexture;
    std::vector<Sprite*> _icons;
    Rect _touchedRect;
    PackInfo *_touchedPack;
    float _iconWidth;
    Node *_iconsParent;
    
    std::vector<PackInfo> _packs;
    
    SptLoader *_sptLoader;
};


#endif // __PACK_BOOK_SCENE_H__
