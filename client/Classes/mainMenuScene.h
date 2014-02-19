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
    
    virtual void onEnterTransitionDidFinish();
    
    void enterCollectionList(Object *sender, Control::EventType controlEvent);
    void enterUserPack(Object *sender, Control::EventType controlEvent);
    
    void onLogin(HttpClient *, HttpResponse *);
    void onInfo(HttpClient *, HttpResponse *);
private:
    
};


#endif // __MAIN_MENU_SCENE_H__
