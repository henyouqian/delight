#include "SliderScene.h"
#include "gifTexture.h"
#include "gameplay.h"
#include "lw/lwLog.h"
#include "SimpleAudioEngine.h"
#include <sys/stat.h>

USING_NS_CC;
USING_NS_CC_EXT;

Scene* SliderScene::createScene() {
    auto scene = Scene::create();
    auto layer = SliderScene::create();
    scene->addChild(layer);
    return scene;
}

bool SliderScene::init() {
    auto t = time(nullptr);
    srand(t);
    if (!Layer::init()) {
        return false;
    }
    this->setTouchEnabled(true);
    
    _imgIdx = 0;
    
    auto ori = Director::getInstance()->getVisibleOrigin();
    auto size = Director::getInstance()->getVisibleSize();
    auto rect = Rect(ori.x, ori.y, size.width, size.height);
    _gameplay = new Gameplay(rect, this);
    
    //reset("img/railway.gif", 8);
    //reset("img/fiat500.jpg", 8);
    //_gameplay->reset("img/zz", 8);
    
    PackLoader::getInstance()->listener = this;
    PackLoader::getInstance()->load(5);
    
    //playingMenu
    auto sptPause = Sprite::create("ui/btnPause.png");
    auto itemPause = MenuItemSprite::create(sptPause, sptPause, std::bind(&SliderScene::onNextImage, this, std::placeholders::_1));
    itemPause->setPosition(size.width-itemPause->getContentSize().width*.5-15, itemPause->getContentSize().height*.5+15);
    itemPause->setOpacity(160);
    _playingMenu = Menu::create(itemPause, NULL);
    _playingMenu->setPosition(Point::ZERO);
    this->addChild(_playingMenu, 2);
    
    //menu
    auto spt = Sprite::create("ui/btnNext.png");
    auto itemNext = MenuItemSprite::create(spt, spt, std::bind(&SliderScene::onNextImage, this, std::placeholders::_1));
    itemNext->setPosition(size.width-itemNext->getContentSize().width*.5-15, size.height-itemNext->getContentSize().height*.5-15);
    _completedMenu = Menu::create(itemNext, NULL);
    _completedMenu->setPosition(Point::ZERO);
    this->addChild(_completedMenu, 2);
    _completedMenu->setVisible(false);
    
    return true;
}

SliderScene::~SliderScene() {
    if (_gameplay) {
        delete _gameplay;
    }
}

void SliderScene::onTouchesBegan(const std::vector<Touch*>& touches, Event *event) {
    auto touch = touches[0];
    if (!_imagePaths.empty() && touch->getLocation().y < 60) {
        if (touch->getLocation().x < 60) {
            _imgIdx--;
            if (_imgIdx == -1) {
                _imgIdx = _imagePaths.size() - 1;
            }
            reset(_imagePaths[_imgIdx].c_str());
            return;
        } else if (touch->getLocation().x > Director::getInstance()->getVisibleSize().width-60){
            _imgIdx++;
            if (_imgIdx == _imagePaths.size()) {
                _imgIdx = 0;
            }
            reset(_imagePaths[_imgIdx].c_str());
            return;
        }
    }
    
    _gameplay->onTouchesBegan(touches);
}

void SliderScene::onTouchesMoved(const std::vector<Touch*>& touches, Event *event) {
    _gameplay->onTouchesMoved(touches);
}

void SliderScene::onTouchesEnded(const std::vector<Touch*>& touches, Event *event) {
    _gameplay->onTouchesEnded(touches);
    if (_gameplay->isCompleted()) {
        _completedMenu->setVisible(true);
        _playingMenu->setVisible(false);
    }
}

void SliderScene::onTouchesCancelled(const std::vector<Touch*>&touches, Event *event) {
    onTouchesEnded(touches, event);
}

void SliderScene::onError(const char* error) {
    
}

void SliderScene::onPackDownload() {
    
}

void SliderScene::onImageReady(const char* path) {
    if (_imagePaths.empty()) {
        _gameplay->reset(path, 10);
        _imgIdx = 0;
    }
    _imagePaths.push_back(path);
}

void SliderScene::reset(const char* filename) {
    _gameplay->reset(filename, 10);
    _completedMenu->setVisible(false);
    _playingMenu->setVisible(true);
}

void SliderScene::onNextImage(Object *obj) {
    _imgIdx++;
    if (_imgIdx == _imagePaths.size()) {
        _imgIdx = 0;
    }
    reset(_imagePaths[_imgIdx].c_str());
}


