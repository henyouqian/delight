#include "mainMenuScene.h"
#include "eventListScene.h"
#include "collectionListScene.h"
#include "util.h"
#include "lang.h"
#include "http.h"
#include "jsonxx/jsonxx.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

Scene* MainMenuScene::createScene() {
    auto scene = Scene::create();
    auto layer = MainMenuScene::create();
    scene->addChild(layer);
    
    return scene;
}

void MainMenuScene::onLogin(HttpClient *c, HttpResponse *r) {
    if (!r->isSucceed()) {
        lwerror("http error");
        return;
    }
    auto vData = r->getResponseData();
    std::istringstream is(std::string(vData->begin(), vData->end()));
    lwinfo("%s", is.str().c_str());
}

void MainMenuScene::onInfo(HttpClient *c, HttpResponse *r) {
    if (!r->isSucceed()) {
        lwerror("http error");
        return;
    }
    auto vData = r->getResponseData();
    std::istringstream is(std::string(vData->begin(), vData->end()));
    lwinfo("%s", is.str().c_str());
}

bool MainMenuScene::init() {
    if ( !Layer::init() ) {
        return false;
    }
    HttpClient::getInstance()->enableCookies(nullptr);
    
    srand(time(nullptr));
    
    Size visibleSize = Director::getInstance()->getVisibleSize();
    
    //buttons
    auto button = createButton(lang("Play"), 48, 2.f);
    button->setPosition(Point(visibleSize.width/2, visibleSize.height/2));
    button->addTargetWithActionForControlEvents(this, cccontrol_selector(MainMenuScene::enterCollectionList), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(button, 1);
    
    button = createButton(lang("Match"), 48, 2.f);
    button->setPosition(Point(visibleSize.width/2, visibleSize.height/3));
    button->addTargetWithActionForControlEvents(this, cccontrol_selector(MainMenuScene::enterMatchMode), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(button, 1);
    
    //login test
    jsonxx::Object loginMsg;
    loginMsg << "Username" << "aa";
	loginMsg << "Password" << "aa";
    postHttpRequest("auth/login", loginMsg.json().c_str(), this, (SEL_HttpResponse)&MainMenuScene::onLogin);
    
    postHttpRequest("auth/info", "\"admin\"", this, (SEL_HttpResponse)&MainMenuScene::onInfo);
    return true;
}

void MainMenuScene::onEnterTransitionDidFinish() {
    TextureCache::getInstance()->removeUnusedTextures();
}

void MainMenuScene::enterCollectionList(Object *sender, Control::EventType controlEvent) {
//    auto layer = CollectionListScene::createScene();
//    Director::getInstance()->pushScene(TransitionFade::create(0.5f, layer->scene));
    
    auto layer = MainContainerLayer::create();
    Director::getInstance()->pushScene(TransitionFade::create(0.5f, layer->getScene()));
}

void MainMenuScene::enterMatchMode(Object *sender, Control::EventType controlEvent) {
    Director::getInstance()->pushScene(TransitionFade::create(0.5f, (Scene*)EventListLayer::createWithScene()->getParent()));
}