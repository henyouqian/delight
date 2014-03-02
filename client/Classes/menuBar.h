#ifndef __MENU_BAR_H__
#define __MENU_BAR_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class MenuBarListener {
public:
    virtual void onMenuBarSelect(uint32_t idx) {}
};

class MenuBar : public LayerColor {
public:
    static MenuBar* create(MenuBarListener *listener);
    bool init(MenuBarListener *listener);
    
    void addElem(const char *icon, float iconScale, const std::function<void()>& func);
    void select(uint32_t idx);
    
    virtual void onEnter();
    
    virtual bool onTouchBegan(Touch* touch, Event  *event) override;
    virtual void onTouchMoved(Touch* touch, Event  *event) override;
    virtual void onTouchEnded(Touch* touch, Event  *event) override;
    virtual void onTouchCancelled(Touch *touch, Event *event) override;
    
private:
    bool isTouchInside(Touch* touch);
    void layout();
    
    MenuBarListener *_listener;
    uint32_t _selIdx;
    uint32_t _touchIdx;
    
//    struct Elem {
//        Sprite* sprite;
//        const std::function<void()> func;
//    };
//    std::vector<>
};

#endif // __MENU_BAR_H__
