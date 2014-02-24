#ifndef __SLIDER_SCENE_H__
#define __SLIDER_SCENE_H__

#include "pack.h"
#include "gameplay.h"
#include "cocos2d.h"
#include "cocos-ext.h"
#include <chrono>

USING_NS_CC;
USING_NS_CC_EXT;

class TimeBar : public SpriteBatchNode {
public:
    static TimeBar* create(float dur1, float dur2, float dur3);
    
    bool init(float dur1, float dur2, float dur3);
    void run();
    void stop();
    int getStarNum();
    
    virtual void update(float dt);
    
private:
    float _dur1;
    float _dur2;
    float _dur3;
    float _durSum;
    Sprite *_bar;
    
    std::chrono::time_point<chrono::system_clock> _startTimePoint;
    int _colorIdx;
};

class SliderScene : public cocos2d::Layer, public GameplayListener{
public:
    static Scene* createScene(PackInfo *packInfo);
    static SliderScene* create(PackInfo *packInfo);
    bool init(PackInfo *packInfo);
    
    virtual ~SliderScene();
    
    //GameplayListener
    virtual void onReset(float rotate);
    
    virtual void onTouchesBegan(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesMoved(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesEnded(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesCancelled(const std::vector<Touch*>&touches, Event *event);
    
    void ShowBackConfirm(Object *sender, Control::EventType controlEvent);
    void HideBackConfirm(Object *sender, Control::EventType controlEvent);
    void back(Object *sender, Control::EventType controlEvent);
    void next(Object *sender, Control::EventType controlEvent);
    
    void showStar();
    
private:
    Gameplay *_gameplay;
    std::vector<std::string> _imagePaths;
    int _imgIdx;
    
    ControlButton *_btnNext;
    ControlButton *_btnBack;
    
    ControlButton *_btnYes;
    ControlButton *_btnNo;
    
    ControlButton *_btnFinish;
    ControlButton *_btnNextPack;
    
//    void reset(const char* filename);
    void reset(int imgIdx);
    
    PackInfo *_packInfo;
    std::string _randomImagePaths;
    
    SpriteBatchNode *_dotBatch;
    std::vector<Sprite*> _dots;
    
    TimeBar *_timeBar;
    bool _isFinish;
    
    LabelTTF *_starLabel;
    LabelTTF *_gradeLabel;
};



#endif // __SLIDER_SCENE_H__
