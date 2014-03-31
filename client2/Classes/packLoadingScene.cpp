#include "packLoadingScene.h"
#include "http.h"
#include "lang.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

PackInfo PackLoadingLayer::_packInfo;

PackLoadingLayer* PackLoadingLayer::createWithScene(PackInfo &packInfo, Scene *enterScene) {
    auto scene = Scene::create();
    auto *p = new PackLoadingLayer();
    if (p && p->init(packInfo, enterScene)) {
        p->autorelease();
        scene->addChild(p);
        return p;
    }
    CC_SAFE_DELETE(p);
    return nullptr;
}

PackLoadingLayer* PackLoadingLayer::createWithScene(uint64_t packId, Scene *enterScene) {
    auto scene = Scene::create();
    auto *p = new PackLoadingLayer();
    if (p && p->init(packId, enterScene)) {
        p->autorelease();
        scene->addChild(p);
        return p;
    }
    CC_SAFE_DELETE(p);
    return nullptr;
}

bool PackLoadingLayer::init(PackInfo &packInfo, Scene *enterScene) {
    if (!LayerColor::init()) {
        return false;
    }
    
    //init
    _packInfo = packInfo;
    _enterScene = enterScene;
    _enterScene->retain();
    
    //
    Size visSize = Director::getInstance()->getVisibleSize();
    
    //pack downloader
    _packDownloader = new PackDownloader;
    _packDownloader->init(&packInfo, this);
    
    //progress label
    _progressLabel = LabelTTF::create("0%", "HelveticaNeue", 38);
    _progressLabel->setAnchorPoint(Point(.5f, .5f));
    _progressLabel->setPosition(Point(visSize.width*.5f, 600));
    _progressLabel->setColor(Color3B(250, 250, 250));
    _progressLabel->setVisible(false);
    _progressLabel->enableShadow(Size(2.f, -2.f), .8f, 2.f);
    addChild(_progressLabel, 1);
    
    //download pack
    if (_packDownloader->progress != 1.f) {
        _packDownloader->startDownload();
        char buf[64];
        snprintf(buf, 64, "%s... %d%%", lang("Downloading"), (int)(_packDownloader->progress*100));
        _progressLabel->setString(buf);
        _progressLabel->setVisible(true);
    } else {
        onPackDownloadComplete();
    }
    
    return true;
}

bool PackLoadingLayer::init(uint64_t packId, Scene *enterScene) {
    if (!LayerColor::init()) {
        return false;
    }
    
    //init
    _enterScene = enterScene;
    _enterScene->retain();
    _packInfo.id = packId;
    
    //
    Size visSize = Director::getInstance()->getVisibleSize();
    
    //pack downloader
    _packDownloader = new PackDownloader;
    
    //progress label
    _progressLabel = LabelTTF::create("0%", "HelveticaNeue", 38);
    _progressLabel->setAnchorPoint(Point(.5f, .5f));
    _progressLabel->setPosition(Point(visSize.width*.5f, 600));
    _progressLabel->setColor(Color3B(250, 250, 250));
    _progressLabel->setVisible(false);
    _progressLabel->enableShadow(Size(2.f, -2.f), .8f, 2.f);
    _progressLabel->setString("xxxxxxxxxxxxxx");
    addChild(_progressLabel, 1);
    
    //send msg
    jsonxx::Object msg;
    msg << "Id" << _packInfo.id;
    postHttpRequest("pack/get", msg.json().c_str(), this, (SEL_HttpResponse)&PackLoadingLayer::onHttpGetPack);
    
    return true;
}

PackLoadingLayer::~PackLoadingLayer() {
    _packDownloader->destroy();
    _enterScene->release();
}

void PackLoadingLayer::onHttpGetPack(HttpClient* cli, HttpResponse* resp) {
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
    _packDownloader->init(&_packInfo, this);
    
    //start to download
    if (_packDownloader->progress != 1.f) {
        _packDownloader->startDownload();
        char buf[64];
        snprintf(buf, 64, "%s... %d%%", lang("Downloading"), (int)(_packDownloader->progress*100));
        _progressLabel->setString(buf);
        _progressLabel->setVisible(true);
    } else {
        onPackDownloadComplete();
    }
}

//void PackLoadingLayer::onEnterTransitionDidFinish() {
//    //send msg
//    jsonxx::Object msg;
//    msg << "Id" << _packInfo.id;
//    postHttpRequest("pack/get", msg.json().c_str(), this, (SEL_HttpResponse)&PackLoadingLayer::onHttpGetPack);
//}

PackInfo& PackLoadingLayer::getPackInfo() {
    return _packInfo;
}

void PackLoadingLayer::onPackImageDownload() {
    char buf[64];
    snprintf(buf, 64, "%s... %d%%", lang("Downloading"), (int)(_packDownloader->progress*100));
    _progressLabel->setString(buf);
}

void PackLoadingLayer::onPackDownloadComplete() {
    Director::getInstance()->popScene((Scene*)(this->getParent()));
    Director::getInstance()->pushScene(TransitionFade::create(0.5f, _enterScene));
    //_progressLabel->setVisible(false);
}