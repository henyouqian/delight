#include "packsBookScene.h"
#include "util.h"
#include "http.h"
#include "gifTexture.h"
#include "jsonxx/jsonxx.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

static const int PACKS_PER_PAGE = 12;
static const float ICON_MARGIN = 5.f;
static const float ICON_Y0 = 120.f;

Scene* PacksBookScene::createScene() {
    auto scene = Scene::create();
    auto layer = PacksBookScene::create();
    scene->addChild(layer);
    return scene;
}

bool PacksBookScene::init() {
    auto visSize = Director::getInstance()->getVisibleSize();
    
    if (!LayerColor::initWithColor(Color4B(255, 255, 255, 255)))  {
        return false;
    }
    this->setTouchEnabled(true);
    this->scheduleUpdate();
    
    //back button
    auto btnBack = createRingButton("﹤", 48, 1.f, Color3B(0, 122, 255));
    btnBack->setPosition(Point(70, 70));
    btnBack->addTargetWithActionForControlEvents(this, cccontrol_selector(PacksBookScene::back), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(btnBack);
    
    //older
    auto label = LabelTTF::create("〈", "HelveticaNeue", 56);
    label->setColor(Color3B(0, 122, 255));
    auto btn = ControlButton::create(label, Scale9Sprite::create());
    btn->setAnchorPoint(Point(0.f, 0.5f));
    btn->setPosition(Point(10.f, visSize.height-80));
    addChild(btn);
    
    //newer
    label = LabelTTF::create("〉", "HelveticaNeue", 56);
    label->setColor(Color3B(0, 122, 255));
    btn = ControlButton::create(label, Scale9Sprite::create());
    btn->setAnchorPoint(Point(1.f, 0.5f));
    btn->setPosition(Point(visSize.width-10, visSize.height-80));
    addChild(btn);
    
    //loading texture
    _loadingTexture = GifTexture::create("ui/loading.gif", this, false);
    _loadingTexture->retain();
    _loadingTexture->setSpeed(2.f);
    
    _loadingSprParent = Node::create();
    addChild(_loadingSprParent);
    
    //page
    _pageLabel = LabelTTF::create("连接中...", "HelveticaNeue", 38);
    _pageLabel->setAnchorPoint(Point(.5f, .5f));
    _pageLabel->setPosition(Point(visSize.width*.5f, visSize.height-80));
    _pageLabel->setColor(Color3B(255, 59, 48));
    addChild(_pageLabel);
    
    //get pack count
    _packCount = 0;
    _pageCount = 0;
    postHttpRequest("pack/count", "", this, (SEL_HttpResponse)(&PacksBookScene::onHttpGetCount));
    
    //sptLoader
    _sptLoader = SptLoader::create(this);
    addChild(_sptLoader);
    
    return true;
}

PacksBookScene::~PacksBookScene() {
    _loadingTexture->release();
    _sptLoader->destroy();
}

void PacksBookScene::back(Object *sender, Control::EventType controlEvent) {
    Director::getInstance()->popSceneWithTransition<TransitionFade>(.5f);
}

void PacksBookScene::onHttpGetCount(HttpClient* client, HttpResponse* response) {
    if (!response->isSucceed()) {
        _pageLabel->setString("连接失败");
        return;
    }
    
    //get pack count
    auto vData = response->getResponseData();
    std::istringstream is(std::string(vData->begin(), vData->end()));
    
    jsonxx::Object root;
    bool ok = root.parse(is);
    if (!ok) {
        lwerror("json parse error");
        return;
    }
    if (!root.has<jsonxx::Number>("PackCount")) {
        lwerror("json parse error: no number: Id");
        return;
    }
    _packCount = root.get<jsonxx::Number>("PackCount");
    
    _pageCount = (_packCount-1) / PACKS_PER_PAGE + 1;
    _pageCount = MAX(_pageCount, 1);
    
    //load last page
    loadPage(_pageCount-1);
}

void PacksBookScene::loadPage(int page) {
    _currPage = page;
    char buf[64];
    snprintf(buf, 64, "%d/%d", page+1, _pageCount);
    _pageLabel->setString(buf);
    
    //
    _packs.clear();
    
    //query packs info
    int offset = page * PACKS_PER_PAGE;
    int limit = PACKS_PER_PAGE;
    jsonxx::Object msg;
    msg << "Offset" << offset;
    msg << "Limit" << limit;
    
    postHttpRequest("pack/get", msg.json().c_str(), this, (SEL_HttpResponse)(&PacksBookScene::onHttpGetPack));
    
    //setup loading sprite
    _loadingSprParent->removeAllChildren();
    
    int packNum = PACKS_PER_PAGE;
    if (_currPage == _pageCount-1) {
        packNum = _packCount % PACKS_PER_PAGE;
    }
    
    for (auto i = 0; i < packNum; ++i) {
        auto loadingSpr = Sprite::createWithTexture(_loadingTexture);
        _loadingSprParent->addChild(loadingSpr);
        int row = i / 3;
        int col = i % 3;
        auto visSize = Director::getInstance()->getVisibleSize();
        float w = (visSize.width-2.f*ICON_MARGIN) / 3.f;
        float x = (w+ICON_MARGIN)*col + .5f*w;
        float y = visSize.height - ((w+ICON_MARGIN)*row+.5f*w) - ICON_Y0;
        loadingSpr->setPosition(Point(x, y));
        loadingSpr->setScale(2.f);
        _iconWidth = w;
    }
    
    //
}

void PacksBookScene::onHttpGetPack(HttpClient* client, HttpResponse* response) {
    if (!response->isSucceed()) {
        lwerror("onHttpGetPack failed");
        return;
    }
    
    //parse json
    auto vData = response->getResponseData();
    std::istringstream is(std::string(vData->begin(), vData->end()));
    
    jsonxx::Object msg;
    bool ok = msg.parse(is);
    if (!ok) {
        lwerror("json parse error");
        return;
    }
    
    if (!msg.has<jsonxx::Array>("Packs")) {
        lwerror("json parse error: no Packs");
        return;
    }
    auto packsJs = msg.get<jsonxx::Array>("Packs");
    for (auto i = 0; i < packsJs.size(); ++i) {
        auto packJs = packsJs.get<jsonxx::Object>(i);
        if (!packJs.has<jsonxx::Number>("Id")) {
            lwerror("json parse error: no Id");
            return;
        }
        if (!packJs.has<jsonxx::String>("Date")) {
            lwerror("json parse error: no Date");
            return;
        }
        if (!packJs.has<jsonxx::String>("Title")) {
            lwerror("json parse error: no Title");
            return;
        }
        if (!packJs.has<jsonxx::String>("Text")) {
            lwerror("json parse error: no string: Text");
            return;
        }
        if (!packJs.has<jsonxx::String>("Icon")) {
            lwerror("json parse error: no Icon");
            return;
        }
        if (!packJs.has<jsonxx::String>("Cover")) {
            lwerror("json parse error: no Cover");
            return;
        }
        if (!packJs.has<jsonxx::Array>("Images")) {
            lwerror("json parse error: no Images");
            return;
        }
        
        Pack pack;
        pack.id = (int)(packJs.get<jsonxx::Number>("Id"));
        pack.date = packJs.get<jsonxx::String>("Date");
        pack.icon = packJs.get<jsonxx::String>("Icon");
        pack.cover = packJs.get<jsonxx::String>("Cover");
        pack.title = packJs.get<jsonxx::String>("Title");
        pack.text = packJs.get<jsonxx::String>("Text");
        
        auto imagesJs = packJs.get<jsonxx::Array>("Images");
        for (auto j = 0; j < imagesJs.size(); ++j) {
            auto imageJs = imagesJs.get<jsonxx::Object>(j);
            if (!imageJs.has<jsonxx::String>("Url")) {
                lwerror("json parse error: no Url");
                return;
            }
            if (!imageJs.has<jsonxx::String>("Title")) {
                lwerror("json parse error: no Title");
                return;
            }
            if (!imageJs.has<jsonxx::String>("Text")) {
                lwerror("json parse error: no Text");
                return;
            }
            Pack::Image image;
            image.url = imageJs.get<jsonxx::String>("Url");
            image.title = imageJs.get<jsonxx::String>("Title");
            image.text = imageJs.get<jsonxx::String>("Text");
            pack.images.push_back(image);
        }
        _packs.push_back(pack);
    }
    
    for (auto pack = _packs.begin(); pack != _packs.end(); ++pack) {
        
    }
}



