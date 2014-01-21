#ifndef __SLIDER_SCENE_H__
#define __SLIDER_SCENE_H__

#include "pack.h"
#include "gameplay.h"
#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class SliderScene : public cocos2d::Layer, public GameplayListener{
public:
    static Scene* createScene(PackInfo *packInfo);
    static SliderScene* create(PackInfo *packInfo);
    bool init(PackInfo *packInfo);
    
    virtual ~SliderScene();
    
    virtual void update(float delta);
    
    //GameplayListener
    virtual void onImageRotate(float rotate);
    
    virtual void onTouchesBegan(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesMoved(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesEnded(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesCancelled(const std::vector<Touch*>&touches, Event *event);
    
    void ShowBackConfirm(Object *sender, Control::EventType controlEvent);
    void HideBackConfirm(Object *sender, Control::EventType controlEvent);
    void back(Object *sender, Control::EventType controlEvent);
    void next(Object *sender, Control::EventType controlEvent);
    
private:
    Gameplay *_gameplay;
    std::vector<std::string> _imagePaths;
    int _imgIdx;
    
    ControlButton *_btnNext;
    ControlButton *_btnBack;
    
    ControlButton *_btnYes;
    ControlButton *_btnNo;
    
    ControlButton *_btnFinish;
    
//    void reset(const char* filename);
    void reset(int imgIdx);
    
    PackInfo *_packInfo;
    std::string _randomImagePaths;
    
    SpriteBatchNode *_dotBatch;
    std::vector<Sprite*> _dots;
};



#endif // __SLIDER_SCENE_H__
