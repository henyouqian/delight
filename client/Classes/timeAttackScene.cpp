#include "timeAttackScene.h"
#include "gifTexture.h"
#include "gameplay.h"
#include "util.h"
#include "lw/lwLog.h"
#include "SimpleAudioEngine.h"
#include <sys/stat.h>

USING_NS_CC;
USING_NS_CC_EXT;

Scene* TimeAttackScene::createScene(PackInfo *packInfo) {
    auto scene = Scene::create();
    auto layer = TimeAttackScene::create(packInfo);
    scene->addChild(layer);
    return scene;
}

TimeAttackScene* TimeAttackScene::create(PackInfo *packInfo) {
    TimeAttackScene *pRet = new TimeAttackScene();
    if (pRet && pRet->init(packInfo)) {
        pRet->autorelease();
        return pRet;
    }
    else {
        delete pRet;
        return NULL;
    }
}

bool TimeAttackScene::init(PackInfo *packInfo) {
    _packInfo = packInfo;
    auto t = time(nullptr);
    srand(t);
    if (!Layer::init()) {
        return false;
    }
    this->scheduleUpdate();
    this->setTouchEnabled(true);
    
    _imgIdx = 0;
    
    auto ori = Director::getInstance()->getVisibleOrigin();
    auto size = Director::getInstance()->getVisibleSize();
    auto rect = Rect(ori.x, ori.y, size.width, size.height);
    _gameplay = new Gameplay(rect, this);
    addChild(_gameplay);
    
    //reset("img/railway.gif", 8);
    //reset("img/fiat500.jpg", 8);
    //_gameplay->reset("img/zz", 8);
    
    //    PackLoader::getInstance()->listener = this;
    //    PackLoader::getInstance()->load(5);
    
    //playingMenu
    auto sptPause = Sprite::create("ui/btnPause.png");
    auto itemPause = MenuItemSprite::create(sptPause, sptPause, std::bind(&TimeAttackScene::onNextImage, this, std::placeholders::_1));
    itemPause->setPosition(size.width-itemPause->getContentSize().width*.5-15, itemPause->getContentSize().height*.5+15);
    itemPause->setOpacity(160);
    _playingMenu = Menu::create(itemPause, NULL);
    _playingMenu->setPosition(Point::ZERO);
    this->addChild(_playingMenu, 2);
    
    //menu
    auto spt = Sprite::create("ui/btnNext.png");
    auto itemNext = MenuItemSprite::create(spt, spt, std::bind(&TimeAttackScene::onNextImage, this, std::placeholders::_1));
    itemNext->setPosition(size.width-itemNext->getContentSize().width*.5-15, size.height-itemNext->getContentSize().height*.5-15);
    _completedMenu = Menu::create(itemNext, NULL);
    _completedMenu->setPosition(Point::ZERO);
    this->addChild(_completedMenu, 2);
    _completedMenu->setVisible(false);
    
    //back button
    auto btnBack = createButton("﹤", 48, 1.f);
    btnBack->setPosition(Point(50, 50));
    btnBack->addTargetWithActionForControlEvents(this, cccontrol_selector(TimeAttackScene::back), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(btnBack, 10);
    
    //shuffle image order
    _packInfo->shuffleImageIndices();
    
    //reset
    reset(0);
    
    return true;
}

TimeAttackScene::~TimeAttackScene() {
    if (_gameplay) {
        delete _gameplay;
    }
}

void TimeAttackScene::update(float delta) {
    
}

void TimeAttackScene::back(Object *sender, Control::EventType controlEvent) {
    Director::getInstance()->popSceneWithTransition<TransitionFade>(.5f);
}

void TimeAttackScene::onTouchesBegan(const std::vector<Touch*>& touches, Event *event) {
    _gameplay->onTouchesBegan(touches);
}

void TimeAttackScene::onTouchesMoved(const std::vector<Touch*>& touches, Event *event) {
    _gameplay->onTouchesMoved(touches);
}

void TimeAttackScene::onTouchesEnded(const std::vector<Touch*>& touches, Event *event) {
    _gameplay->onTouchesEnded(touches);
    if (_gameplay->isCompleted()) {
        _completedMenu->setVisible(true);
        _playingMenu->setVisible(false);
    }
}

void TimeAttackScene::onTouchesCancelled(const std::vector<Touch*>&touches, Event *event) {
    onTouchesEnded(touches, event);
}

void TimeAttackScene::reset(int imgIdx) {
    _imgIdx = imgIdx;
    std::string local;
    auto idx = _packInfo->imageIndices[_imgIdx];
    makeLocalImagePath(local, _packInfo->images[idx].url.c_str());
    _gameplay->reset(local.c_str(), 8);
    auto nextIdx = _imgIdx + 1;
    if (nextIdx >= _packInfo->images.size()) {
        nextIdx = 0;
    }
    idx = _packInfo->imageIndices[nextIdx];
    makeLocalImagePath(local, _packInfo->images[idx].url.c_str());
    _gameplay->preload(local.c_str());
    _completedMenu->setVisible(false);
    _playingMenu->setVisible(true);
}

void TimeAttackScene::onNextImage(Object *obj) {
    int imgIdx = _imgIdx + 1;
    if (imgIdx == _packInfo->images.size()) {
        imgIdx = 0;
    }
    reset(imgIdx);
}


