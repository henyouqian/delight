#ifndef __MATCH_LIST_SCENE_H__
#define __MATCH_LIST_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"

#include "spriteLoader.h"

USING_NS_CC;
USING_NS_CC_EXT;

class DragView;

class MatchListLayer : public Layer, public SptLoaderListener{
public:
    CREATE_FUNC(MatchListLayer);
    bool init();
    
    //touch
    virtual bool onTouchBegan(Touch* touch, Event  *event);
    virtual void onTouchMoved(Touch* touch, Event  *event);
    virtual void onTouchEnded(Touch* touch, Event  *event);
    virtual void onTouchCancelled(Touch *touch, Event *event);
    //SptLoaderListener
    virtual void onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData);
    virtual void onSptLoaderError(const char *localPath, void *userData);
    
private:
    DragView *_dragView;
    SptLoader *_sptLoader;
    
};

#endif // __MATCH_LIST_SCENE_H__
