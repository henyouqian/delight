#ifndef __MATCH_LIST_SCENE_H__
#define __MATCH_LIST_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"

#include "spriteLoader.h"
#include "pack.h"

USING_NS_CC;
USING_NS_CC_EXT;

class DragView;

class MatchListLayer : public Layer, public SptLoaderListener{
public:
    CREATE_FUNC(MatchListLayer);
    static MatchListLayer* createWithScene();
    bool init();
    
    //
    void onHttpListMatch(HttpClient* client, HttpResponse* response);
    
    //touch
    virtual bool onTouchBegan(Touch* touch, Event  *event);
    virtual void onTouchMoved(Touch* touch, Event  *event);
    virtual void onTouchEnded(Touch* touch, Event  *event);
    virtual void onTouchCancelled(Touch *touch, Event *event);
    
    //SptLoaderListener
    virtual void onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData);
    virtual void onSptLoaderError(const char *localPath, void *userData);
    
    //
    void freePlay(Object *sender, Control::EventType controlEvent);
    
private:
    DragView *_dragView;
    SptLoader *_sptLoader;
    
    struct MatchInfo {
        uint64_t matchId;
        std::string beginTime;
		std::string endTime;
        PackInfo packInfo;
        Rect thumbRect;
        std::string thumbFilePath;
        bool loaded;
    };
    std::vector<MatchInfo> _matchInfos;
    float _thumbWidth;
    float _thumbHeight;
};

#endif // __MATCH_LIST_SCENE_H__
