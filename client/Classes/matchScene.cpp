#include "matchScene.h"
#include "gifTexture.h"
#include "util.h"
#include "lang.h"
#include "db.h"
#include "lw/lwLog.h"
#include "SimpleAudioEngine.h"
#include "modeSelectScene.h"
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

//static const char *SND_STAR = "audio/star.aiff";

static const int SLIDER_NUM = 6;

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

MatchLayer* MatchLayer::create(PackInfo *packInfo) {
    auto scene = Scene::create();
    auto *p = new MatchLayer();
    if (p && p->init(packInfo)) {
        p->autorelease();
        scene->addChild(p);
        return p;
    }
    CC_SAFE_DELETE(p);
    return nullptr;
}

bool MatchLayer::init(PackInfo *packInfo) {
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
    
    _gameplay = Gameplay::create(this);
    addChild(_gameplay);

    //next button
    _btnNext = createColorButton("〉", FORWARD_BACK_FONT_SIZE, 1.f, Color3B::WHITE, GREEN, BTN_BG_OPACITY);
    _btnNext->setTitleOffset(FORWARD_BACK_FONT_OFFSET, 0.f);
    _btnNext->setPosition(Point(size.width-70, 70));
    _btnNext->addTargetWithActionForControlEvents(this, cccontrol_selector(MatchLayer::next), Control::EventType::TOUCH_UP_INSIDE);
    _btnNext->setOpacity(0);
    auto label = (LabelTTF*)_btnNext->getTitleLabelForState(Control::State::NORMAL);
    label->setOpacity(0);
    this->addChild(_btnNext, 10);
    
    //back button
    _btnBack = createButton(lang("Back"), 36, 1.f);
    _btnBack->setPosition(Point(70, 70));
    _btnBack->addTargetWithActionForControlEvents(this, cccontrol_selector(MatchLayer::ShowBackConfirm), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(_btnBack, 10);
    
    //yes button
    _btnYes = createColorButton(lang("Yes"), 36, 1.f, Color3B::WHITE, Color3B(255, 59, 48), BTN_BG_OPACITY);
    _btnYes->setPosition(Point(70, 70));
    _btnYes->addTargetWithActionForControlEvents(this, cccontrol_selector(MatchLayer::back), Control::EventType::TOUCH_UP_INSIDE);
    _btnYes->setOpacity(0);
    label = (LabelTTF*)_btnYes->getTitleLabelForState(Control::State::NORMAL);
    label->setOpacity(0);
    _btnYes->setEnabled(false);
    this->addChild(_btnYes, 10);
    
    //no button
    _btnNo = createButton(lang("No"), 36, 1.f);
    _btnNo->setPosition(Point(70, 70));
    _btnNo->addTargetWithActionForControlEvents(this, cccontrol_selector(MatchLayer::HideBackConfirm), Control::EventType::TOUCH_UP_INSIDE);
    _btnNo->setOpacity(0);
    label = (LabelTTF*)_btnNo->getTitleLabelForState(Control::State::NORMAL);
    label->setOpacity(0);
    _btnNo->setEnabled(false);
    this->addChild(_btnNo, 10);
    
    //finish button
    _btnFinish = createColorButton(lang("Back"), 36, 1.f, Color3B::WHITE, RED, BTN_BG_OPACITY);
    _btnFinish->setPosition(Point(70, 70));
    _btnFinish->addTargetWithActionForControlEvents(this, cccontrol_selector(MatchLayer::back), Control::EventType::TOUCH_UP_INSIDE);
    _btnFinish->setOpacity(0);
    _btnFinish->setEnabled(false);
    label = (LabelTTF*)_btnFinish->getTitleLabelForState(Control::State::NORMAL);
    label->setOpacity(0);
    this->addChild(_btnFinish, 10);
    
    //next pack button
    _btnNextPack = createColorButton(lang("Next"), 36, 1.f, Color3B::WHITE, GREEN, BTN_BG_OPACITY);
    _btnNextPack->setPosition(Point(visSize.width-70, 70));
    //_btnNextPack->addTargetWithActionForControlEvents(this, cccontrol_selector(MatchLayer::nextPack), Control::EventType::TOUCH_UP_INSIDE);
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
    
    //shuffle image order
    _packInfo->shuffleImageIndices();
    
    //reset
    reset(0);
    
    return true;
}

MatchLayer::~MatchLayer() {
    
}

void MatchLayer::onReset(float rotate) {
    auto rot = RotateTo::create(.3f, rotate);
    auto ease = EaseSineInOut::create(rot);
    _btnNext->runAction(ease->clone());
    _btnBack->runAction(ease->clone());
    _btnYes->runAction(ease->clone());
    _btnNo->runAction(ease->clone());
    _btnFinish->runAction(ease->clone());
    _btnNextPack->runAction(ease->clone());
}

void MatchLayer::ShowBackConfirm(Object *sender, Control::EventType controlEvent) {
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

void MatchLayer::HideBackConfirm(Object *sender, Control::EventType controlEvent) {
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

void MatchLayer::back(Object *sender, Control::EventType controlEvent) {
    Director::getInstance()->popSceneWithTransition<TransitionFade>((Scene*)this->getParent(), .5f);
}

void MatchLayer::next(Object *sender, Control::EventType controlEvent) {
    int imgIdx = _imgIdx + 1;
    if (imgIdx == _packInfo->images.size()) {
        imgIdx = 0;
    }
    reset(imgIdx);
}

void MatchLayer::onTouchesBegan(const std::vector<Touch*>& touches, Event *event) {
    _gameplay->onTouchesBegan(touches);
    if (_btnYes->getOpacity() != 0) {
        HideBackConfirm(nullptr, Control::EventType::TOUCH_DOWN);
    }
    if (!_isFinish && _gameplay->isCompleted()) {
        next(nullptr, Control::EventType::TOUCH_DOWN);
    }
}

void MatchLayer::onTouchesMoved(const std::vector<Touch*>& touches, Event *event) {
    _gameplay->onTouchesMoved(touches);
}

void MatchLayer::onTouchesEnded(const std::vector<Touch*>& touches, Event *event) {
    auto isComp = _gameplay->isCompleted();
    _gameplay->onTouchesEnded(touches);
    if (!isComp && _gameplay->isCompleted()) {
        if (_imgIdx == _packInfo->images.size()-1) {
            //complete
            btnFadeIn(_btnFinish);
            btnFadeOut(_btnBack);
            _isFinish = true;
            
            //_btnNextPack
            btnFadeIn(_btnNextPack);
        } else {
            btnFadeIn(_btnNext);
        }
    }
}

void MatchLayer::onTouchesCancelled(const std::vector<Touch*>&touches, Event *event) {
    onTouchesEnded(touches, event);
}

void MatchLayer::reset(int imgIdx) {
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



