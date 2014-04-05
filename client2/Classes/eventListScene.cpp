#include "eventListScene.h"
#include "eventHomeScene.h"
//#include "packLoadingScene.h"
#include "loginScene.h"
#include "jsonxx/jsonxx.h"
#include "db.h"
#include "http.h"
#include "dragView.h"
#include "util.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

static const float HEADER_HEIGHT = 130.f;
static const float THUMB_MARGIN = 10.f;
static const float MENUBAR_HEIGHT = 100.f;

EventListLayer* EventListLayer::createWithScene() {
    auto scene = Scene::create();
    auto layer = new EventListLayer();
    if (layer && layer->init()) {
        layer->autorelease();
        scene->addChild(layer);
        return layer;
    }
    CC_SAFE_DELETE(layer);
    return nullptr;
}

bool EventListLayer::init() {
    if (!Layer::init()) {
        return false;
    }
    
    auto visSize = Director::getInstance()->getVisibleSize();
    
    //header
    auto headerBg = Sprite::create("ui/pt.png");
    headerBg->setScaleX(visSize.width);
    headerBg->setScaleY(HEADER_HEIGHT);
    headerBg->setAnchorPoint(Point(0.f, 1.f));
    headerBg->setPosition(Point(0.f, visSize.height));
    headerBg->setColor(Color3B(255, 255, 27));
    addChild(headerBg, 10);
    
    //login button
    auto button = createTextButton("HelveticaNeue", "Login", 48, Color3B::WHITE);
    button->setAnchorPoint(Point(0.f, 1.f));
    button->setPosition(Point(20, visSize.height-20));
    button->setTitleColorForState(Color3B(255, 0, 0), Control::State::HIGH_LIGHTED);
    button->addTargetWithActionForControlEvents(this, cccontrol_selector(EventListLayer::gotoLogin), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(button, 10);
    
    //
    auto title = LabelTTF::create("aaaaaaaaaaaaaaa\naaaaaaaaaaaaaaa\naaaaaaaaaaaaaaa\naaaaaaaaaaaaaaa\naaaaaaaaaaaaaaa\naaaaaaaaaaaaaaa\naaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\nnaaaaaaaaaaaaaaa\n", "HelveticaNenu", 40);
    title->setAnchorPoint(Point(0.f, 1.f));
    title->setPosition(30, 0);
    title->setHorizontalAlignment(TextHAlignment::LEFT);
    title->setColor(Color3B::WHITE);
    headerBg->addChild(title);
    
    
    _listY = -100.f;
    
    //drag view
    _dragView = DragView::create();
    addChild(_dragView);
    float dragViewHeight = visSize.height-HEADER_HEIGHT;
    _dragView->setWindowRect(Rect(0, 0, visSize.width, dragViewHeight));
    
    //get match pack list
    jsonxx::Object msg;
    msg << "StartId" << 0;
    msg << "Limit" << 20;
    
    postHttpRequest("event/list", msg.json().c_str(), this, (SEL_HttpResponse)(&EventListLayer::onHttpListEvent));
    
    return true;
}

EventListLayer::~EventListLayer() {
    for (auto it = _eventInfos.begin(); it != _eventInfos.end(); ++it) {
        delete *it;
    }
}

void EventListLayer::gotoLogin(Ref *sender, Control::EventType controlEvent) {
    Director::getInstance()->replaceScene(TransitionFade::create(0.5f, (Scene*)LoginLayer::createWithScene()->getParent()));
}

void EventListLayer::onHttpListEvent(HttpClient* client, HttpResponse* resp) {
    jsonxx::Array msg;
    std::string body;
    if (!checkHttpResp(resp, body)) {
        lwerror("MatchListLayer::onHttpListMatch http error:%s", body.c_str());
        return;
    } else {
        //parse response
        bool ok = msg.parse(body);
        if (!ok) {
            lwerror("json parse error");
            return;
        }
    }
    
    auto visSize = Director::getInstance()->getVisibleSize();
    for (auto i = 0; i < msg.size(); ++i) {
        auto eventObj = msg.get<jsonxx::Object>(i);
        if (!eventObj.has<jsonxx::String>("Type")
            || !eventObj.has<jsonxx::Number>("Id")
            || !eventObj.has<jsonxx::Number>("PackId")
            || !eventObj.has<jsonxx::Number>("BeginTime")
            || !eventObj.has<jsonxx::Number>("EndTime")
            || !eventObj.has<jsonxx::Boolean>("IsFinished")) {
            lwerror("json invalid, need Type, Id, PackId, BeginTime, EndTime, IsFinished: %s", eventObj.json().c_str());
            return;
        }
        
        EventInfo *eventInfo = new EventInfo;
        auto type = eventObj.get<jsonxx::String>("Type");
        if (type.compare("PERSONAL_RANK") == 0) {
            eventInfo->type = EventInfo::PERSONAL_RANK;
        } else if (type.compare("TEAM_CHAMPIONSHIP") == 0) {
            eventInfo->type = EventInfo::TEAM_CHAMPIONSHIP;
        } else {
            lwerror("invalid event type:%s", type.c_str());
            return;
        }
        eventInfo->id = (uint64_t)eventObj.get<jsonxx::Number>("Id");
        eventInfo->packId = (uint64_t)eventObj.get<jsonxx::Number>("PackId");
        eventInfo->beginTime = (int64_t)eventObj.get<jsonxx::Number>("BeginTime");
        eventInfo->endTime = (int64_t)eventObj.get<jsonxx::Number>("EndTime");
        eventInfo->isFinished = eventObj.get<jsonxx::Boolean>("IsFinished");
        
        _eventInfos.push_back(eventInfo);
        
        std::stringstream ss;
        ss << "event" << eventInfo->id;
        auto button = createTextButton("HelveticaNeue", ss.str().c_str(), 48, Color3B::WHITE);
        button->setPosition(Point(visSize.width*.5f, _listY));
        button->setTitleColorForState(Color3B(255, 0, 0), Control::State::HIGH_LIGHTED);
        button->setUserData((void*)eventInfo);
        button->addTargetWithActionForControlEvents(this, cccontrol_selector(EventListLayer::enterEvent), Control::EventType::TOUCH_UP_INSIDE);
        _dragView->addChild(button);
        _listY -= 120;
    }
    
    _dragView->setContentHeight(-_listY);
}

void EventListLayer::enterEvent(Ref *sender, Control::EventType controlEvent) {
    auto eventInfo = (EventInfo*)(((Node*)sender)->getUserData());
    
    Director::getInstance()->pushScene(TransitionFade::create(0.5f, (Scene*)EventHomeLayer::createWithScene(eventInfo)->getParent()));
    
//    char key[64];
//    snprintf(key, 64, "packs/%llu", eventInfo->packId);
//    std::string v;
//    auto exist = getKv(key, v);
//    if (exist) {
//        Director::getInstance()->pushScene(TransitionFade::create(0.5f, (Scene*)EventHomeLayer::createWithScene(eventInfo)->getParent()));
//    } else {
//        auto eventHomeScene = (Scene*)EventHomeLayer::createWithScene(eventInfo)->getParent();
//        auto loadingLayer = PackLoadingLayer::createWithScene(eventInfo->packId, eventHomeScene);
//        Director::getInstance()->pushScene(TransitionFade::create(0.5f, (Scene*)(loadingLayer->getParent())));
//    }
}
