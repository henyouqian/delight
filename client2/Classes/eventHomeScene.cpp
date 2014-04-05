#include "eventHomeScene.h"
#include "eventListScene.h"
#include "eventRoundLayer.h"
#include "packLoadingScene.h"
#include "jsonxx/jsonxx.h"
#include "db.h"
#include "http.h"
#include "util.h"
#include "lang.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

static Color3B BTN_COLOR(0, 122, 255);
static int ROUND_NUM = 6;

EventHomeLayer* EventHomeLayer::createWithScene(EventInfo* eventInfo) {
    auto scene = Scene::create();
    auto layer = new EventHomeLayer();
    if (layer && layer->init(eventInfo)) {
        layer->autorelease();
        scene->addChild(layer);
        return layer;
    }
    CC_SAFE_DELETE(layer);
    return nullptr;
}

bool EventHomeLayer::init(EventInfo* eventInfo) {
    if (!LayerColor::initWithColor(Color4B(255, 255, 255, 255))) {
        return false;
    }
    
    auto sz = this->getContentSize();
    
    _eventInfo = *eventInfo;
    auto visSize = Director::getInstance()->getVisibleSize();
    
    //back button
    auto button = createTextButton("HelveticaNeue", "Back", 48, BTN_COLOR);
    button->setAnchorPoint(Point(0.f, 1.f));
    button->setPosition(Point(20, visSize.height-20));
    button->setTitleColorForState(Color3B(255, 0, 0), Control::State::HIGH_LIGHTED);
    button->addTargetWithActionForControlEvents(this, cccontrol_selector(EventHomeLayer::back), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(button);
    
    //event info label
    std::stringstream ss;
    ss << "Type: " << _eventInfo.type << "\n";
    ss << "Id: " << _eventInfo.id << "\n";
    ss << "PackId: " << _eventInfo.packId << "\n";
    
    _labelEventInfo = LabelTTF::create(ss.str().c_str(), "HelveticaNeue", 42);
    _labelEventInfo->setPosition(Point(40, visSize.height-200));
    _labelEventInfo->setHorizontalAlignment(TextHAlignment::LEFT);
    _labelEventInfo->setColor(Color3B::BLACK);
    _labelEventInfo->setAnchorPoint(Point(0.f, 1.f));
    this->addChild(_labelEventInfo);
    _labelEventInfo->setVisible(false);
    
    //event result label
    _labelEventResult = LabelTTF::create("loading event result", "HelveticaNeue", 42);
    _labelEventResult->setPosition(Point(40, visSize.height-400));
    _labelEventResult->setHorizontalAlignment(TextHAlignment::LEFT);
    _labelEventResult->setColor(Color3B::BLACK);
    _labelEventResult->setAnchorPoint(Point(0.f, 1.f));
    this->addChild(_labelEventResult);
    _labelEventResult->setVisible(false);
    
    //player result label
    _labelPlayerResult = LabelTTF::create("loading player result", "HelveticaNeue", 42);
    _labelPlayerResult->setPosition(Point(40, visSize.height-600));
    _labelPlayerResult->setHorizontalAlignment(TextHAlignment::LEFT);
    _labelPlayerResult->setColor(Color3B::BLACK);
    _labelPlayerResult->setAnchorPoint(Point(0.f, 1.f));
    this->addChild(_labelPlayerResult);
    _labelPlayerResult->setVisible(false);
    
    //_labelHighScore
    float y = visSize.height-200;
    _labelHighScore = LabelTTF::create("High score", "HelveticaNeue", 42);
    _labelHighScore->setPosition(Point(40, y));
    _labelHighScore->setHorizontalAlignment(TextHAlignment::LEFT);
    _labelHighScore->setColor(Color3B::BLACK);
    _labelHighScore->setAnchorPoint(Point(0.f, 1.f));
    this->addChild(_labelHighScore);
    
    //_labelRank
    y -= 100;
    _labelRank = LabelTTF::create("Rank", "HelveticaNeue", 42);
    _labelRank->setPosition(Point(40, y));
    _labelRank->setHorizontalAlignment(TextHAlignment::LEFT);
    _labelRank->setColor(Color3B::BLACK);
    _labelRank->setAnchorPoint(Point(0.f, 1.f));
    this->addChild(_labelRank);
    
    //_labelTimeLeft
    y -= 200;
    _labelTimeLeft = LabelTTF::create("TimeLeft", "HelveticaNeue", 42);
    _labelTimeLeft->setPosition(Point(40, y));
    _labelTimeLeft->setHorizontalAlignment(TextHAlignment::LEFT);
    _labelTimeLeft->setColor(Color3B::BLACK);
    _labelTimeLeft->setAnchorPoint(Point(0.f, 1.f));
    this->addChild(_labelTimeLeft);
    
//    //_labelTeams
//    y -= 160;
//    _labelTeams = LabelTTF::create("Teams", "HelveticaNeue", 42);
//    _labelTeams->setPosition(Point(40, y));
//    _labelTeams->setHorizontalAlignment(TextHAlignment::LEFT);
//    _labelTeams->setColor(Color3B::BLACK);
//    _labelTeams->setAnchorPoint(Point(0.f, 1.f));
//    this->addChild(_labelTeams);

    
    //practice button
    button = createTextButton("HelveticaNeue", lang("Practice"), 48, BTN_COLOR);
    button->setAnchorPoint(Point(0.5f, 1.f));
    button->setPosition(Point(160, visSize.height-1000));
    button->setTitleColorForState(Color3B(255, 0, 0), Control::State::HIGH_LIGHTED);
    button->addTargetWithActionForControlEvents(this, cccontrol_selector(EventHomeLayer::practice), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(button);
    
    //match button
    button = createTextButton("HelveticaNeue", lang("Match"), 48, BTN_COLOR);
    button->setAnchorPoint(Point(.5f, 1.f));
    button->setPosition(Point(visSize.width-160, visSize.height-1000));
    button->setTitleColorForState(Color3B(255, 0, 0), Control::State::HIGH_LIGHTED);
    button->addTargetWithActionForControlEvents(this, cccontrol_selector(EventHomeLayer::play), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(button);
    
//    //round layers
//    for (auto i = 0; i < ROUND_NUM; ++i) {
//        auto roundLayer = EventRoundLayer::create(i);
//        roundLayer->setAnchorPoint(Point(0, 0));
//        roundLayer->setPosition(Point(visSize.width*(i+1), 0));
//        this->addChild(roundLayer);
//        _roundLayers.push_back(roundLayer);
//    }
    
    //get pack info
    jsonxx::Object msg;
    msg << "Id" << _eventInfo.packId;
    postHttpRequest("pack/get", msg.json().c_str(), this, (SEL_HttpResponse)&EventHomeLayer::onHttpGetPack);
    
    //get result info
    jsonxx::Object resultMsg;
    resultMsg << "EventId" << _eventInfo.id;
    postHttpRequest("event/getResult", resultMsg.json().c_str(), this, (SEL_HttpResponse)&EventHomeLayer::onHttpGetResult);
    
    //get result info
    jsonxx::Object myResult;
    myResult << "EventId" << _eventInfo.id;
    postHttpRequest("event/getMyResult", resultMsg.json().c_str(), this, (SEL_HttpResponse)&EventHomeLayer::onHttpGetMyResult);
    
    scheduleUpdate();
    
    return true;
}

EventHomeLayer::~EventHomeLayer() {
    
}

void EventHomeLayer::onEnter() {
    LayerColor::onEnter();
    
    //touch
//    _touchListener = EventListenerTouchOneByOne::create();
//    _touchListener->setSwallowTouches(true);
//    _touchListener->onTouchBegan = CC_CALLBACK_2(EventHomeLayer::onTouchBegan, this);
//    _touchListener->onTouchMoved = CC_CALLBACK_2(EventHomeLayer::onTouchMoved, this);
//    _touchListener->onTouchEnded = CC_CALLBACK_2(EventHomeLayer::onTouchEnded, this);
//    _touchListener->onTouchCancelled = CC_CALLBACK_2(EventHomeLayer::onTouchEnded, this);
//    _eventDispatcher->addEventListenerWithFixedPriority(_touchListener, 1);
}

void EventHomeLayer::onExit() {
    LayerColor::onExit();
    
//    _eventDispatcher->removeEventListener(_touchListener);
}

void EventHomeLayer::update(float delta) {
    int64_t timeLeft = _eventInfo.endTime - getNow();
    char buf[64];
    snprintf(buf, sizeof(buf), "Time left: %02lld:%02lld:%02lld", timeLeft/3600, timeLeft%3600/60, timeLeft%60);
//    std::stringstream ss;
//    
//    ss << "Time left:" << timeLeft/3600 << ":" << timeLeft%3600/60 << ":" << timeLeft%60;
    _labelTimeLeft->setString(buf);
    
}

void EventHomeLayer::back(Ref *sender, Control::EventType controlEvent) {
    Director::getInstance()->popSceneWithTransition<TransitionFade>((Scene*)this->getParent(), .5f);
}

void EventHomeLayer::practice(Ref *sender, Control::EventType controlEvent) {
    if (_packInfo.id != 0) {
        auto sliderScene = (Scene*)(SliderLayer::createWithScene(&_packInfo, &_eventInfo, nullptr)->getParent());
        if (isPackDownloaded(_packInfo)) {
            Director::getInstance()->pushScene(TransitionFade::create(0.5f, sliderScene));
        } else {
            auto loadingScene = (Scene*)(PackLoadingLayer::createWithScene(_packInfo, sliderScene)->getParent());
            Director::getInstance()->pushScene(TransitionFade::create(0.5f, loadingScene));
        }
    }
}

void EventHomeLayer::play(Ref *sender, Control::EventType controlEvent) {
    if (_packInfo.id != 0) {
        jsonxx::Object msg;
        msg << "EventId" << _eventInfo.id;
        postHttpRequest("event/playBegin", msg.json().c_str(), this, (SEL_HttpResponse)&EventHomeLayer::onHttpPlayBegin);
    }
}

void EventHomeLayer::onHttpPlayBegin(HttpClient* cli, HttpResponse* resp) {
    std::string body;
    if (!checkHttpResp(resp, body)) {
        lwerror("http error:%s", body.c_str());
        return;
    }
    
    jsonxx::Object rootObj;
    if (!rootObj.parse(body)) {
        lwerror("msgObj(body)");
        return;
    }
    
    if (!rootObj.has<jsonxx::String>("Secret")
        ||!rootObj.has<jsonxx::Number>("SecretExpire")
        ||!rootObj.has<jsonxx::Number>("HighScore")
        ||!rootObj.has<jsonxx::Number>("Trys")) {
        lwerror("msgObj key error");
        return;
    }
    
    _ticket.secret = rootObj.get<jsonxx::String>("Secret");
    _ticket.secretExpire = (int64_t)rootObj.get<jsonxx::Number>("SecretExpire");
    _ticket.highScore = (int32_t)rootObj.get<jsonxx::Number>("HighScore");
    _ticket.trys = (uint32_t)rootObj.get<jsonxx::Number>("Trys");
    
    if (_packInfo.id != 0) {
        auto sliderScene = (Scene*)(SliderLayer::createWithScene(&_packInfo, &_eventInfo, &_ticket)->getParent());
        if (isPackDownloaded(_packInfo)) {
            Director::getInstance()->pushScene(TransitionFade::create(0.5f, sliderScene));
        } else {
            auto loadingScene = (Scene*)(PackLoadingLayer::createWithScene(_packInfo, sliderScene)->getParent());
            Director::getInstance()->pushScene(TransitionFade::create(0.5f, loadingScene));
        }
    }
}

void EventHomeLayer::rounds(Ref *sender, Control::EventType controlEvent) {
    auto moveto = MoveTo::create(.2f, Point(-Director::getInstance()->getVisibleSize().width, 0));
    auto ease = EaseSineOut::create(moveto);
    this->runAction(ease);
}

void EventHomeLayer::onHttpGetPack(HttpClient* cli, HttpResponse* resp) {
    std::string body;
    if (!checkHttpResp(resp, body)) {
        lwerror("http error:%s", body.c_str());
        return;
    }
    
    jsonxx::Object packObj;
    if (!packObj.parse(body)) {
        lwerror("packObj.parse(body)");
        return;
    }
    
    _packInfo.init(packObj);
}

void EventHomeLayer::onHttpGetResult(HttpClient* cli, HttpResponse* resp) {
    std::string body;
    if (!checkHttpResp(resp, body)) {
        lwerror("http error:%s", body.c_str());
        return;
    }
    
    //lwinfo("%s", body.c_str());
    jsonxx::Object resultObj;
    auto ok = resultObj.parse(body.c_str());
    if (!ok) {
        lwerror("resultObj.parse error");
        return;
    }
    
    if (!resultObj.has<jsonxx::Number>("EventId")
        ||!resultObj.has<jsonxx::Number>("CurrRound")
        ||!resultObj.has<jsonxx::Array>("Rounds")) {
        lwerror("resultObj key error");
        return;
    }
    
    _result.EventId = (uint64_t)(resultObj.get<jsonxx::Number>("EventId"));
    _result.CurrRound = (int)(resultObj.get<jsonxx::Number>("CurrRound"));
    auto roundsArray = resultObj.get<jsonxx::Array>("Rounds");
    for (auto i = 0; i < roundsArray.size(); ++i) {
        auto roundObj = roundsArray.get<jsonxx::Object>(i);
        if (roundObj.has<jsonxx::Null>("Games")) {
            continue;
        }
        auto gamesArray = roundObj.get<jsonxx::Array>("Games");
        std::vector<Game> games;
        for (auto i = 0; i < gamesArray.size(); ++i) {
            auto gameObj = gamesArray.get<jsonxx::Object>(i);
            auto teamsArray = gameObj.get<jsonxx::Array>("Teams");
            std::vector<Team> teams;
            for (auto i = 0; i < teamsArray.size(); ++i) {
                auto teamObj = teamsArray.get<jsonxx::Object>(i);
                Team team;
                team.Id = (uint32_t)(teamObj.get<jsonxx::Number>("Id"));
                team.Score = (int32_t)(teamObj.get<jsonxx::Number>("Score"));
                teams.push_back(team);
            }
            Game game;
            game.Teams = teams;
            games.push_back(game);
        }
        Round round;
        round.Games = games;
        _result.Rounds.push_back(round);
        
        if (i < _roundLayers.size()) {
            _roundLayers[i]->setRound(&round);
        }
    }
    
    //
    std::stringstream ss;
    ss << "CurrRound: " << _result.CurrRound << "\n";
    ss << "RoundsNum: " << _result.Rounds.size() << "\n";
    _labelEventResult->setString(ss.str().c_str());
}

void EventHomeLayer::onHttpGetMyResult(HttpClient* cli, HttpResponse* resp) {
    std::string body;
    if (!checkHttpResp(resp, body)) {
        lwerror("http error:%s", body.c_str());
        jsonxx::Object errObj;
        auto ok = errObj.parse(body);
        if (!ok) {
            lwerror("resultObj.parse error");
            return;
        }
        auto err = errObj.get<jsonxx::String>("Error");
        if (err.compare("err_not_played") == 0) {
            _labelHighScore->setString("--");
            _labelRank->setString("--");
        }
        return;
    }
    
    //lwinfo("%s", body.c_str());
    jsonxx::Object playerResultObj;
    auto ok = playerResultObj.parse(body.c_str());
    if (!ok) {
        lwerror("resultObj.parse error");
        return;
    }
    
    if (!playerResultObj.has<jsonxx::Number>("HighScore")
        ||!playerResultObj.has<jsonxx::Number>("TeamId")
        ||!playerResultObj.has<jsonxx::Number>("Trys")
        ||!playerResultObj.has<jsonxx::Number>("Rank")
        ||!playerResultObj.has<jsonxx::Number>("RankNum")
        ||!playerResultObj.has<jsonxx::Number>("TeamRank")
        ||!playerResultObj.has<jsonxx::Number>("TeamRankNum")) {
        lwerror("playerResultObj key error");
        return;
    }
    
    PlayerResult result;
    result.HighScore = (int32_t)(playerResultObj.get<jsonxx::Number>("HighScore"));
    result.TeamId = (uint32_t)(playerResultObj.get<jsonxx::Number>("TeamId"));
    result.Trys = (uint32_t)(playerResultObj.get<jsonxx::Number>("Trys"));
    result.Rank = (uint32_t)(playerResultObj.get<jsonxx::Number>("Rank"));
    result.RankNum = (uint32_t)(playerResultObj.get<jsonxx::Number>("RankNum"));
    result.TeamRank = (uint32_t)(playerResultObj.get<jsonxx::Number>("TeamRank"));
    result.TeamRankNum = (uint32_t)(playerResultObj.get<jsonxx::Number>("TeamRankNum"));
    
    //
    std::stringstream ss;
    ss << "HighScore: " << result.HighScore << "\n";
    ss << "TeamId: " << result.TeamId << "\n";
    ss << "Trys: " << result.Trys << "\n";
    ss << "Rank: " << result.Rank << "\n";
    ss << "RankNum: " << result.RankNum << "\n";
    ss << "TeamRank: " << result.TeamRank << "\n";
    ss << "TeamRankNum: " << result.TeamRankNum << "\n";
    _labelPlayerResult->setString(ss.str().c_str());
    
    //highscore
    const int BUF_SZ = 256;
    char buf[BUF_SZ];
    auto score = -result.HighScore;
    snprintf(buf, BUF_SZ, "HighScore:%02d:%02d.%03d",
             score/60000,
             score%60000/1000,
             score%1000);
    _labelHighScore->setString(buf);
    
    //rank
    float beatRate = 0.f;
    float beatRateTeam = 0.f;
    if (result.RankNum > 1) {
        beatRate = (float)(result.RankNum - result.Rank)/(float)(result.RankNum-1)*100.f;
    }
    if (result.TeamRankNum > 1) {
        beatRateTeam = (float)(result.TeamRankNum - result.TeamRank)/(float)(result.TeamRankNum-1)*100.f;
    }
    
    snprintf(buf, BUF_SZ, "全国排名:%d, 击败了%.1f%%\n全省排名:%d, 击败了%.1f%%", result.Rank, beatRate, result.TeamRank, beatRateTeam);
    _labelRank->setString(buf);
    
    
//    //team vs match
//    auto playerInfo = getPlayerInfo();
//    if (_result.CurrRound < _result.Rounds.size()) {
//        auto currRound = _result.Rounds[_result.CurrRound];
//        std::vector<Team>* teams = nullptr;
//        for (auto itGame = currRound.Games.begin(); itGame != currRound.Games.end(); ++itGame) {
//            for (auto itTeam = itGame->Teams.begin(); itTeam != itGame->Teams.end(); ++itTeam) {
//                if (itTeam->Id == playerInfo.teamId) {
//                    teams = &(itGame->Teams);
//                    break;
//                }
//            }
//        }
//        if (teams) {
//            std::stringstream ss;
//            for (auto it = teams->begin(); it != teams->end(); ++it) {
//                ss << getTeamName(it->Id) << "  ";
//            }
//            _labelTeams->setString(ss.str().c_str());
//        } else {
//            _labelTeams->setString("已淘汰");
//        }
//    }
}

bool EventHomeLayer::onTouchBegan(Touch *touch, Event *event) {
    _isDragging = false;
    return true;
}

void EventHomeLayer::onTouchMoved(Touch *touch, Event *event) {
    if (!_isDragging) {
        auto dx = fabs(touch->getStartLocation().x - touch->getLocation().x);
        if (dx > 10) {
            _isDragging = true;
            for (auto it = _roundLayers.begin(); it != _roundLayers.end(); ++it) {
                (*it)->cancelButton();
            }
        }
    }
    auto visSize = Director::getInstance()->getVisibleSize();
    auto pos = this->getPosition();
    auto d = touch->getDelta();
    auto toX = pos.x+d.x;
    float maxDist = 300.f;
    if (pos.x > 0) {
        float dt = pos.x;
        if (dt < maxDist) {
            toX = pos.x + d.x * (cos((dt/maxDist)*M_PI_2+M_PI_2)+1.f);
        }
    } else if (pos.x < -visSize.width*ROUND_NUM) {
        float dt = -visSize.width*ROUND_NUM-pos.x;
        if (dt < maxDist) {
            toX = pos.x + d.x * (cos((dt/maxDist)*M_PI_2+M_PI_2)+1.f);
        }
    }
    
    this->setPosition(toX, pos.y);
}

void EventHomeLayer::onTouchEnded(Touch *touch, Event *event) {
    if (!_isDragging) {
        return;
    }
    auto visSize = Director::getInstance()->getVisibleSize();
    _isDragging = false;
    auto dx = touch->getDelta().x;
    auto posX = -this->getPosition().x;
    float idx = floor(posX/visSize.width);
    float toX = -idx * visSize.width;
    if (dx < 0) {
        toX = -(idx+1) * visSize.width;
    }
    toX = MAX(-visSize.width*ROUND_NUM, MIN(0.f, toX));
    auto moveto = MoveTo::create(.2f, Point(toX, 0));
    auto ease = EaseSineOut::create(moveto);
    this->runAction(ease);
}



