#include "packsBookScene.h"
#include "util.h"

USING_NS_CC;
USING_NS_CC_EXT;

cocos2d::Scene* PacksBookScene::createScene() {
    auto scene = Scene::create();
    auto layer = PacksBookScene::create();
    scene->addChild(layer);
    return scene;
}

bool PacksBookScene::init() {
    auto visSize = Director::getInstance()->getVisibleSize();
    
    if (!LayerColor::initWithColor(Color4B(255, 255, 255, 255)))  {
        return false;
    }
    this->setTouchEnabled(true);
    this->scheduleUpdate();
    
    //back button
    auto btnBack = createButton("<", 48, 1.f);
    btnBack->setPosition(Point(70, 70));
    btnBack->addTargetWithActionForControlEvents(this, cccontrol_selector(PacksBookScene::back), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(btnBack);
    
    //older
    auto label = LabelTTF::create("←older", "HelveticaNeue", 48);
    label->setAnchorPoint(Point(0.f, 0.f));
    label->setPosition(Point(20.f, visSize.height-103));
    label->setColor(Color3B(0, 122, 255));
    addChild(label);
    
    //newer
    label = LabelTTF::create("newer→", "HelveticaNeue", 48);
    label->setAnchorPoint(Point(1.f, 0.f));
    label->setPosition(Point(visSize.width-20.f, visSize.height-103));
    label->setColor(Color3B(0, 122, 255));
    addChild(label);
    
    //page
    auto page = LabelTTF::create("4/566", "HelveticaNeue", 42);
    page->setAnchorPoint(Point(.5f, 0.f));
    page->setPosition(Point(visSize.width*.5f, visSize.height-103));
    page->setColor(Color3B(0, 122, 255));
    addChild(page);
    
    return true;
}

PacksBookScene::~PacksBookScene() {
    
}

void PacksBookScene::back(Object *sender, Control::EventType controlEvent) {
    Director::getInstance()->popSceneWithTransition<TransitionFade>(.5f);
}