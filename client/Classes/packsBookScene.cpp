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
static const float THUMB_MARGIN = 5.f;
static const float THUMB_Y0 = 130.f;

Scene* PacksBookScene::createScene() {
    auto scene = Scene::create();
    auto layer = PacksBookScene::create();
    scene->addChild(layer);
    return scene;
}

bool PacksBookScene::init() {
    showStatusBar(true);
    auto visSize = Director::getInstance()->getVisibleSize();
    
    if (!LayerColor::initWithColor(Color4B(10, 10, 10, 255)))  {
        return false;
    }
    this->setTouchEnabled(true);
    this->scheduleUpdate();
    
    //back button
    auto btnBack = createRingButton("﹤", 48, 1.f, Color3B(0, 122, 255));
    btnBack->setPosition(Point(70, 70));
    btnBack->addTargetWithActionForControlEvents(this, cccontrol_selector(PacksBookScene::back), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(btnBack);
    
    //header
    auto headerBg = Sprite::create("ui/pt.png");
    headerBg->setScaleX(visSize.width);
    headerBg->setScaleY(128);
    headerBg->setAnchorPoint(Point(0.f, 1.f));
    headerBg->setPosition(Point(0.f, visSize.height));
    headerBg->setColor(Color3B(27, 27, 27));
    addChild(headerBg);
    
    //
    float y = visSize.height-70;
    
    //older
    auto label = LabelTTF::create("〈", "HelveticaNeue", 64);
    label->setColor(Color3B(240, 240, 240));
    auto btn = ControlButton::create(label, Scale9Sprite::create());
    btn->setAnchorPoint(Point(0.f, 0.5f));
    btn->setPosition(Point(10.f, y));
    addChild(btn);
    
    //label
    auto title = LabelTTF::create(lang("Packs"), "HelveticaNeue", 44);
    title->setAnchorPoint(Point(.5f, .5f));
    title->setPosition(Point(visSize.width*.5f, y));
    title->setColor(Color3B(240, 240, 240));
    addChild(title);
    
    _thumbWidth = (visSize.width-2.f*THUMB_MARGIN) / 3.f;
    _thumbHeight = _thumbWidth * 1.414f;
    
    //sptLoader
    _sptLoader = SptLoader::create(this);
    addChild(_sptLoader);
    
    //iconsParent
    _thumbsParent = Node::create();
    addChild(_thumbsParent);
    
    //stars
    _starBatch = SpriteBatchNode::create("ui/star36.png");
    this->addChild(_starBatch, 10);
    SpriteFrameCache::getInstance()->addSpriteFramesWithFile("ui/star36.plist");
    
//    //get pack count
//    _packCount = 0;
//    _pageCount = 0;
//    postHttpRequest("pack/count", "", this, (SEL_HttpResponse)(&PacksBookScene::onHttpGetCount));
    
    loadPage(0);
    
    return true;
}

PacksBookScene::~PacksBookScene() {
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
    
    //
    _packs.clear();
    
    //query packs info
    int limit = PACKS_PER_PAGE*5;
    jsonxx::Object msg;
    msg << "UserId" << 0;
    msg << "StartId" << 0;
    msg << "Limit" << limit;
    
    postHttpRequest("pack/list", msg.json().c_str(), this, (SEL_HttpResponse)(&PacksBookScene::onHttpGetPage));
    
    //setup loading sprite
    int packNum = PACKS_PER_PAGE;
    if (_currPage == _pageCount-1) {
        packNum = _packCount % PACKS_PER_PAGE;
        if (packNum == 0) {
            packNum = PACKS_PER_PAGE;
        }
    }
    
    auto batch = SpriteBatchNode::create("ui/loading.png");
    _thumbsParent->addChild(batch);
    
    for (auto i = 0; i < packNum; ++i) {
        auto loadingSpr = Sprite::create("ui/loading.png");
        batch->addChild(loadingSpr);
        loadingSpr->setUserData((void*)i);
        _thumbs.push_back(loadingSpr);
        int row = i / 3;
        int col = i % 3;
        auto visSize = Director::getInstance()->getVisibleSize();
        float w = _thumbWidth;
        float x = (w+THUMB_MARGIN)*col + .5f*w;
        float y = visSize.height - ((_thumbHeight+THUMB_MARGIN)*row+.5f*_thumbHeight) - THUMB_Y0;
        loadingSpr->setPosition(Point(x, y));
        loadingSpr->setScale(_thumbWidth/loadingSpr->getContentSize().width);
        
        //stars
        auto starNum = rand()%4;
        float dx = 35.f;
        x -= dx;
        y -= 120.f;
        for (auto iStar = 0; iStar < 3; ++iStar) {
            Sprite *sprStar;
            if (iStar < starNum) {
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
        
        jsonxx::Array msg;
        bool ok = msg.parse(is);
        if (!ok) {
            lwerror("json parse error");
            return;
        }
        
        for (auto i = 0; i < msg.size(); ++i) {
            auto packJs = msg.get<jsonxx::Object>(i);
            PackInfo pack;
            pack.init(packJs);
            _packs.push_back(pack);
            
            _sptLoader->download(pack.thumb.c_str(), (void*)i);
        }
    }
}

void PacksBookScene::onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData) {
    int idx = (int)userData;
    if (idx >= 0 && idx < _thumbs.size()) {
        _thumbsParent->addChild(sprite);
        sprite->setPosition(_thumbs[idx]->getPosition());
        //sprite->setScale(_iconWidth/sprite->getContentSize().width);
        sprite->setUserData((void*)idx);
        _thumbs[idx]->removeFromParent();
        _thumbs[idx] = sprite;
        
//        auto size = sprite->getContentSize();
//        auto shortEdge = MIN(size.width, size.height);
//        sprite->setScale(_iconWidth/shortEdge);
//        sprite->setTextureRect(Rect((size.width-shortEdge)*.5f, (size.height-shortEdge)*.5f, shortEdge, shortEdge));
        
        auto size = sprite->getContentSize();
        auto scaleW = _thumbWidth/size.width;
        auto scaleH = _thumbHeight/size.height;
        auto scale = MAX(scaleW, scaleH);
        float uvw = size.width;
        float uvh = size.height;
        if (scaleW <= scaleH) {
            uvw = size.height * _thumbWidth/_thumbHeight;
        } else {
            uvh = size.width * _thumbHeight/_thumbWidth;
        }
        sprite->setScale(scale);
        sprite->setTextureRect(Rect((size.width-uvw)*.5f, (size.height-uvh)*.5f, uvw, uvh));
        
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
    for( int i = 0; i < _thumbs.size(); i++){
        auto thumb = _thumbs[i];
        auto rect = thumb->getBoundingBox();
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

