#ifndef __EVENT_ROUND_LAYER_H__
#define __EVENT_ROUND_LAYER_H__

#include "cocos2d.h"
#include "cocos-ext.h"


USING_NS_CC;
USING_NS_CC_EXT;

class EventRoundLayer : public LayerColor{
public:
    static EventRoundLayer* create();
    bool init();
    
private:
};

#endif // __EVENT_ROUND_LAYER_H__