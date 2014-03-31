#ifndef __BUTTON_H__
#define __BUTTON_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class Button : public Scale9Sprite {
public:
    static Button* create(const char* bgFile);
    bool init(const char* bgFile);
    ~Button();
    
    void addLabel(LabelTTF *label, const Color3B &normalColor, const Color3B &highlightColor);
    
    typedef void (Ref::*Handler)(Ref*);
    void onClick(Ref* target, Handler handler);
    
private:
    bool _isPushed;
    
    struct LabelInfo {
        LabelTTF *label;
        Color3B normalColor;
        Color3B highlightColor;
    };
    
    std::vector<LabelInfo> _LabelInfos;
    Ref *_targetClick;
    Handler _handlerClick;
};

#endif // __BUTTON_H__
