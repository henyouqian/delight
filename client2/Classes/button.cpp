#include "button.h"
#include "jsonxx/jsonxx.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;


Button* Button::create(const char* bgFile) {
    auto p = new Button();
    if (p && p->init(bgFile)) {
        p->autorelease();
        return p;
    }
    CC_SAFE_DELETE(p);
    return nullptr;
}

bool Button::init(const char* bgFile) {
    if (!Scale9Sprite::initWithFile(bgFile)) {
        return false;
    }
    this->setOpacity(0);
    
    _isPushed = false;
    _targetClick = nullptr;
    _handlerClick = nullptr;
    
    ////////////////////////
    //touch
    auto _touchListener = EventListenerTouchOneByOne::create();
    _touchListener->setSwallowTouches(true);
    _touchListener->onTouchBegan = [this](Touch* touch, Event* event){
        Point locationInNode = this->convertToNodeSpace(touch->getLocation());
        Size s = this->getContentSize();
        Rect rect = Rect(0, 0, s.width, s.height);
        
        if (rect.containsPoint(locationInNode)) {
            auto fadein = FadeIn::create(.04f);
            this->runAction(fadein);
            _isPushed = true;
            
            for (auto labelInfo : _LabelInfos) {
                labelInfo.label->setColor(labelInfo.highlightColor);
            }
            return true;
        }
        return true;
    };
    
    _touchListener->onTouchMoved = [=](Touch* touch, Event* event){
        
    };
    
    _touchListener->onTouchEnded = [=](Touch* touch, Event* event){
        _isPushed = false;
        auto fadeout = FadeOut::create(.1f);
        this->runAction(fadeout);
        for (auto labelInfo : _LabelInfos) {
            labelInfo.label->setColor(labelInfo.normalColor);
        }
        Point locationInNode = this->convertToNodeSpace(touch->getLocation());
        Size s = this->getContentSize();
        Rect rect = Rect(0, 0, s.width, s.height);
        
        if (rect.containsPoint(locationInNode)) {
            if (_targetClick && _handlerClick) {
                (_targetClick->*_handlerClick)(this);
            }
        }
    };
    
    _eventDispatcher->addEventListenerWithSceneGraphPriority(_touchListener, this);
    
    return true;
}

Button::~Button() {
    if (_targetClick) {
        _targetClick->release();
    }
}

void Button::addLabel(LabelTTF *label, const Color3B &normalColor, const Color3B &highlightColor) {
    this->addChild(label);
    
    auto labelInfo = LabelInfo{label, normalColor, highlightColor};
    _LabelInfos.push_back(labelInfo);
    label->setColor(normalColor);
}

void Button::onClick(Ref* target, Handler handler) {
    if (_targetClick) {
        _targetClick->release();
    }
    
    _targetClick = target;
    _handlerClick = handler;
    _targetClick->retain();
}








