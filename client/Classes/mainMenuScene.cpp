#include "mainMenuScene.h"
#include "packsBookScene.h"
#include "util.h"
#include "lang.h"

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
    
    srand(time(nullptr));
    
    Size visibleSize = Director::getInstance()->getVisibleSize();
    
    //
    auto button = createButton(lang("Play"), 48, 2.f);
    button->setPosition(Point(visibleSize.width/2, visibleSize.height/3));
    button->addTargetWithActionForControlEvents(this, cccontrol_selector(MainMenuScene::enterBook), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(button, 1);
    
    return true;
}

void MainMenuScene::onEnterTransitionDidFinish() {
    TextureCache::getInstance()->removeUnusedTextures();
}

void MainMenuScene::enterBook(Object *sender, Control::EventType controlEvent) {
    Director::getInstance()->pushScene(TransitionFade::create(0.5f, PacksBookScene::createScene()));
}