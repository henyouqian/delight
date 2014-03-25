#ifndef __EVENT_HOME_SCENE_H__
#define __EVENT_HOME_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"

#include "eventListScene.h"
#include "pack.h"

USING_NS_CC;
USING_NS_CC_EXT;

class DragView;

struct Team {
	uint32_t Id;
	int32_t Score;
};

struct Game {
    std::vector<Team> Teams;
};

struct Round {
	std::vector<Game> Games;
};

struct EventResult {
    uint64_t EventId;
	int CurrRound;
	std::vector<Round> Rounds;
};

class EventHomeLayer : public LayerColor{
public:
    static EventHomeLayer* createWithScene(EventInfo* eventInfo);
    bool init(EventInfo* eventInfo);
    
    //button callback
    void back(Object *sender, Control::EventType controlEvent);
    
    //http callback
    void onHttpGetPack(HttpClient* cli, HttpResponse* resp);
    void onHttpGetResult(HttpClient* cli, HttpResponse* resp);
    
    //touch
    virtual bool onTouchBegan(Touch* touch, Event  *event);
    virtual void onTouchMoved(Touch* touch, Event  *event);
    virtual void onTouchEnded(Touch* touch, Event  *event);
    virtual void onTouchCancelled(Touch *touch, Event *event);
    
private:
    DragView *_dragView;
    EventInfo _eventInfo;
    PackInfo _packInfo;
    
    LabelTTF *_labelEventInfo;
    LabelTTF *_labelEventResult;
};

#endif // __EVENT_HOME_SCENE_H__
