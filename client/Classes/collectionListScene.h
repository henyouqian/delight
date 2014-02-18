#ifndef __COLLECTION_LIST_SCENE_H__
#define __COLLECTION_LIST_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class DragView;

class CollectionListScene : public cocos2d::Layer {
public:
    static cocos2d::Scene* createScene();
    virtual bool init();
    CREATE_FUNC(CollectionListScene);
    
    void onHttpListCollection(HttpClient* client, HttpResponse* response);
    
private:
    DragView *_dragView;
};

#endif // __COLLECTION_LIST_SCENE_H__
