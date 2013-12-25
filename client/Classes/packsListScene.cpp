#include "packsListScene.h"
#include "http.h"
#include "spriteLoader.h"
#include "gifTexture.h"
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
    
    //fixme: spriteLoader test
    //auto *task = SptLoadTask::loadFromUrl("http://image.zcool.com.cn/41/0/m_1281182218957.jpg");
    SptLoader::getInstance()->load("1.png");
    SptLoader::getInstance()->load("2.png");
    SptLoader::getInstance()->load("3.png");
    SptLoader::getInstance()->load("4.png");
    
    _pack = new Pack;
    _pack->init(4, this);
    lwinfo("progress: %f", _pack->progress);
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
    return true;
}

PacksListScene::~PacksListScene() {
    if (_packListRequest) {
        _packListRequest->release();
    }
    _loadingTexture->release();
    delete _pack;
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
        auto spt = Sprite::createWithTexture(_loadingTexture);
        this->addChild(spt);
        int row = i / 3;
        int col = i % 3;
        float w = (visSize.width-2.f*margin) / 3.f;
        float x = (w+margin)*col + .5f*w;
        float y = visSize.height - ((w+margin)*row+.5f*w);
        spt->setPosition(Point(x, y));
        spt->setScale(2.f);
        
        //async load
        
    }
}

void PacksListScene::onPackParseComplete() {
    lwinfo("onPackParseComplete");
    _pack->download();
}

void PacksListScene::onError() {
    lwinfo("onError");
}

void PacksListScene::onImageDownload(){
    lwinfo("onImageDownload: %f", _pack->progress);
}

void PacksListScene::onComplete() {
    lwinfo("onComplete");
}

void PacksListScene::onTouchesBegan(const std::vector<Touch*>& touches, Event *event) {
    auto touch = touches[0];
    
    SptLoader::getInstance()->load("xxxxxxx.png");
}






