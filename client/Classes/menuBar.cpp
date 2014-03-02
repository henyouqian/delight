#include "menuBar.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

MenuBar* MenuBar::create(MenuBarListener *listener) {
    MenuBar *p = new MenuBar();
    if (p && p->init(listener)) {
        p->autorelease();
        return p;
    }
    CC_SAFE_DELETE(p);
    return nullptr;
}

bool MenuBar::init(MenuBarListener *listener) {
    if (!LayerColor::init()) {
        return false;
    }
    _selIdx = -1;
    _listener = listener;
    
    setTouchEnabled(true);
    return true;
}

void MenuBar::addElem(const char *icon, float iconScale, const std::function<void()>& func) {
    auto spt = Sprite::create(icon);
    spt->setScale(iconScale);
    spt->setUserData((void*)&func);
    this->addChild(spt);
    
    layout();
}

void MenuBar::layout() {
    auto count = this->getChildrenCount();
    auto size = this->getContentSize();
    auto dx = size.width/count;
    float x = dx*.5f;
    Array *chidren = this->getChildren();
    Object* pObj = NULL;
    CCARRAY_FOREACH(chidren, pObj) {
        Sprite* spt = static_cast<Sprite*>(pObj);
        spt->setPosition(Point(x, size.height*.5f));
        x += dx;
    }
}

void MenuBar::select(uint32_t idx) {
    if (idx == _selIdx || idx >= this->getChildrenCount()) {
        lwerror("idx out of range");
        return;
    }
    
    _selIdx = idx;
    Array *chidren = this->getChildren();
    Object* pObj = NULL;
    int i = 0;
    CCARRAY_FOREACH(chidren, pObj) {
        Sprite* spt = static_cast<Sprite*>(pObj);
        if (i == idx) {
            spt->setColor(Color3B(255, 255, 255));
        } else {
            spt->setColor(Color3B(100, 100, 100));
        }
        i++;
    }
    if (_listener) {
        _listener->onMenuBarSelect(idx);
    }
}

void MenuBar::onEnter() {
    LayerColor::onEnter();
    this->setTouchMode(Touch::DispatchMode::ONE_BY_ONE);
}

bool MenuBar::isTouchInside(Touch* touch) {
    Point touchLocation = touch->getLocation(); // Get the touch position
    touchLocation = this->getParent()->convertToNodeSpace(touchLocation);
    Rect bBox = getBoundingBox();
    return bBox.containsPoint(touchLocation);
}

bool MenuBar::onTouchBegan(Touch* touch, Event  *event) {
    if (!isTouchInside(touch)) {
        return false;
    }
    auto pt = touch->getLocation();
    auto count = this->getChildrenCount();
    auto w = this->getContentSize().width / count;
    _touchIdx = floor(pt.x / w);
    
    return true;
}

void MenuBar::onTouchMoved(Touch* touch, Event  *event) {
    
}

void MenuBar::onTouchEnded(Touch* touch, Event  *event) {
    auto pt = touch->getLocation();
    auto count = this->getChildrenCount();
    auto w = this->getContentSize().width / count;
    auto idx = floor(pt.x / w);
    if (idx == _touchIdx) {
        select(idx);
    }
}

void MenuBar::onTouchCancelled(Touch *touch, Event *event) {
    
}