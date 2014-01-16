#ifndef __SLIDER_SCENE_H__
#define __SLIDER_SCENE_H__

#include "pack.h"
#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class Gameplay;
class Pack;
struct PackInfo;

class SliderScene : public cocos2d::Layer {
public:
    static Scene* createScene(PackInfo *packInfo);
    static SliderScene* create(PackInfo *packInfo);
    bool init(PackInfo *packInfo);
    
    virtual ~SliderScene();
    
    virtual void update(float delta);
    
    virtual void onTouchesBegan(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesMoved(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesEnded(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesCancelled(const std::vector<Touch*>&touches, Event *event);
    
    void back(Object *sender, Control::EventType controlEvent);
    
private:
    Gameplay *_gameplay;
    std::vector<std::string> _imagePaths;
    int _imgIdx;
    
    Menu *_completedMenu;
    Menu *_playingMenu;
    
//    void reset(const char* filename);
    void reset(int imgIdx);
    void onNextImage(Object *obj);
    
    PackInfo *_packInfo;
};



#endif // __SLIDER_SCENE_H__
