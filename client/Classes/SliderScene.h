#ifndef __SLIDER_SCENE_H__
#define __SLIDER_SCENE_H__

#include "packLoader.h"
#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class Gameplay;

class SliderScene : public cocos2d::Layer, public PackLoaderListener {
public:
    static cocos2d::Scene* createScene();
    virtual bool init();
    CREATE_FUNC(SliderScene);
    virtual ~SliderScene();
    
    virtual void onTouchesBegan(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesMoved(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesEnded(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesCancelled(const std::vector<Touch*>&touches, Event *event);
    
    virtual void onError(const char* error);
    virtual void onPackDownload();
    virtual void onImageReady(const char* path);
    
private:
    Gameplay *_gameplay;
    std::vector<std::string> _imagePaths;
    int _imgIdx;
    
    Menu *_completedMenu;
    Menu *_playingMenu;
    
    void reset(const char* filename);
    void onNextImage(Object *obj);
};



#endif // __SLIDER_SCENE_H__
