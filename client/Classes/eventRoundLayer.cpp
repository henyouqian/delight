#include "eventRoundLayer.h"
#include "jsonxx/jsonxx.h"
#include "db.h"
#include "http.h"
#include "util.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

static Color3B BTN_COLOR(0, 122, 255);

EventRoundLayer* EventRoundLayer::create() {
    auto scene = Scene::create();
    auto layer = new EventRoundLayer();
    if (layer && layer->init()) {
        layer->autorelease();
        scene->addChild(layer);
        return layer;
    }
    CC_SAFE_DELETE(layer);
    return nullptr;
}

bool EventRoundLayer::init() {
    if (!LayerColor::initWithColor(Color4B(255, 255, 255, 255))) {
        return false;
    }
    
    auto sz = this->getContentSize();
    
    setTouchEnabled(true);
    this->setTouchMode(Touch::DispatchMode::ONE_BY_ONE);
//    auto visSize = Director::getInstance()->getVisibleSize();
    return true;
}
