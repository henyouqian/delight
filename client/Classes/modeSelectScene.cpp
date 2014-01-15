#include "modeSelectScene.h"
#include "sliderScene.h"
#include "util.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

cocos2d::Scene* ModeSelectScene::createScene(PackInfo *packInfo) {
    auto scene = Scene::create();
    auto layer = new ModeSelectScene();
    bool ok = layer->init(packInfo);
    if (ok) {
        layer->autorelease();
        scene->addChild(layer);
        return scene;
    } else {
        return nullptr;
    }
}

bool ModeSelectScene::init(PackInfo *packInfo) {
    if ( !LayerColor::initWithColor(Color4B(255, 255, 255, 255)) ) {
        return false;
    }
    _packInfo = packInfo;
    Size visibleSize = Director::getInstance()->getVisibleSize();
    
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
    
    //pack downloader
    _packDownloader = new PackDownloader;
    _packDownloader->init(_packInfo, this);
    
    //progress label
    auto visSize = Director::getInstance()->getVisibleSize();
    _progressLabel = LabelTTF::create("0%", "HelveticaNeue", 38);
    _progressLabel->setAnchorPoint(Point(.5f, .5f));
    _progressLabel->setPosition(Point(visSize.width*.5f, 600));
    _progressLabel->setColor(Color3B(30, 30, 30));
    _progressLabel->setVisible(false);
    addChild(_progressLabel);
    
    return true;
}

ModeSelectScene::~ModeSelectScene() {
    _packDownloader->destroy();
}

void ModeSelectScene::enterCasualMode(Object *sender, Control::EventType controlEvent) {
    if (_packDownloader->progress == 1.f) {
        auto scene = SliderScene::createScene(_packInfo);
        Director::getInstance()->pushScene(TransitionFade::create(0.5f, scene));
        _progressLabel->setVisible(false);
    } else {
        _packDownloader->startDownload();
        char buf[64];
        snprintf(buf, 64, "下载中... %d%%", (int)(_packDownloader->progress*100));
        _progressLabel->setString(buf);
        _progressLabel->setVisible(true);
    }
}

void ModeSelectScene::enterTimeAttackMode(Object *sender, Control::EventType controlEvent) {
    auto scene = SliderScene::createScene(_packInfo);
    Director::getInstance()->pushScene(TransitionFade::create(0.5f, scene));
}

void ModeSelectScene::back(Object *sender, Control::EventType controlEvent) {
    Director::getInstance()->popSceneWithTransition<TransitionFade>(.5f);
}

void ModeSelectScene::onPackError() {
    
}

void ModeSelectScene::onPackImageDownload() {
    char buf[64];
    snprintf(buf, 64, "下载中... %d%%", (int)(_packDownloader->progress*100));
    _progressLabel->setString(buf);
}

void ModeSelectScene::onPackDownloadComplete() {
    auto scene = SliderScene::createScene(_packInfo);
    Director::getInstance()->pushScene(TransitionFade::create(0.5f, scene));
    _progressLabel->setVisible(false);
}

