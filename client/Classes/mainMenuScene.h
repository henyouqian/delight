#ifndef __MAIN_MENU_SCENE_H__
#define __MAIN_MENU_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class MainMenuScene : public cocos2d::Layer {
public:
    static cocos2d::Scene* createScene();
    virtual bool init();
    CREATE_FUNC(MainMenuScene);
    
    void enterGame(Object *sender, Control::EventType controlEvent);
    void enterBook(Object *sender, Control::EventType controlEvent);
private:
    
};


#endif // __MAIN_MENU_SCENE_H__
