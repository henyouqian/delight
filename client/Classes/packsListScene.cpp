#include "packsListScene.h"
#include "http.h"
#include "spriteLoader.h"
#include "gifTexture.h"
#include "util.h"
#include "jsonxx/jsonxx.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

cocos2d::Scene* PacksListScene::createScene() {
    auto scene = Scene::create();
    auto layer = PacksListScene::create();
    scene->addChild(layer);
    return scene;
}

bool PacksListScene::init() {
    if (!LayerColor::initWithColor(Color4B(255, 255, 255, 255)))  {
        return false;
    }
    this->setTouchEnabled(true);
    this->scheduleUpdate();
    
    _sptLoader = SptLoader::create(this, this);
    _sptLoader->download("http://image.zcool.com.cn/41/0/m_1281182218957.jpg");
    
    //fixme: spriteLoader test
//    _pack = new Pack;
//    _pack->init(4, this);
//    lwinfo("progress: %f", _pack->progress);
    //fixend
    
    
    //get list
    std::string url;
    char buf[256];
    snprintf(buf, 256, "{\"LastPackId\": %d, \"Limit\": %d}", 0, 16);
    _packListRequest = postHttpRequest("pack/list", buf, std::bind(&PacksListScene::onPackList, this, std::placeholders::_1, std::placeholders::_2));
    _packListRequest->retain();
    
    //loading texture
    _loadingTexture = GifTexture::create("ui/loading.gif", this, false);
    _loadingTexture->retain();
    _loadingTexture->setSpeed(2.f);
    
    //test
//    auto spt = Sprite::create("/Users/weili/Library/Application Support/iPhone Simulator/7.0.3/Applications/43409BA6-5B2F-43B4-80AE-FBE08C2E63F7/Documents/images/85131b9e79e1da9c0d88c7c65fee6c79ec261df7");
//    this->addChild(spt);

    return true;
}

PacksListScene::~PacksListScene() {
    if (_packListRequest) {
        _packListRequest->release();
    }
    _loadingTexture->release();
    delete _pack;
    delete _sptLoader;
}

void PacksListScene::update(float delta) {
    _sptLoader->mainThreadUpdate();
    
//    //check loaded sprite
//    while(1) {
//        SptLoader::LoadedSprite ls;
//        if (!_sptLoader->popLoadedSprite(ls)) {
//            break;
//        }
//        
//        auto it = _loadingSpts.find(ls.localPath);
//        if (it == _loadingSpts.end()) {
//            lwerror("loading error");
//        } else {
//            auto loadingSpt = it->second;
//            loadingSpt->getParent()->addChild(ls.spt);
//            ls.spt->setPosition(loadingSpt->getPosition());
//            ls.spt->setScale(.3f);
//            loadingSpt->removeFromParent();
//            _loadingSpts.erase(it);
//        }
//        lwinfo("spt loaded");
//    }
}

namespace {
    Sprite* loadSprite(const char *filename, Node *parentNode) {
        //try gif first
        auto spt = GifTexture::createSprite(filename, parentNode);
        if (!spt) {
            spt = Sprite::create(filename);
        }
        return spt;
    }
}

void PacksListScene::onPackList(HttpClient* client, HttpResponse* response) {
    lwinfo("onPackList");
    auto v = response->getResponseData();
    std::istringstream is(std::string(v->begin(), v->end()));
    
    jsonxx::Array packs;
    bool ok = packs.parse(is);
    if (!ok) {
        lwerror("json parse error");
        return;
    }
    
    auto visSize = Director::getInstance()->getVisibleSize();
    for (auto i = 0; i < packs.size(); ++i) {
        auto pack = packs.get<jsonxx::Object>(i);
        
        if (!pack.has<jsonxx::Number>("Id")) {
            lwerror("json parse error: no number: Id");
            return;
        }
        if (!pack.has<jsonxx::String>("Date")) {
            lwerror("json parse error: no string: Date");
            return;
        }
        if (!pack.has<jsonxx::String>("Title")) {
            lwerror("json parse error: no string: Title");
            return;
        }
        if (!pack.has<jsonxx::String>("Cover")) {
            lwerror("json parse error: no string: Cover");
            return;
        }
        if (!pack.has<jsonxx::String>("Text")) {
            lwerror("json parse error: no string: Text");
            return;
        }
        
        PackInfo packInfo;
        packInfo.id = (int)(pack.get<jsonxx::Number>("Id"));
        packInfo.date = pack.get<jsonxx::String>("Date");
        packInfo.cover = pack.get<jsonxx::String>("Cover");
        packInfo.title = pack.get<jsonxx::String>("Title");
        packInfo.text = pack.get<jsonxx::String>("Text");
        packInfo.sprite = nullptr;
        
        _packInfos.push_back(packInfo);
        
        //loading sprite
        float margin = 10.f;
        auto loadingSpt = Sprite::createWithTexture(_loadingTexture);
        this->addChild(loadingSpt);
        int row = i / 3;
        int col = i % 3;
        float w = (visSize.width-2.f*margin) / 3.f;
        float x = (w+margin)*col + .5f*w;
        float y = visSize.height - ((w+margin)*row+.5f*w);
        loadingSpt->setPosition(Point(x, y));
        loadingSpt->setScale(2.f);
        _thumbWidth = w;
        
        //async load
        std::string localPath;
        makeLocalImagePath(localPath, packInfo.cover.c_str());
        
        _loadingSpts.insert(std::make_pair(localPath, loadingSpt));
        _sptLoader->download(packInfo.cover.c_str());
    }
}

void PacksListScene::onPackParseComplete() {
    lwinfo("onPackParseComplete");
    _pack->startDownload();
}

void PacksListScene::onPackError() {
    lwinfo("onPackError");
}

void PacksListScene::onPackImageDownload(){
    lwinfo("onPackImageDownload: %f", _pack->progress);
}

void PacksListScene::onPackDownloadComplete() {
    lwinfo("onPackDownloadComplete");
}

void PacksListScene::onSptLoaderLoad(const char *localPath, Sprite* sprite) {
    lwinfo("onSptLoaderLoad");
    
//    auto range = _loadingSpts.equal_range(localPath);
//    if (range.first == range.second) {
//        lwerror("no loading sprite to replace");
//    } else {
//        for (auto it = range.first; it != range.second; ++it) {
//            auto loadingSpt = it->second;
//            loadingSpt->getParent()->addChild(sprite);
//            sprite->setPosition(loadingSpt->getPosition());
//            
//            sprite->setScale(_thumbWidth/sprite->getContentSize().width);
//            loadingSpt->removeFromParent();
//        }
//        _loadingSpts.erase(range.first, range.second);
//    }
    auto it = _loadingSpts.find(localPath);
    if (it == _loadingSpts.end()) {
        lwerror("no loading sprite to replace");
    } else {
        auto loadingSpt = it->second;
        loadingSpt->getParent()->addChild(sprite);
        sprite->setPosition(loadingSpt->getPosition());
        
        sprite->setScale(_thumbWidth/sprite->getContentSize().width);
        loadingSpt->removeFromParent();
        _loadingSpts.erase(it);
    }
}

void PacksListScene::onSptLoaderError(const char *localPath) {
    lwinfo("onSptLoaderError");
    
    
}

void PacksListScene::onTouchesBegan(const std::vector<Touch*>& touches, Event *event) {
    //auto touch = touches[0];
    _sptLoader->download("http://image.zcool.com.cn/41/0/m_1281182218957.jpg");
}






