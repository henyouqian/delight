#include "modeSelectScene.h"
#include "sliderScene.h"
#include "packsListScene.h"
#include "util.h"

USING_NS_CC;
USING_NS_CC_EXT;

Scene* ModeSelectScene::createScene(PacksListScene *packListScene) {
    auto scene = Scene::create();
    auto layer = new ModeSelectScene();
    bool ok = layer->init(packListScene);
    if (ok) {
        layer->autorelease();
        scene->addChild(layer);
        return scene;
    } else {
        return nullptr;
    }
}

bool ModeSelectScene::init(PacksListScene *scene) {
    if ( !Layer::init() ) {
        return false;
    }
    _packListScene = scene;
    Size visibleSize = Director::getInstance()->getVisibleSize();
    
    //background
    auto cover = _packListScene->selPack->cover;
    
    //button
    float btnY = 240.f;
    
    //casual button
    auto button = createButton("休闲", 36, 1.5f);
    button->setPosition(Point(visibleSize.width/3, btnY));
    button->addTargetWithActionForControlEvents(this, cccontrol_selector(ModeSelectScene::enterCasualMode), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(button, 1);
    
    //time attck button
    button = createButton("计时", 36, 1.5f);
    button->setPosition(Point(visibleSize.width/3*2.f, btnY));
    button->addTargetWithActionForControlEvents(this, cccontrol_selector(ModeSelectScene::enterCasualMode), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(button, 1);
    
    //back button
    auto btnBack = createButton("﹤", 48, 1.f);
    btnBack->setPosition(Point(70, 70));
    btnBack->addTargetWithActionForControlEvents(this, cccontrol_selector(ModeSelectScene::back), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(btnBack);
    
    return true;
}

void ModeSelectScene::enterCasualMode(Object *sender, Control::EventType controlEvent) {
    auto selPack = _packListScene->selPack;
    auto scene = SliderScene::createScene(selPack->title.c_str(), selPack->text.c_str(), selPack->images.c_str());
    Director::getInstance()->pushScene(TransitionFade::create(0.5f, scene));
}

void ModeSelectScene::enterTimeAttackMode(Object *sender, Control::EventType controlEvent) {
    auto selPack = _packListScene->selPack;
    auto scene = SliderScene::createScene(selPack->title.c_str(), selPack->text.c_str(), selPack->images.c_str());
    Director::getInstance()->pushScene(TransitionFade::create(0.5f, scene));
}

void ModeSelectScene::back(Object *sender, Control::EventType controlEvent) {
    Director::getInstance()->popSceneWithTransition<TransitionFade>(.5f);
    //Director::getInstance()->popScene();
}