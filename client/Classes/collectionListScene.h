#ifndef __COLLECTION_LIST_SCENE_H__
#define __COLLECTION_LIST_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"
#include "spriteLoader.h"

USING_NS_CC;
USING_NS_CC_EXT;

class DragView;

struct Collection {
    uint64_t id;
    std::string title;
    std::string text;
    std::string thumb;
    std::vector<uint64_t> packs;
};

class CollectionListScene : public cocos2d::Layer, public SptLoaderListener{
public:
    static CollectionListScene* createScene();
    virtual bool init();
    CREATE_FUNC(CollectionListScene);
    ~CollectionListScene();
    
    Scene *scene;
    
    void onHttpListCollection(HttpClient* client, HttpResponse* response);
    void back(Object *sender, Control::EventType controlEvent);
    
    //SptLoaderListener
    virtual void onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData);
    virtual void onSptLoaderError(const char *localPath, void *userData);
    
    //touch
    virtual void onTouchesBegan(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesMoved(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesEnded(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesCancelled(const std::vector<Touch*>&touches, Event *event);
    
private:
    DragView *_dragView;
    std::vector<Collection> _collections;
    SptLoader *_sptLoader;
    Touch* _touch;
    float _thumbWidth;
    float _thumbHeight;
    std::vector<Sprite*> _thumbs;
};

#endif // __COLLECTION_LIST_SCENE_H__
