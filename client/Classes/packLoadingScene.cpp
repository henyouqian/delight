#include "packLoadingScene.h"
#include "lw/lwLog.h"
#include "lang.h"

USING_NS_CC;
USING_NS_CC_EXT;

PackInfo PackLoadingLayer::_packInfo;

PackLoadingLayer* PackLoadingLayer::create(PackInfo &packInfo, Scene *enterScene) {
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
    }
    
    return true;
}

PackLoadingLayer::~PackLoadingLayer() {
    _packDownloader->destroy();
    _enterScene->release();
}

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