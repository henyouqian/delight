#ifndef __EVENT_LIST_SCENE_H__
#define __EVENT_LIST_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class DragView;

struct EventInfo {
    enum Type{
        PERSONAL_RANK,
        TEAM_CHAMPIONSHIP,
    };
    Type type;
    uint64_t id;
    uint64_t packId;
    std::vector<int64_t> timePoints;
};

class EventListLayer : public Layer{
public:
    static EventListLayer* createWithScene();
    bool init();
    ~EventListLayer();
    
    //button callback
    void gotoLogin(Object *sender, Control::EventType controlEvent);
    void enterEvent(Object *sender, Control::EventType controlEvent);
    
    //
    void onHttpListEvent(HttpClient* client, HttpResponse* response);
    void onHttpListClosedEvent(HttpClient* client, HttpResponse* resp);
    
    //touch
    virtual bool onTouchBegan(Touch* touch, Event  *event);
    virtual void onTouchMoved(Touch* touch, Event  *event);
    virtual void onTouchEnded(Touch* touch, Event  *event);
    virtual void onTouchCancelled(Touch *touch, Event *event);
    
private:
    DragView *_dragView;
    std::vector<EventInfo*> _eventInfos;
    float _listY;
};

#endif // __EVENT_LIST_SCENE_H__
