#ifndef __SPRITE_LOADER_H__
#define __SPRITE_LOADER_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

struct SptLoader {
    static SptLoader* loadFromUrl(const char *url, Sprite *placeholder = nullptr);
    SptLoader();
    ~SptLoader();
    
    std::string url;
    std::string local;
    Sprite *placeholder;
    Sprite *sprite;
    
    enum State {
        READY,
        DOWNLOADING,
        LOADING,
        SUCCEED,
        ERROR,
    };
    State state;
    std::function<void(SptLoader*)> _onEvent;
};


#endif // __SPRITE_LOADER_H__
