#include "mainMenuScene.h"
#include "packsListScene.h"
#include "util.h"

USING_NS_CC;
USING_NS_CC_EXT;

Scene* MainMenuScene::createScene() {
    auto scene = Scene::create();
    auto layer = MainMenuScene::create();
    scene->addChild(layer);
    return scene;
}

bool MainMenuScene::init() {
    if ( !Layer::init() ) {
        return false;
    }
    
    Size visibleSize = Director::getInstance()->getVisibleSize();
    
    auto button = createButton("玩", 48, 2.f);
    button->setPosition(Point(visibleSize.width/2, visibleSize.height/2));
    button->addTargetWithActionForControlEvents(this, cccontrol_selector(MainMenuScene::enterGame), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(button, 1);
    
    return true;
}

void MainMenuScene::enterGame(Object *sender, Control::EventType controlEvent) {
    Director::getInstance()->pushScene(TransitionFade::create(0.5f, PacksListScene::createScene()));
}