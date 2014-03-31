#ifndef __EVENT_ROUND_LAYER_H__
#define __EVENT_ROUND_LAYER_H__

#include "cocos2d.h"
#include "cocos-ext.h"
#include "network/HttpClient.h"
#include "eventHomeScene.h"

USING_NS_CC;
USING_NS_CC_EXT;
using namespace cocos2d::network;

struct Round;

class EventRoundLayer : public LayerColor{
public:
    static EventRoundLayer* create(uint32_t idx);
    bool init(uint32_t idx);
    
    void setRound(Round* round);
    void cancelButton();
    
    //button callback
    void touchDown(Ref *sender, Control::EventType controlEvent);
    void gameDetail(Ref *sender, Control::EventType controlEvent);
    void prev(Ref *sender, Control::EventType controlEvent);
    void next(Ref *sender, Control::EventType controlEvent);
    
private:
    uint32_t _idx;
    Node *_roundGroup;
    ControlButton* _activeButton;
    Round _round;
};

#endif // __EVENT_ROUND_LAYER_H__
