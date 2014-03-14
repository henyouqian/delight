#include "matchLobbyScene.h"
#include "matchScene.h"
#include "util.h"
#include "lang.h"
#include "http.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

MatchLobbyLayer* MatchLobbyLayer::create(MatchInfo &matchInfo) {
    auto scene = Scene::create();
    auto layer = new MatchLobbyLayer();
    if (layer && layer->init(matchInfo)) {
        layer->autorelease();
        scene->addChild(layer);
        return layer;
    }
    CC_SAFE_DELETE(layer);
    return nullptr;
}

bool MatchLobbyLayer::init(MatchInfo &matchInfo) {
    if ( !LayerColor::initWithColor(Color4B(0, 0, 0, 255)) ) {
        return false;
    }
    
    _matchInfo = matchInfo;
    
    Size visSize = Director::getInstance()->getVisibleSize();
    
    //sprite loader
    _sptLoader = SptLoader::create(this);
    addChild(_sptLoader);
    
    //background(cover)
    //_sptLoader->download(packInfo.cover.c_str());
    
    //button
    float btnY = 240.f;
    
    //casual button
    auto button = createButton(lang("Free"), 36, 1.5f);
    button->setPosition(Point(visSize.width/3, btnY));
    button->addTargetWithActionForControlEvents(this, cccontrol_selector(MatchLobbyLayer::enterFreePlayMode), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(button, 1);
    
    //time attck button
    button = createButton(lang("Match"), 36, 1.5f);
    button->setPosition(Point(visSize.width/3*2.f, btnY));
    button->addTargetWithActionForControlEvents(this, cccontrol_selector(MatchLobbyLayer::enterMatchMode), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(button, 1);
    
    //back button
    //auto button = createButton("〈", 48, 1.f);
    auto btnBack = createButton("HelveticaNeue", "〈", FORWARD_BACK_FONT_SIZE, Color3B(255, 255, 255), "ui/btnBg.png", 1.f, Color3B(255, 255, 255), 180);
    btnBack->setTitleOffset(-FORWARD_BACK_FONT_OFFSET, 0.f);
    btnBack->setPosition(Point(70, visSize.height-70));
    btnBack->addTargetWithActionForControlEvents(this, cccontrol_selector(MatchLobbyLayer::back), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(btnBack, 1);
    
    //label
    _freePlayLabel = LabelTTF::create("fsdfsdf", "HelveticaNeue", 38, Size::ZERO, TextHAlignment::LEFT, TextVAlignment::TOP);
    _freePlayLabel->setAnchorPoint(Point(.5f, .5f));
    _freePlayLabel->setPosition(Point(visSize.width*.5f, 900));
    _freePlayLabel->setColor(Color3B(250, 250, 250));
    //_freePlayLabel->setVisible(false);
    _freePlayLabel->enableShadow(Size(2.f, -2.f), .8f, 2.f);
    _freePlayLabel->setString(lang("读取中"));
    addChild(_freePlayLabel, 1);
    
    _matchLabel = LabelTTF::create("fsdfsdf", "HelveticaNeue", 38, Size::ZERO, TextHAlignment::LEFT, TextVAlignment::TOP);
    _matchLabel->setAnchorPoint(Point(.5f, .5f));
    _matchLabel->setPosition(Point(visSize.width*.5f, 600));
    _matchLabel->setColor(Color3B(250, 250, 250));
    //_freePlayLabel->setVisible(false);
    _matchLabel->enableShadow(Size(2.f, -2.f), .8f, 2.f);
    _matchLabel->setString(lang("读取中"));
    addChild(_matchLabel, 1);
    
    //get match info
    jsonxx::Object msg;
    msg << "MatchId" << matchInfo.matchId;
    
    postHttpRequest("match/info", msg.json().c_str(), this, (SEL_HttpResponse)(&MatchLobbyLayer::onHttpMatchInfo));
    
    return true;
}

MatchLobbyLayer::~MatchLobbyLayer() {
    _sptLoader->destroy();
    TextureCache::getInstance()->removeUnusedTextures();
}

void MatchLobbyLayer::onHttpMatchInfo(HttpClient* client, HttpResponse* response) {
    jsonxx::Object msg;
    if (!response->isSucceed()) {
        lwerror("onHttpMatchInfo error");
    }
    
    //parse response
    std::string body;
    getHttpResponseString(response, body);
    bool ok = msg.parse(body);
    if (!ok) {
        lwerror("json parse error");
        return;
    }
    
    if (!msg.has<jsonxx::Number>("FreePlayRank")
        || !msg.has<jsonxx::Number>("FreePlayRankNum")
        || !msg.has<jsonxx::Number>("FreePlayTrys")
        || !msg.has<jsonxx::Number>("FreePlayHighScore")
        || !msg.has<jsonxx::Number>("MatchRank")
        || !msg.has<jsonxx::Number>("MatchRankNum")
        || !msg.has<jsonxx::Number>("MatchTrys")
        || !msg.has<jsonxx::Number>("MatchHighScore")
        ) {
        lwerror("json parse error");
        return;
    }
    
    //free play
    int freePlayRank = (int)msg.get<jsonxx::Number>("FreePlayRank");
    int freePlayRankNum = (int)msg.get<jsonxx::Number>("FreePlayRankNum");
    int freePlayTrys =  (int)msg.get<jsonxx::Number>("FreePlayTrys");
    int freePlayHighScore = (int)msg.get<jsonxx::Number>("FreePlayHighScore");
    
    if (freePlayRankNum > 0) {
        char buf[512];
        snprintf(buf, 512, "Rank: %d\nRankNum: %d\nTrys:%d\nHighScore:%d",
                 freePlayRank, freePlayRankNum, freePlayTrys, freePlayHighScore);
        _freePlayLabel->setString(buf);
    } else {
        _freePlayLabel->setString(lang("无记录"));
    }
    
    //match
    int matchRank = (int)msg.get<jsonxx::Number>("MatchRank");
    int matchRankNum = (int)msg.get<jsonxx::Number>("MatchRankNum");
    int matchTrys =  (int)msg.get<jsonxx::Number>("MatchTrys");
    int matchHighScore = (int)msg.get<jsonxx::Number>("MatchHighScore");
    
    if (matchRankNum > 0) {
        char buf[512];
        snprintf(buf, 512, "Rank: %d\nRankNum: %d\nTrys:%d\nHighScore:%d",
                 matchRank, matchRankNum, matchTrys, matchHighScore);
        _matchLabel->setString(buf);
    } else {
        _matchLabel->setString(lang("无记录"));
    }
    
}

void MatchLobbyLayer::enterFreePlayMode(Object *sender, Control::EventType controlEvent) {
    auto layer = MatchLayer::create(&(_matchInfo.packInfo));
    Director::getInstance()->pushScene(TransitionFade::create(0.5f, (Scene*)layer->getParent()));
}

void MatchLobbyLayer::enterMatchMode(Object *sender, Control::EventType controlEvent) {
    auto layer = MatchLayer::create(&(_matchInfo.packInfo));
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
}

void MatchLobbyLayer::onSptLoaderError(const char *localPath, void *userData) {
    lwerror("MatchLobbyLayer::onSptLoaderError");
}

