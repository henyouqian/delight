#ifndef __DRAG_VIEW_H__
#define __DRAG_VIEW_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class DragView : public LayerColor {
public:
    CREATE_FUNC(DragView);
    bool init();
    virtual void onEnter();
    virtual void onExit();
    
    void setWindowRect(const Rect &rect);
    const Rect& getWindowRect();
    void setContentHeight(float height);
    float getContentHeight();
    bool isDragging();
    void resetY();
    
    bool onTouchBegan(Touch* touch, Event* event);
    void onTouchMoved(Touch* touch, Event* event);
    void onTouchEnded(Touch* touch, Event* event);
    
    virtual void update(float delta);
    
    void bounceEnd();
    
    bool beyondTop();
    bool beyondBottom();
    
private:
    bool _trackTouch;
    bool _dragging;
    Rect _windowRect;
    float _contentHeight;
    
    struct DragPointInfo {
        float y;
        std::chrono::steady_clock::time_point t;
    };
    std::list<DragPointInfo> _dragPointInfos;
    float _rollSpeed;
    bool _bouncing;
    EventListenerTouchOneByOne *_touchListener;
};

#endif // __DRAG_VIEW_H__
