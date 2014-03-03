#include "matchListScene.h"

USING_NS_CC;
USING_NS_CC_EXT;

bool MatchListLayer::init() {
    if (!Layer::init()) {
        return false;
    }
    
    setTouchEnabled(true);
    this->setTouchMode(Touch::DispatchMode::ONE_BY_ONE);
    
    return true;
}

//touch
bool MatchListLayer::onTouchBegan(Touch* touch, Event  *event) {
    return true;
}

void MatchListLayer::onTouchMoved(Touch* touch, Event  *event) {
    
}

void MatchListLayer::onTouchEnded(Touch* touch, Event  *event) {
    
}

void MatchListLayer::onTouchCancelled(Touch *touch, Event *event) {
    
}


//SptLoaderListener
void MatchListLayer::onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData) {
    
}

void MatchListLayer::onSptLoaderError(const char *localPath, void *userData) {
    
}