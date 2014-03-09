#include "matchLobbyScene.h"
#include "matchScene.h"
#include "util.h"
#include "lang.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

MatchLobbyLayer* MatchLobbyLayer::create(PackInfo &packInfo) {
    auto scene = Scene::create();
    auto layer = new MatchLobbyLayer();
    if (layer && layer->init(packInfo)) {
        layer->autorelease();
        scene->addChild(layer);
        return layer;
    }
    CC_SAFE_DELETE(layer);
    return nullptr;
}

bool MatchLobbyLayer::init(PackInfo &packInfo) {
    if ( !LayerColor::initWithColor(Color4B(0, 0, 0, 255)) ) {
        return false;
    }
    
    _packInfo = packInfo;
    _bg = nullptr;
    
    Size visSize = Director::getInstance()->getVisibleSize();
    
    //sprite loader
    _sptLoader = SptLoader::create(this);
    addChild(_sptLoader);
    
    //background(cover)
    //_sptLoader->download(packInfo.cover.c_str());
    
    //button
    float btnY = 240.f;
    
    //casual button
    auto button = createButton(lang("Challenge"), 36, 1.5f);
    button->setPosition(Point(visSize.width/3, btnY));
    button->addTargetWithActionForControlEvents(this, cccontrol_selector(MatchLobbyLayer::enterCasualMode), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(button, 1);
    
    //time attck button
    button = createButton(lang("Gallery"), 36, 1.5f);
    button->setPosition(Point(visSize.width/3*2.f, btnY));
    button->addTargetWithActionForControlEvents(this, cccontrol_selector(MatchLobbyLayer::enterCasualMode), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(button, 1);
    
    //back button
    //auto button = createButton("〈", 48, 1.f);
    auto btnBack = createButton("HelveticaNeue", "〈", FORWARD_BACK_FONT_SIZE, Color3B(255, 255, 255), "ui/btnBg.png", 1.f, Color3B(255, 255, 255), 180);
    btnBack->setTitleOffset(-FORWARD_BACK_FONT_OFFSET, 0.f);
    btnBack->setPosition(Point(70, visSize.height-70));
    btnBack->addTargetWithActionForControlEvents(this, cccontrol_selector(MatchLobbyLayer::back), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(btnBack, 1);
    
    //progress label
    _progressLabel = LabelTTF::create("0%", "HelveticaNeue", 38);
    _progressLabel->setAnchorPoint(Point(.5f, .5f));
    _progressLabel->setPosition(Point(visSize.width*.5f, 600));
    _progressLabel->setColor(Color3B(250, 250, 250));
    _progressLabel->setVisible(false);
    _progressLabel->enableShadow(Size(2.f, -2.f), .8f, 2.f);
    addChild(_progressLabel, 1);
    
    return true;
}


MatchLobbyLayer::~MatchLobbyLayer() {
    _sptLoader->destroy();
    TextureCache::getInstance()->removeUnusedTextures();
}

void MatchLobbyLayer::enterCasualMode(Object *sender, Control::EventType controlEvent) {
    auto layer = MatchLayer::create(&_packInfo);
    Director::getInstance()->pushScene(TransitionFade::create(0.5f, (Scene*)layer->getParent()));
}

void MatchLobbyLayer::onEnter() {
    LayerColor::onEnter();
    TextureCache::getInstance()->removeUnusedTextures();
}


void MatchLobbyLayer::back(Object *sender, Control::EventType controlEvent) {
    Director::getInstance()->popSceneWithTransition<TransitionFade>((Scene*)this->getParent(), .5f);
}

void MatchLobbyLayer::onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData) {
    auto visSize = Director::getInstance()->getVisibleSize();
    sprite->setPosition(Point(visSize.width*.5f, visSize.height*.5f));
    auto sptSize = sprite->getContentSize();
    float scale = MAX(visSize.width / sptSize.width, visSize.height / sptSize.height);
    sprite->setScale(scale);
    sprite->setOpacity(0);
    addChild(sprite);
    auto fadeIn = EaseSineIn::create(FadeIn::create(.5f));
    sprite->runAction(fadeIn);
    _bg = sprite;
}

void MatchLobbyLayer::onSptLoaderError(const char *localPath, void *userData) {
    lwerror("MatchLobbyLayer::onSptLoaderError");
}

