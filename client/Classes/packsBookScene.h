#ifndef __PACK_BOOK_SCENE_H__
#define __PACK_BOOK_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class PacksBookScene : public LayerColor {
public:
    static cocos2d::Scene* createScene();
    CREATE_FUNC(PacksBookScene);
    virtual bool init();
    virtual ~PacksBookScene();
    
    void back(Object *sender, Control::EventType controlEvent);
};


#endif // __PACK_BOOK_SCENE_H__
