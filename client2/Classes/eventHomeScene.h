#ifndef __EVENT_HOME_SCENE_H__
#define __EVENT_HOME_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"
#include "network/HttpClient.h"

#include "eventListScene.h"
#include "pack.h"

USING_NS_CC;
USING_NS_CC_EXT;
using namespace cocos2d::network;

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

struct PlayerResult {
    int32_t HighScore;
    uint32_t TeamId;
    uint32_t Trys;
    uint32_t Rank;
    uint32_t RankNum;
    uint32_t TeamRank;
    uint32_t TeamRankNum;
};

class EventHomeLayer : public LayerColor{
public:
    static EventHomeLayer* createWithScene(EventInfo* eventInfo);
    bool init(EventInfo* eventInfo);
    
    //button callback
    void back(Ref *sender, Control::EventType controlEvent);
    void play(Ref *sender, Control::EventType controlEvent);
    void rounds(Ref *sender, Control::EventType controlEvent);
    
    //http callback
    void onHttpGetPack(HttpClient* cli, HttpResponse* resp);
    void onHttpGetResult(HttpClient* cli, HttpResponse* resp);
    void onHttpGetPlayerResult(HttpClient* cli, HttpResponse* resp);
    
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
    LabelTTF *_labelPlayerResult;
};

#endif // __EVENT_HOME_SCENE_H__
