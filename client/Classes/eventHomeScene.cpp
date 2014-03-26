#include "eventHomeScene.h"
#include "eventListScene.h"
#include "jsonxx/jsonxx.h"
#include "db.h"
#include "http.h"
#include "dragView.h"
#include "util.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

static Color3B BTN_COLOR(0, 122, 255);

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
    
    setTouchEnabled(true);
    this->setTouchMode(Touch::DispatchMode::ONE_BY_ONE);
    auto visSize = Director::getInstance()->getVisibleSize();
    
    //drag view
    _dragView = DragView::create();
    addChild(_dragView);
    float dragViewHeight = visSize.height;
    _dragView->setWindowRect(Rect(0, 0, visSize.width, dragViewHeight));
    
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
    
    //event result label
    _labelEventResult = LabelTTF::create("loading event result", "HelveticaNeue", 42);
    _labelEventResult->setPosition(Point(40, visSize.height-400));
    _labelEventResult->setHorizontalAlignment(TextHAlignment::LEFT);
    _labelEventResult->setColor(Color3B::BLACK);
    _labelEventResult->setAnchorPoint(Point(0.f, 1.f));
    this->addChild(_labelEventResult);
    
    //player result label
    _labelPlayerResult = LabelTTF::create("loading player result", "HelveticaNeue", 42);
    _labelPlayerResult->setPosition(Point(40, visSize.height-600));
    _labelPlayerResult->setHorizontalAlignment(TextHAlignment::LEFT);
    _labelPlayerResult->setColor(Color3B::BLACK);
    _labelPlayerResult->setAnchorPoint(Point(0.f, 1.f));
    this->addChild(_labelPlayerResult);
    
    //play button
    button = createTextButton("HelveticaNeue", "Play", 48, BTN_COLOR);
    button->setAnchorPoint(Point(0.5f, 1.f));
    button->setPosition(Point(160, visSize.height-1000));
    button->setTitleColorForState(Color3B(255, 0, 0), Control::State::HIGH_LIGHTED);
    button->addTargetWithActionForControlEvents(this, cccontrol_selector(EventHomeLayer::play), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(button);
    
    //rounds button
    button = createTextButton("HelveticaNeue", "Rounds", 48, BTN_COLOR);
    button->setAnchorPoint(Point(.5f, 1.f));
    button->setPosition(Point(visSize.width-160, visSize.height-1000));
    button->setTitleColorForState(Color3B(255, 0, 0), Control::State::HIGH_LIGHTED);
    button->addTargetWithActionForControlEvents(this, cccontrol_selector(EventHomeLayer::rounds), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(button);
    
    //get pack info
    jsonxx::Object msg;
    msg << "Id" << _eventInfo.packId;
    postHttpRequest("pack/get", msg.json().c_str(), this, (SEL_HttpResponse)&EventHomeLayer::onHttpGetPack);
    
    //get result info
    jsonxx::Object resultMsg;
    resultMsg << "EventId" << _eventInfo.id;
    postHttpRequest("event/getResult", resultMsg.json().c_str(), this, (SEL_HttpResponse)&EventHomeLayer::onHttpGetResult);
    
    //get result info
    jsonxx::Object playerResult;
    playerResult << "EventId" << _eventInfo.id;
    postHttpRequest("event/getPlayerResult", resultMsg.json().c_str(), this, (SEL_HttpResponse)&EventHomeLayer::onHttpGetPlayerResult);
    
    return true;
}

void EventHomeLayer::back(Object *sender, Control::EventType controlEvent) {
    Director::getInstance()->popSceneWithTransition<TransitionFade>((Scene*)this->getParent(), .5f);
}

void EventHomeLayer::play(Object *sender, Control::EventType controlEvent) {
    Director::getInstance()->popSceneWithTransition<TransitionFade>((Scene*)this->getParent(), .5f);
}

void EventHomeLayer::rounds(Object *sender, Control::EventType controlEvent) {
    Director::getInstance()->popSceneWithTransition<TransitionFade>((Scene*)this->getParent(), .5f);
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
    
    EventResult result;
    result.EventId = (uint64_t)(resultObj.get<jsonxx::Number>("EventId"));
    result.CurrRound = (int)(resultObj.get<jsonxx::Number>("CurrRound"));
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
        result.Rounds.push_back(round);
    }
    
    //
    std::stringstream ss;
    ss << "CurrRound: " << result.CurrRound << "\n";
    ss << "RoundsNum: " << result.Rounds.size() << "\n";
    _labelEventResult->setString(ss.str().c_str());
}

void EventHomeLayer::onHttpGetPlayerResult(HttpClient* cli, HttpResponse* resp) {
    std::string body;
    if (!checkHttpResp(resp, body)) {
        lwerror("http error:%s", body.c_str());
        _labelPlayerResult->setString(body.c_str());
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
}


//touch
bool EventHomeLayer::onTouchBegan(Touch* touch, Event *event) {
    _dragView->onTouchesBegan(touch);
    return true;
}

void EventHomeLayer::onTouchMoved(Touch* touch, Event *event) {
    _dragView->onTouchesMoved(touch);
}

void EventHomeLayer::onTouchEnded(Touch* touch, Event *event) {
    if (!_dragView->isDragging() && _dragView->getWindowRect().containsPoint(touch->getLocation())) {
        
    }
    
    _dragView->onTouchesEnded(touch);
}

void EventHomeLayer::onTouchCancelled(Touch *touch, Event *event) {
    onTouchEnded(touch, event);
}

