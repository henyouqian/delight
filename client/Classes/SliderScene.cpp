#include "SliderScene.h"
#include "gifTexture.h"
#include "util.h"
#include "lang.h"
#include "lw/lwLog.h"
#include "SimpleAudioEngine.h"
#include <sys/stat.h>

USING_NS_CC;
USING_NS_CC_EXT;

static const GLubyte BTN_BG_OPACITY = 160;
static const float BTN_EASE_DUR = .2f;

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
    this->scheduleUpdate();
    this->setTouchEnabled(true);
    
    _imgIdx = 0;
    
    auto ori = Director::getInstance()->getVisibleOrigin();
    auto size = Director::getInstance()->getVisibleSize();
    auto rect = Rect(ori.x, ori.y, size.width, size.height);
    _gameplay = new Gameplay(rect, this);
    addChild(_gameplay);

    //next button
    _btnNext = createColorButton(lang("Next"), 36, 1.f, Color3B::WHITE, Color3B(76, 217, 100), BTN_BG_OPACITY);
    _btnNext->setPosition(Point(size.width-50, 50));
    _btnNext->addTargetWithActionForControlEvents(this, cccontrol_selector(SliderScene::next), Control::EventType::TOUCH_UP_INSIDE);
    _btnNext->setOpacity(0);
    auto label = (LabelTTF*)_btnNext->getTitleLabelForState(Control::State::NORMAL);
    label->setOpacity(0);
    this->addChild(_btnNext, 10);
    
    //back button
    _btnBack = createButton(lang("Back"), 36, 1.f);
    _btnBack->setPosition(Point(50, 50));
    _btnBack->addTargetWithActionForControlEvents(this, cccontrol_selector(SliderScene::ShowBackConfirm), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(_btnBack, 10);
    
    //yes button
    _btnYes = createColorButton(lang("Yes"), 36, 1.f, Color3B::WHITE, Color3B(255, 59, 48), BTN_BG_OPACITY);
    _btnYes->setPosition(Point(50, 50));
    _btnYes->addTargetWithActionForControlEvents(this, cccontrol_selector(SliderScene::back), Control::EventType::TOUCH_UP_INSIDE);
    _btnYes->setOpacity(0);
    label = (LabelTTF*)_btnYes->getTitleLabelForState(Control::State::NORMAL);
    label->setOpacity(0);
    _btnYes->setEnabled(false);
    this->addChild(_btnYes, 10);
    
    //no button
    _btnNo = createButton(lang("No"), 36, 1.f);
    _btnNo->setPosition(Point(50, 50));
    _btnNo->addTargetWithActionForControlEvents(this, cccontrol_selector(SliderScene::HideBackConfirm), Control::EventType::TOUCH_UP_INSIDE);
    _btnNo->setOpacity(0);
    label = (LabelTTF*)_btnNo->getTitleLabelForState(Control::State::NORMAL);
    label->setOpacity(0);
    _btnNo->setEnabled(false);
    this->addChild(_btnNo, 10);
    
    //shuffle image order
    _packInfo->shuffleImageIndices();
    
    //reset
    reset(0);
    
    return true;
}

SliderScene::~SliderScene() {
    if (_gameplay) {
        delete _gameplay;
    }
}

void SliderScene::update(float delta) {
    
}

void SliderScene::onImageRotate(float rotate) {
    auto rot = RotateTo::create(.3f, rotate);
    auto ease = EaseSineInOut::create(rot);
    _btnNext->runAction(ease->clone());
    _btnBack->runAction(ease->clone());
    _btnYes->runAction(ease->clone());
    _btnNo->runAction(ease->clone());
}

void SliderScene::ShowBackConfirm(Object *sender, Control::EventType controlEvent) {
    //yes button
    auto fadeto = FadeTo::create(BTN_EASE_DUR, BTN_BG_OPACITY);
    auto easeFadeto = EaseSineOut::create(fadeto);
    auto moveTo = MoveTo::create(BTN_EASE_DUR, Point(50.f, 150.f));
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
    auto moveTo = MoveTo::create(BTN_EASE_DUR, Point(50.f, 50.f));
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
    Director::getInstance()->popSceneWithTransition<TransitionFade>(.5f);
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
}

void SliderScene::onTouchesMoved(const std::vector<Touch*>& touches, Event *event) {
    _gameplay->onTouchesMoved(touches);
}

void SliderScene::onTouchesEnded(const std::vector<Touch*>& touches, Event *event) {
    auto isComp = _gameplay->isCompleted();
    _gameplay->onTouchesEnded(touches);
    if (!isComp && _gameplay->isCompleted()) {
        btnFadeIn(_btnNext);
    }
}

void SliderScene::onTouchesCancelled(const std::vector<Touch*>&touches, Event *event) {
    onTouchesEnded(touches, event);
}

void SliderScene::reset(int imgIdx) {
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
    
    //
    btnFadeOut(_btnNext);
}



