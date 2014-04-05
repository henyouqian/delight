#ifndef __EVENT_HOME_SCENE_H__
#define __EVENT_HOME_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"
#include "network/HttpClient.h"

#include "eventListScene.h"
#include "sliderScene.h"
#include "pack.h"

USING_NS_CC;
USING_NS_CC_EXT;
using namespace cocos2d::network;

class DragView;
class EventRoundLayer;

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
    ~EventHomeLayer();
    
    virtual void onEnter();
    virtual void onExit();
    virtual void update(float delta);
    
    //button callback
    void back(Ref *sender, Control::EventType controlEvent);
    void practice(Ref *sender, Control::EventType controlEvent);
    void play(Ref *sender, Control::EventType controlEvent);
    void rounds(Ref *sender, Control::EventType controlEvent);
    
    //http callback
    void onHttpGetPack(HttpClient* cli, HttpResponse* resp);
    void onHttpGetResult(HttpClient* cli, HttpResponse* resp);
    void onHttpGetMyResult(HttpClient* cli, HttpResponse* resp);
    void onHttpPlayBegin(HttpClient* cli, HttpResponse* resp);
    
    //touch
    bool onTouchBegan(Touch* touch, Event* event);
    void onTouchMoved(Touch* touch, Event* event);
    void onTouchEnded(Touch* touch, Event* event);
    
private:
    EventInfo _eventInfo;
    PackInfo _packInfo;
    EventResult _result;
    
    LabelTTF *_labelHighScore;
    LabelTTF *_labelRank;
    LabelTTF *_labelTeams;
    
    LabelTTF *_labelEventInfo;
    LabelTTF *_labelEventResult;
    LabelTTF *_labelPlayerResult;
    LabelTTF *_labelTimeLeft;
    EventListenerTouchOneByOne *_touchListener;
    
    std::vector<EventRoundLayer*> _roundLayers;
    bool _isDragging;
    PlayTicket _ticket;
};

#endif // __EVENT_HOME_SCENE_H__
