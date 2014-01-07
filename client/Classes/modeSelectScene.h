#ifndef __MODE_SELECT_SCENE_H__
#define __MODE_SELECT_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class PacksListScene;

class ModeSelectScene : public cocos2d::Layer {
public:
    static cocos2d::Scene* createScene(PacksListScene *packListScene);
    virtual bool init(PacksListScene *scene);
    
    void enterCasualMode(Object *sender, Control::EventType controlEvent);
    void enterTimeAttackMode(Object *sender, Control::EventType controlEvent);
    void back(Object *sender, Control::EventType controlEvent);
    
private:
    PacksListScene *_packListScene;
};

#endif // __MODE_SELECT_SCENE_H__
