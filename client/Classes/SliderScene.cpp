#include "SliderScene.h"
#include "gifTexture.h"
#include "util.h"
#include "lang.h"
#include "db.h"
#include "lw/lwLog.h"
#include "SimpleAudioEngine.h"
#include <sys/stat.h>

USING_NS_CC;
USING_NS_CC_EXT;

using namespace CocosDenshion;

static const GLubyte BTN_BG_OPACITY = 160;
static const float BTN_EASE_DUR = .2f;
static const GLubyte TRANS_DOT_OPACITY = 80;

static const Color3B GREEN = Color3B(76, 217, 100);
static const Color3B YELLOW = Color3B(255, 204, 0);
static const Color3B RED = Color3B(255, 59, 48);

static const char *SND_STAR = "audio/star.aiff";

static const int SLIDER_NUM = 6;

TimeBar* TimeBar::create(float dur1, float dur2, float dur3) {
    auto timeBar = new TimeBar();
    if (timeBar->init(dur1, dur2, dur3)) {
        timeBar->autorelease();
        return timeBar;
    } else {
        delete timeBar;
        return nullptr;
    }
}

bool TimeBar::init(float dur1, float dur2, float dur3) {
    if (!SpriteBatchNode::initWithFile("ui/pt.png", 16)) {
        return false;
    }
    _dur1 = dur1;
    _dur2 = dur2;
    _dur3 = dur3;
    
    auto size = Director::getInstance()->getVisibleSize();
    
    //spr
    _durSum = dur1 + dur2 + dur3;
    float x = 0;
    float y = size.height;
    float w = dur1/_durSum * size.width;
    float h = 5.f;
    GLubyte opacity = 60;
    auto spr = Sprite::create("ui/pt.png");
    spr->setAnchorPoint(Point(0.f, 1.f));
    spr->setScaleX(w);
    spr->setScaleY(h);
    spr->setPosition(Point(x, y));
    spr->setColor(GREEN);
    spr->setOpacity(opacity);
    this->addChild(spr);
    
    x += w;
    w = dur2/_durSum * size.width;
    spr = Sprite::create("ui/pt.png");
    spr->setAnchorPoint(Point(0.f, 1.f));
    spr->setScaleX(w);
    spr->setScaleY(h);
    spr->setPosition(Point(x, y));
    spr->setColor(YELLOW);
    spr->setOpacity(opacity);
    this->addChild(spr);
    
    x += w;
    w = dur3/_durSum * size.width;
    spr = Sprite::create("ui/pt.png");
    spr->setAnchorPoint(Point(0.f, 1.f));
    spr->setScaleX(w);
    spr->setScaleY(h);
    spr->setPosition(Point(x, y));
    spr->setColor(RED);
    spr->setOpacity(opacity);
    this->addChild(spr);
    
    _bar = Sprite::create("ui/pt.png");
    _bar->setAnchorPoint(Point(0.f, 1.f));
    _bar->setScaleX(0);
    _bar->setScaleY(h);
    _bar->setPosition(Point(0, y));
    _bar->setColor(GREEN);
    this->addChild(_bar);
    _colorIdx = 0;
    
    return true;
}

void TimeBar::run() {
    scheduleUpdate();
    _startTimePoint = std::chrono::system_clock::now();
}

void TimeBar::stop() {
    unscheduleUpdate();
}

int TimeBar::getStarNum() {
    auto now = std::chrono::system_clock::now();
    auto dur = now - _startTimePoint;
    std::chrono::milliseconds ms = std::chrono::duration_cast<std::chrono::milliseconds> (dur);
    float t = ms.count()*.001f;
    
    if (t <= _dur1) {
        return 3;
    } else if (t <= _dur1+_dur2) {
        return 2;
    } else if (t <= _dur1+_dur2+_dur3) {
        return 1;
    } else {
        return 0;
    }
}

void TimeBar::update(float dt) {
    auto now = std::chrono::system_clock::now();
    auto dur = now - _startTimePoint;
    std::chrono::milliseconds ms = std::chrono::duration_cast<std::chrono::milliseconds> (dur);
    float t = ms.count()*.001f;
    auto size = Director::getInstance()->getVisibleSize();
    float scaleX = MIN(t/_durSum*size.width, size.width);
    _bar->setScaleX(scaleX);
    
    int colorIdx = 0;
    auto color = GREEN;
    if (t >= _dur1 + _dur2) {
        colorIdx = 2;
        color = RED;
    } else if ( t >= _dur1) {
        colorIdx = 1;
        color = YELLOW;
    }
    
    if (colorIdx != _colorIdx) {
        _colorIdx = colorIdx;
        
        auto tintTo = TintTo::create(.3f, color.r, color.g, color.b);
        _bar->runAction(tintTo);
    }
}

static void btnFadeOut(ControlButton *button) {
    auto fadeout = FadeOut::create(BTN_EASE_DUR);
    auto easeFadeout = EaseSineOut::create(fadeout);
    button->runAction(easeFadeout);
    button->setEnabled(false);
    
    auto label = (LabelTTF*)button->getTitleLabelForState(Control::State::NORMAL);
    label->runAction(easeFadeout->clone());
}

static void btnFadeIn(ControlButton *button) {
    auto fadeto = FadeTo::create(BTN_EASE_DUR, BTN_BG_OPACITY);
    auto easeFadeto = EaseSineOut::create(fadeto);
    button->runAction(easeFadeto);
    button->setEnabled(true);
    
    auto fadein = FadeIn::create(BTN_EASE_DUR);
    auto easeFadein = EaseSineOut::create(fadein);
    auto label = (LabelTTF*)button->getTitleLabelForState(Control::State::NORMAL);
    label->runAction(easeFadein);
}

Scene* SliderScene::createScene(PackInfo *packInfo) {
    auto scene = Scene::create();
    auto layer = SliderScene::create(packInfo);
    scene->addChild(layer);
    return scene;
}

SliderScene* SliderScene::create(PackInfo *packInfo) {
    SliderScene *pRet = new SliderScene();
    if (pRet && pRet->init(packInfo)) {
        pRet->autorelease();
        return pRet;
    }
    else {
        delete pRet;
        return NULL;
    }
}

bool SliderScene::init(PackInfo *packInfo) {
    _packInfo = packInfo;
    auto t = time(nullptr);
    srand(t);
    if (!Layer::init()) {
        return false;
    }
    this->setTouchEnabled(true);
    auto visSize = Director::getInstance()->getVisibleSize();
    
    _isFinish = false;
    _imgIdx = 0;
    
    auto size = Director::getInstance()->getVisibleSize();
    
    _gameplay = new Gameplay(this);
    addChild(_gameplay);

    //next button
    _btnNext = createColorButton(lang("Next"), 36, 1.f, Color3B::WHITE, GREEN, BTN_BG_OPACITY);
    _btnNext->setPosition(Point(size.width-70, 70));
    _btnNext->addTargetWithActionForControlEvents(this, cccontrol_selector(SliderScene::next), Control::EventType::TOUCH_UP_INSIDE);
    _btnNext->setOpacity(0);
    auto label = (LabelTTF*)_btnNext->getTitleLabelForState(Control::State::NORMAL);
    label->setOpacity(0);
    this->addChild(_btnNext, 10);
    
    //back button
    _btnBack = createButton(lang("Back"), 36, 1.f);
    _btnBack->setPosition(Point(70, 70));
    _btnBack->addTargetWithActionForControlEvents(this, cccontrol_selector(SliderScene::ShowBackConfirm), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(_btnBack, 10);
    
    //yes button
    _btnYes = createColorButton(lang("Yes"), 36, 1.f, Color3B::WHITE, Color3B(255, 59, 48), BTN_BG_OPACITY);
    _btnYes->setPosition(Point(70, 70));
    _btnYes->addTargetWithActionForControlEvents(this, cccontrol_selector(SliderScene::back), Control::EventType::TOUCH_UP_INSIDE);
    _btnYes->setOpacity(0);
    label = (LabelTTF*)_btnYes->getTitleLabelForState(Control::State::NORMAL);
    label->setOpacity(0);
    _btnYes->setEnabled(false);
    this->addChild(_btnYes, 10);
    
    //no button
    _btnNo = createButton(lang("No"), 36, 1.f);
    _btnNo->setPosition(Point(70, 70));
    _btnNo->addTargetWithActionForControlEvents(this, cccontrol_selector(SliderScene::HideBackConfirm), Control::EventType::TOUCH_UP_INSIDE);
    _btnNo->setOpacity(0);
    label = (LabelTTF*)_btnNo->getTitleLabelForState(Control::State::NORMAL);
    label->setOpacity(0);
    _btnNo->setEnabled(false);
    this->addChild(_btnNo, 10);
    
    //finish button
    _btnFinish = createColorButton(lang("Back"), 36, 1.f, Color3B::WHITE, RED, BTN_BG_OPACITY);
    _btnFinish->setPosition(Point(70, 70));
    _btnFinish->addTargetWithActionForControlEvents(this, cccontrol_selector(SliderScene::back), Control::EventType::TOUCH_UP_INSIDE);
    _btnFinish->setOpacity(0);
    _btnFinish->setEnabled(false);
    label = (LabelTTF*)_btnFinish->getTitleLabelForState(Control::State::NORMAL);
    label->setOpacity(0);
    this->addChild(_btnFinish, 10);
    
    //next pack button
    _btnNextPack = createColorButton(lang("Next"), 36, 1.f, Color3B::WHITE, GREEN, BTN_BG_OPACITY);
    _btnNextPack->setPosition(Point(visSize.width-70, 70));
    _btnNextPack->addTargetWithActionForControlEvents(this, cccontrol_selector(SliderScene::back), Control::EventType::TOUCH_UP_INSIDE);
    _btnNextPack->setOpacity(0);
    _btnNextPack->setEnabled(false);
    label = (LabelTTF*)_btnNextPack->getTitleLabelForState(Control::State::NORMAL);
    label->setOpacity(0);
    this->addChild(_btnNextPack, 10);
    
    //dots
    _dotBatch = SpriteBatchNode::create("ui/dot24.png");
    this->addChild(_dotBatch, 10);
    auto imgNum = _packInfo->images.size();
    //float dx = 20.f;
    float dx = (size.width - 20.f) / (imgNum);
    float x = (size.width - (imgNum-1)*dx) * .5f;
    float y = size.height-20.f;
    for (auto i = 0; i < imgNum; ++i) {
        auto dot = Sprite::create("ui/dot24.png");
        dot->setPosition(Point(x, y));
        dot->setOpacity(TRANS_DOT_OPACITY);
        _dotBatch->addChild(dot);
        x += dx;
    }
    
    //timeBar
    //_timeBar = TimeBar::create(60, 10, 10);
    _timeBar = TimeBar::create(10, 3, 3);
    this->addChild(_timeBar, 1);
    
    //shuffle image order
    _packInfo->shuffleImageIndices();
    
    //stars
    _starLabel = LabelTTF::create("★★★", "HelveticaNeue", 72);
    _starLabel->setPosition(Point(visSize.width*.5f, visSize.height*.7f));
    _starLabel->setColor(Color3B(255, 229, 153));
    _starLabel->enableShadow(Size(3, -3), .5f, 1.f);
    _starLabel->setScaleY(0.f);
    this->addChild(_starLabel, 10);
    
    //SimpleAudioEngine::getInstance()->preloadEffect(SND_STAR);
    
    //grade label
    _gradeLabel = LabelTTF::create("Great", "HelveticaNeue", 96);
    _gradeLabel->setPosition(Point(visSize.width*.5f, visSize.height*.7f));
    _gradeLabel->setColor(Color3B(255, 229, 153));
    _gradeLabel->setOpacity(0);
    _gradeLabel->enableShadow(Size(3, -3), .5f, 1.f);
    _gradeLabel->setScale(3.f);
    this->addChild(_gradeLabel, 10);
    
    //reset
    reset(0);
    
    return true;
}

SliderScene::~SliderScene() {
    if (_gameplay) {
        delete _gameplay;
    }
}

void SliderScene::onReset(float rotate) {
    auto rot = RotateTo::create(.3f, rotate);
    auto ease = EaseSineInOut::create(rot);
    _btnNext->runAction(ease->clone());
    _btnBack->runAction(ease->clone());
    _btnYes->runAction(ease->clone());
    _btnNo->runAction(ease->clone());
    _btnFinish->runAction(ease->clone());
    _btnNextPack->runAction(ease->clone());
    
    if (_imgIdx == 0) {
        _timeBar->run();
    }
}

void SliderScene::ShowBackConfirm(Object *sender, Control::EventType controlEvent) {
    //yes button
    auto fadeto = FadeTo::create(BTN_EASE_DUR, BTN_BG_OPACITY);
    auto easeFadeto = EaseSineOut::create(fadeto);
    auto moveTo = MoveTo::create(BTN_EASE_DUR, Point(170.f, 70.f));
    auto easeMoveTo = EaseSineOut::create(moveTo);
    auto spawn = Spawn::create(easeFadeto, easeMoveTo, NULL);
    _btnYes->setVisible(true);
    _btnYes->setEnabled(true);
    _btnYes->setOpacity(0);
    _btnYes->runAction(spawn);
    
    auto label = (LabelTTF*)_btnYes->getTitleLabelForState(Control::State::NORMAL);
    auto fadein = FadeIn::create(BTN_EASE_DUR);
    auto easeFadein = EaseSineOut::create(fadein);
    label->setOpacity(0);
    label->runAction(easeFadein);
    
    //no button
    btnFadeIn(_btnNo);

    //back button
    btnFadeOut(_btnBack);
}

void SliderScene::HideBackConfirm(Object *sender, Control::EventType controlEvent) {
    //yes button
    auto fadeTo = FadeTo::create(BTN_EASE_DUR, 0);
    auto easeFadeout = EaseSineOut::create(fadeTo);
    auto moveTo = MoveTo::create(BTN_EASE_DUR, Point(70.f, 70.f));
    auto easeMoveTo = EaseSineOut::create(moveTo);
    auto spawn = Spawn::create(easeFadeout, easeMoveTo, NULL);
    
    _btnYes->setEnabled(false);
    _btnYes->runAction(spawn);
    
    auto label = (LabelTTF*)_btnYes->getTitleLabelForState(Control::State::NORMAL);
    label->runAction(easeFadeout->clone());
    
    //no button
    _btnNo->setEnabled(false);
    _btnNo->setOpacity(0);
    _btnNo->runAction(easeFadeout->clone());
    
    label = (LabelTTF*)_btnNo->getTitleLabelForState(Control::State::NORMAL);
    label->runAction(easeFadeout->clone());
    
    //back button
    auto fadeto = FadeTo::create(BTN_EASE_DUR, BTN_BG_OPACITY);
    auto easeFadeto = EaseSineOut::create(fadeto);
    _btnBack->runAction(easeFadeto);
    _btnBack->setEnabled(true);
    
    auto fadeIn = FadeIn::create(BTN_EASE_DUR);
    auto easeFadeIn = EaseSineOut::create(fadeIn);
    label = (LabelTTF*)_btnBack->getTitleLabelForState(Control::State::NORMAL);
    label->runAction(easeFadeIn);
}

void SliderScene::back(Object *sender, Control::EventType controlEvent) {
    Director::getInstance()->popSceneWithTransition<TransitionFade>((Scene*)this->getParent(), .5f);
}

void SliderScene::next(Object *sender, Control::EventType controlEvent) {
    int imgIdx = _imgIdx + 1;
    if (imgIdx == _packInfo->images.size()) {
        imgIdx = 0;
    }
    reset(imgIdx);
}

void SliderScene::onTouchesBegan(const std::vector<Touch*>& touches, Event *event) {
    _gameplay->onTouchesBegan(touches);
    if (_btnYes->getOpacity() != 0) {
        HideBackConfirm(nullptr, Control::EventType::TOUCH_DOWN);
    }
    if (!_isFinish && _gameplay->isCompleted()) {
        next(nullptr, Control::EventType::TOUCH_DOWN);
    }
}

void SliderScene::onTouchesMoved(const std::vector<Touch*>& touches, Event *event) {
    _gameplay->onTouchesMoved(touches);
}

void SliderScene::onTouchesEnded(const std::vector<Touch*>& touches, Event *event) {
    auto isComp = _gameplay->isCompleted();
    _gameplay->onTouchesEnded(touches);
    if (!isComp && _gameplay->isCompleted()) {
        if (_imgIdx == _packInfo->images.size()-1) {
            //complete
            btnFadeIn(_btnFinish);
            btnFadeIn(_btnNextPack);
            btnFadeOut(_btnBack);
            _timeBar->stop();
            _isFinish = true;
            
            //setStar
            auto cs = CollectionStars::getInstance();
            int prevStarNum = cs->getStarNum(_packInfo->id);
            int starNum = _timeBar->getStarNum();
            if (starNum > prevStarNum) {
                cs->setStarNum(_packInfo->id, starNum);
            }
            
            //
            if (starNum == 0) {
                _gradeLabel->setString(lang("Failed"));
                _starLabel->setString("");
            } else if (starNum == 1) {
                _gradeLabel->setString(lang("Pass"));
                _starLabel->setString("★");
            } else if (starNum == 2) {
                _gradeLabel->setString(lang("Good"));
                _starLabel->setString("★★");
            } else if (starNum == 3) {
                _gradeLabel->setString(lang("Great"));
                _starLabel->setString("★★★");
            }
            
            //show grade
            float t = .2f;
            auto scaleTo = ScaleTo::create(t, 1.f);
            auto ease = EaseSineIn::create(scaleTo);
            auto fadeIn = FadeIn::create(t);
            auto spawn = Spawn::create(ease, fadeIn, nullptr);
            auto delay = DelayTime::create(1.2f);
            auto callback = CallFunc::create(CC_CALLBACK_0(SliderScene::showStar, this));
            auto seq = Sequence::create(spawn, delay, callback, nullptr);
            _gradeLabel->runAction(seq);
        } else {
            btnFadeIn(_btnNext);
        }
    }
}

void SliderScene::showStar() {
    //SimpleAudioEngine::getInstance()->playEffect(SND_STAR);
    
    float flipT = .15f;
    auto gScale = ScaleTo::create(flipT, 1.f, 0.f);
    auto gEase = EaseSineIn::create(gScale);
    _gradeLabel->runAction(gEase);
    
    float outT = .3f;
    auto delay = DelayTime::create(flipT);
    auto scale = ScaleTo::create(flipT, 1.f);
    auto ease = EaseSineOut::create(scale);
    auto stay = DelayTime::create(2.f);
    auto fadeOut = FadeOut::create(outT);
    auto eFadeOut = EaseSineIn::create(fadeOut);
    auto scaleOut = ScaleTo::create(outT, 1.4f);
    auto easeOut = EaseBackIn::create(scaleOut);
    auto out = Spawn::create(eFadeOut, easeOut, nullptr);
    auto seq = Sequence::create(delay, ease, stay, out, nullptr);
    _starLabel->runAction(seq);
}

void SliderScene::onTouchesCancelled(const std::vector<Touch*>&touches, Event *event) {
    onTouchesEnded(touches, event);
}

void SliderScene::reset(int imgIdx) {
    _imgIdx = imgIdx;
    std::string local;
    auto idx = _packInfo->imageIndices[_imgIdx];
    makeLocalImagePath(local, _packInfo->images[idx].key.c_str());
    bool isLast = imgIdx == _packInfo->images.size() - 1;
    _gameplay->reset(local.c_str(), _packInfo->sliderNum, isLast);
    //_gameplay->reset(local.c_str(), 3);
    auto nextIdx = _imgIdx + 1;
    if (nextIdx >= _packInfo->images.size()) {
        nextIdx = 0;
    }
    idx = _packInfo->imageIndices[nextIdx];
    makeLocalImagePath(local, _packInfo->images[idx].key.c_str());
    _gameplay->preload(local.c_str());
    
    //
    btnFadeOut(_btnNext);
    
    //
    Sprite *dot = (Sprite*)(_dotBatch->getChildren()->getObjectAtIndex(imgIdx));
    auto fadeTo = FadeTo::create(.3f, 255);
    auto ease = EaseSineOut::create(fadeTo);
    dot->runAction(ease);
    if (imgIdx > 0) {
        Sprite *prevDot = (Sprite*)(_dotBatch->getChildren()->getObjectAtIndex(imgIdx-1));
        auto fadeTo = FadeTo::create(.3f, TRANS_DOT_OPACITY);
        auto ease = EaseSineOut::create(fadeTo);
        prevDot->runAction(ease);
    }
}



