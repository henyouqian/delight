#ifndef __DRAG_VIEW_H__
#define __DRAG_VIEW_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class DragView : public Node {
public:
    CREATE_FUNC(DragView);
    bool init();
    void setWindowRect(const Rect &rect);
    const Rect& getWindowRect();
    void setContentHeight(float height);
    bool isDragging();
    
    virtual void onTouchesBegan(const Touch* touch);
    virtual void onTouchesMoved(const Touch* touch);
    virtual void onTouchesEnded(const Touch* touch);
    
    virtual void update(float delta);
    
    void bounceEnd();
    
private:
    bool beyondTop();
    bool beyondBottom();
    
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
    
};

#endif // __DRAG_VIEW_H__
