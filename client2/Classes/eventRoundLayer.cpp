#include "eventRoundLayer.h"
#include "jsonxx/jsonxx.h"
#include "db.h"
#include "http.h"
#include "util.h"
#include "lang.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

static Color3B BTN_COLOR(0, 122, 255);

EventRoundLayer* EventRoundLayer::create(uint32_t idx) {
    auto layer = new EventRoundLayer();
    if (layer && layer->init(idx)) {
        layer->autorelease();
        return layer;
    }
    CC_SAFE_DELETE(layer);
    return nullptr;
}

bool EventRoundLayer::init(uint32_t idx) {
    if (!LayerColor::initWithColor(Color4B(255, 255, 55, 255))) {
        return false;
    }
    
    _idx = idx;
    _activeButton = nullptr;
    
    auto visSize = Director::getInstance()->getVisibleSize();
    
    //title
    char buf[64];
    snprintf(buf, 64, "round%dTitle", idx);
    
    auto title = LabelTTF::create(lang(buf), "HelveticaNenu", 40);
    title->setAnchorPoint(Point(0.f, 1.f));
    title->setPosition(30, visSize.height - 30);
    title->setHorizontalAlignment(TextHAlignment::LEFT);
    title->setColor(Color3B::BLACK);
    this->addChild(title);
    
//    //prev button
//    auto button = createTextButton("HelveticaNeue", "Prev", 48, BTN_COLOR);
//    button->setAnchorPoint(Point(.5f, 1.f));
//    button->setPosition(Point(120, visSize.height-1000));
//    button->setTitleColorForState(Color3B(255, 0, 0), Control::State::HIGH_LIGHTED);
//    button->addTargetWithActionForControlEvents(this, cccontrol_selector(EventRoundLayer::touchDown), Control::EventType::TOUCH_DOWN);
//    button->addTargetWithActionForControlEvents(this, cccontrol_selector(EventRoundLayer::prev), Control::EventType::TOUCH_UP_INSIDE);
//    this->addChild(button);
//    
//    //next button
//    if (idx < 5) {
//        button = createTextButton("HelveticaNeue", "Next", 48, BTN_COLOR);
//        button->setAnchorPoint(Point(.5f, 1.f));
//        button->setPosition(Point(visSize.width-120, visSize.height-1000));
//        button->setTitleColorForState(Color3B(255, 0, 0), Control::State::HIGH_LIGHTED);
//        button->addTargetWithActionForControlEvents(this, cccontrol_selector(EventRoundLayer::touchDown), Control::EventType::TOUCH_DOWN);
//        button->addTargetWithActionForControlEvents(this, cccontrol_selector(EventRoundLayer::next), Control::EventType::TOUCH_UP_INSIDE);
//        this->addChild(button);
//    }
    
    //round group
    _roundGroup = Node::create();
    this->addChild(_roundGroup);
    
    return true;
}

void EventRoundLayer::setRound(Round* round) {
    _round = *round;
    _roundGroup->removeAllChildren();
    auto visSize = Director::getInstance()->getVisibleSize();
    float y = visSize.height - 150.f;
    for (auto itGame = _round.Games.begin(); itGame != _round.Games.end(); ++itGame) {
        std::stringstream ss;
        for (auto itTeam = itGame->Teams.begin(); itTeam != itGame->Teams.end(); ++itTeam) {
            ss << getTeamName(itTeam->Id) << ":" << itTeam->Score << "| ";
        }
        auto button = createTextButton("HelveticaNeue", ss.str().c_str(), 36, BTN_COLOR);
        button->setAnchorPoint(Point(.0f, 1.f));
        button->setPosition(Point(20, y));
        button->setTitleColorForState(Color3B(255, 0, 0), Control::State::HIGH_LIGHTED);
        button->addTargetWithActionForControlEvents(this, cccontrol_selector(EventRoundLayer::touchDown), Control::EventType::TOUCH_DOWN);
        button->addTargetWithActionForControlEvents(this, cccontrol_selector(EventRoundLayer::gameDetail), Control::EventType::TOUCH_UP_INSIDE);
        button->setUserData(&(*itGame));
        _roundGroup->addChild(button);
        y -= 100;
    }
}

void EventRoundLayer::cancelButton() {
    if (_activeButton) {
        _activeButton->onTouchCancelled(nullptr, nullptr);
        _activeButton = nullptr;
    }
}

void EventRoundLayer::touchDown(Ref *sender, Control::EventType controlEvent) {
    _activeButton = (ControlButton*)sender;
}

void EventRoundLayer::gameDetail(Ref *sender, Control::EventType controlEvent) {
    auto game = (Game*)(((Node*)sender)->getUserData());
    
    lwinfo("game: teams=%lu", game->Teams.size());
}

void EventRoundLayer::prev(Ref *sender, Control::EventType controlEvent) {
    auto visSize = Director::getInstance()->getVisibleSize();
    auto moveto = MoveTo::create(.2f, Point(-(float)_idx*visSize.width, 0.f));
    auto ease = EaseSineOut::create(moveto);
    getParent()->runAction(ease);
}

void EventRoundLayer::next(Ref *sender, Control::EventType controlEvent) {
    auto visSize = Director::getInstance()->getVisibleSize();
    lwinfo("%f", (-_idx-2.f)*visSize.width);
    auto moveto = MoveTo::create(.2f, Point((-(float)_idx-2.f)*visSize.width, 0.f));
    auto ease = EaseSineOut::create(moveto);
    getParent()->runAction(ease);
}
