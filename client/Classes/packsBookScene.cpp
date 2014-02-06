#include "packsBookScene.h"
#include "modeSelectScene.h"
#include "util.h"
#include "http.h"
#include "db.h"
#include "lang.h"
#include "gifTexture.h"
#include "jsonxx/jsonxx.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

static const int PACKS_PER_PAGE = 12;
static const float ICON_MARGIN = 5.f;
static const float ICON_Y0 = 130.f;

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
    
    //
    float y = visSize.height-70;
    
    //older
    auto label = LabelTTF::create("〈", "HelveticaNeue", 64);
    label->setColor(Color3B(0, 122, 255));
    auto btn = ControlButton::create(label, Scale9Sprite::create());
    btn->setAnchorPoint(Point(0.f, 0.5f));
    btn->setPosition(Point(10.f, y));
    addChild(btn);
    
    //newer
    label = LabelTTF::create("〉", "HelveticaNeue", 64);
    label->setColor(Color3B(0, 122, 255));
    btn = ControlButton::create(label, Scale9Sprite::create());
    btn->setAnchorPoint(Point(1.f, 0.5f));
    btn->setPosition(Point(visSize.width-10, y));
    addChild(btn);
    
    //page
    _pageLabel = LabelTTF::create(lang("Connecting..."), "HelveticaNeue", 44);
    _pageLabel->setAnchorPoint(Point(.5f, .5f));
    _pageLabel->setPosition(Point(visSize.width*.5f, y));
    _pageLabel->setColor(Color3B(255, 59, 48));
    addChild(_pageLabel);
    
    //line
    auto line = Sprite::create("ui/pt.png");
    line->setScaleX(visSize.width);
    line->setAnchorPoint(Point(0.f, 0.f));
    line->setPosition(Point(0.f, visSize.height - ICON_Y0+5));
    line->setColor(Color3B(168, 168, 168));
    addChild(line, 1);
    
    line = Sprite::create("ui/pt.png");
    line->setScaleX(visSize.width);
    line->setAnchorPoint(Point(0.f, 1.f));
    _iconWidth = (visSize.width-2.f*ICON_MARGIN) / 3.f;
    line->setPosition(Point(0.f, visSize.height - ICON_Y0 - 4*_iconWidth - 3*ICON_MARGIN-5));
    line->setColor(Color3B(168, 168, 168));
    addChild(line, 1);
    
    //loading texture
    _loadingTexture = GifTexture::create("ui/loading.gif", this, false);
    _loadingTexture->retain();
    //_loadingTexture->setSpeed(2.f);
    
    //get pack count
    _packCount = 0;
    _pageCount = 0;
    postHttpRequest("pack/count", "", this, (SEL_HttpResponse)(&PacksBookScene::onHttpGetCount));
    
    //sptLoader
    _sptLoader = SptLoader::create(this);
    addChild(_sptLoader);
    
    //iconsParent
    _iconsParent = Node::create();
    addChild(_iconsParent);
    
    //stars
    _starBatch = SpriteBatchNode::create("ui/star36.png");
    this->addChild(_starBatch, 10);
    SpriteFrameCache::getInstance()->addSpriteFramesWithFile("ui/star36.plist");
    
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
    _packCount = 0;
    
    if (!response->isSucceed()) {
        _isOffline = true;
        
        //get pack count local
        sqlite3_stmt* pStmt = NULL;
        
        std::stringstream sql;
        sql << "SELECT value from kvs WHERE key='packCount';";
        auto r = sqlite3_prepare_v2(gSaveDb, sql.str().c_str(), -1, &pStmt, NULL);
        if (r != SQLITE_OK) {
            lwerror("sqlite error: %s", sql.str().c_str());
            return;
        }
        r = sqlite3_step(pStmt);
        if ( r == SQLITE_ROW ){
            const char * countString = (const char *)sqlite3_column_text(pStmt, 0);
            _packCount = atoi(countString);
        }
        sqlite3_finalize(pStmt);
    } else {
        _isOffline = false;
        
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
        
        //save to sqlite
        std::stringstream sql;
        sql << "REPLACE INTO kvs(key, value) VALUES('packCount',";
        sql << "'" << _packCount << "');";
        char *err;
        auto r = sqlite3_exec(gSaveDb, sql.str().c_str(), NULL, NULL, &err);
        if(r != SQLITE_OK) {
            lwerror("sqlite error: %s\nsql=%s", err, sql.str().c_str());
        }
    }
    
    _pageCount = (_packCount-1) / PACKS_PER_PAGE + 1;
    _pageCount = MAX(_pageCount, 1);
    
    //load last page
    loadPage(_pageCount-1);
}

void PacksBookScene::loadPage(int page) {
    TextureCache::getInstance()->removeUnusedTextures();
    
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
    
    postHttpRequest("pack/get", msg.json().c_str(), this, (SEL_HttpResponse)(&PacksBookScene::onHttpGetPage));
    
    //setup loading sprite
    int packNum = PACKS_PER_PAGE;
    if (_currPage == _pageCount-1) {
        packNum = _packCount % PACKS_PER_PAGE;
    }
    
    for (auto i = 0; i < packNum; ++i) {
        auto loadingSpr = Sprite::createWithTexture(_loadingTexture);
        _iconsParent->addChild(loadingSpr);
        loadingSpr->setUserData((void*)i);
        _icons.push_back(loadingSpr);
        int row = i / 3;
        int col = i % 3;
        auto visSize = Director::getInstance()->getVisibleSize();
        float w = _iconWidth;
        float x = (w+ICON_MARGIN)*col + .5f*w;
        float y = visSize.height - ((w+ICON_MARGIN)*row+.5f*w) - ICON_Y0;
        loadingSpr->setPosition(Point(x, y));
        loadingSpr->setScale(2.f);
    }
    
    //
}

static int makePageKey(int pageIdx) {
    return pageIdx*100+PACKS_PER_PAGE;
}

void PacksBookScene::onHttpGetPage(HttpClient* client, HttpResponse* response) {
    int pageKey = makePageKey(_currPage);
    std::string pageJs;
    
    if (!response->isSucceed()) {
        //load local
        sqlite3_stmt* pStmt = NULL;
        std::stringstream sql;
        sql << "SELECT value FROM pages WHERE key=" << pageKey << ";";
        auto r = sqlite3_prepare_v2(gSaveDb, sql.str().c_str(), -1, &pStmt, NULL);
        if (r != SQLITE_OK) {
            lwerror("sqlite error: %s", sql.str().c_str());
            return;
        }
        r = sqlite3_step(pStmt);
        if ( r == SQLITE_ROW ){
            const char* value = (const char*)sqlite3_column_text(pStmt, 0);
            pageJs = value;
        }
        sqlite3_finalize(pStmt);
    } else {
        auto vData = response->getResponseData();
        pageJs = std::string(vData->begin(), vData->end());
        
        //sqlite
        std::stringstream sql;
        sql << "REPLACE INTO pages(key, value) VALUES(";
        sql << pageKey << ",";
        sql << "'" << pageJs << "');";
        char *err;
        auto r = sqlite3_exec(gSaveDb, sql.str().c_str(), NULL, NULL, &err);
        if(r != SQLITE_OK) {
            lwerror("sqlite error: %s\nsql=%s", err, sql.str().c_str());
        }
    }
    
    _packs.clear();
    
    if (!pageJs.empty()) {
        //parse json
        std::istringstream is(pageJs);
        
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
            PackInfo pack;
            pack.init(packJs);
            _packs.push_back(pack);
            
            _sptLoader->download(pack.icon.c_str(), (void*)i);
            
            //stars
            auto icon = _icons[i];
            float x = icon->getPositionX();
            float y = icon->getPositionY();
            
            float dx = 35.f;
            x -= dx;
            y -= 80.f;
            for (auto iStar = 0; iStar < 3; ++iStar) {
                Sprite *sprStar;
                if (iStar < pack.star) {
                    sprStar = Sprite::createWithSpriteFrameName("star36Gold.png");
                } else {
                    sprStar = Sprite::createWithSpriteFrameName("star36White.png");
                    sprStar->setOpacity(128);
                }
                sprStar->setPosition(Point(x, y));
                _starBatch->addChild(sprStar);
                x += dx;
            }
        }
    }
}

void PacksBookScene::onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData) {
    int idx = (int)userData;
    if (idx >= 0 && idx < _icons.size()) {
        _iconsParent->addChild(sprite);
        sprite->setPosition(_icons[idx]->getPosition());
        auto size = sprite->getContentSize();
        auto len = MIN(size.width, size.height);
        auto u = (size.width - len) * .5f;
        auto v = (size.height - len) * .5f;
        sprite->setScale(_iconWidth/len);
        sprite->setTextureRect(Rect(u, v, len, len));
        sprite->setUserData((void*)idx);
        _icons[idx]->removeFromParent();
        _icons[idx] = sprite;
    } else {
        lwerror("no loading sprite to replace");
    }
}

void PacksBookScene::onSptLoaderError(const char *localPath, void *userData) {
    lwerror("sprite load error");
    //fixme:
}

void PacksBookScene::onTouchesBegan(const std::vector<Touch*>& touches, Event *event) {
    auto touch = touches[0];
    
    _touchedRect = Rect::ZERO;
    _touchedPack = nullptr;
    for( int i = 0; i < _icons.size(); i++){
        auto icon = _icons[i];
        auto rect = icon->getBoundingBox();
        //rect.origin.y += _sptParent->getPositionY();
        if (rect.containsPoint(touch->getLocation())) {
            if (i < _packs.size()) {
                _touchedRect = rect;
                _touchedPack = &(_packs[i]);
            }
            break;
        }
    }
}

void PacksBookScene::onTouchesMoved(const std::vector<Touch*>& touches, Event *event) {
    
}

void PacksBookScene::onTouchesEnded(const std::vector<Touch*>& touches, Event *event) {
    auto touch = touches[0];
    if (_touchedPack) {
        if (_touchedRect.containsPoint(touch->getLocation())) {
            auto scene = ModeSelectScene::createScene(_touchedPack);
            Director::getInstance()->pushScene(TransitionFade::create(0.5f, scene));
        }
    }
}

void PacksBookScene::onTouchesCancelled(const std::vector<Touch*>&touches, Event *event) {
    //fixme
}

