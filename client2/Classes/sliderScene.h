#ifndef __SLIDER_SCENE_H__
#define __SLIDER_SCENE_H__

#include "pack.h"
#include "gameplay.h"
#include "cocos2d.h"
#include "cocos-ext.h"
#include <chrono>

USING_NS_CC;
USING_NS_CC_EXT;

class ModeSelectScene;
struct EventInfo;

class TimeBar : public SpriteBatchNode {
public:
    static TimeBar* create(float dur1, float dur2, float dur3);
    
    bool init(float dur1, float dur2, float dur3);
    void run();
    void stop();
    int getStarNum();
    uint32_t getMilliseconds();
    virtual void update(float dt);
    
private:
    float _dur1;
    float _dur2;
    float _dur3;
    float _durSum;
    Sprite *_bar;
    
    std::chrono::time_point<std::chrono::system_clock> _startTimePoint;
    int _colorIdx;
};

struct PlayTicket {
    std::string secret;
    int64_t secretExpire;
    int32_t highScore;
    uint32_t trys;
};

class SliderLayer : public cocos2d::Layer, public GameplayListener{
public:
    static SliderLayer* createWithScene(PackInfo *packInfo, EventInfo *eventInfo, PlayTicket *ticket);
    bool init(PackInfo *packInfo, EventInfo *eventInfo, PlayTicket *ticket);
    virtual ~SliderLayer();
    virtual void onEnter();
    virtual void onExit();
    
    //GameplayListener
    virtual void onReset(float rotate);
    
    //http
    void onHttpPlayEnd(HttpClient* cli, HttpResponse* resp);
    
    //
    bool onTouchBegan(Touch* touch, Event* event);
    void onTouchMoved(Touch* touch, Event* event);
    void onTouchEnded(Touch* touch, Event* event);
    
    void ShowBackConfirm(Ref *sender, Control::EventType controlEvent);
    void HideBackConfirm(Ref *sender, Control::EventType controlEvent);
    void back(Ref *sender, Control::EventType controlEvent);
    void next(Ref *sender, Control::EventType controlEvent);
    void nextPack(Ref *sender, Control::EventType controlEvent);
    
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
    EventInfo *_eventInfo;
    std::string _randomImagePaths;
    
    SpriteBatchNode *_dotBatch;
    std::vector<Sprite*> _dots;
    
    TimeBar *_timeBar;
    bool _isFinish;
    
    LabelTTF *_starLabel;
    LabelTTF *_gradeLabel;
    
    EventListenerTouchOneByOne *_touchListener;
    PlayTicket *_ticket;
};



#endif // __SLIDER_SCENE_H__
