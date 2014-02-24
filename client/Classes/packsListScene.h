#ifndef __PACK_BOOK_SCENE_H__
#define __PACK_BOOK_SCENE_H__

#include "spriteLoader.h"
#include "pack.h"
#include "collectionListScene.h"
#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class GifTexture;
class DragView;
class Collection;

class PacksListScene : public LayerColor, public SptLoaderListener{
public:
    static PacksListScene* createScene();
    CREATE_FUNC(PacksListScene);
    virtual bool init();
    virtual ~PacksListScene();
    
    void loadCollection(Collection *collection);
    void onHttpListPack(HttpClient* client, HttpResponse* response);
    
    void back(Object *sender, Control::EventType controlEvent);
    //void onHttpGetCount(HttpClient* client, HttpResponse* response);
    void onHttpGetPage(HttpClient* client, HttpResponse* response);
    
    //
    virtual void onEnter();
    
    //SptLoaderListener
    virtual void onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData);
    virtual void onSptLoaderError(const char *localPath, void *userData);
    
    //touch
    virtual void onTouchesBegan(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesMoved(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesEnded(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesCancelled(const std::vector<Touch*>&touches, Event *event);
    
private:
    ////page: zero based
    //void loadPage(int page);
    bool isLocked(int idx);
    
    int _packCount;
    int _pageCount;
    int _currPage;
    bool _isOffline;
    
    std::vector<Sprite*> _thumbs;
    float _thumbWidth;
    float _thumbHeight;
    DragView *_dragView;
    
    std::vector<PackInfo> _packs;
    SptLoader *_sptLoader;
    SpriteBatchNode *_starBatch;
    Touch* _touch;
    Collection _collection;
    SpriteBatchNode *_lockBatch;
    
};


#endif // __PACK_BOOK_SCENE_H__
