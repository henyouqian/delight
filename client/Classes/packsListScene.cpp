#include "packsListScene.h"
#include "modeSelectScene.h"
#include "util.h"
#include "http.h"
#include "db.h"
#include "lang.h"
#include "gifTexture.h"
#include "dragView.h"
#include "jsonxx/jsonxx.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

static const int PACKS_PER_PAGE = 12;
static const float THUMB_MARGIN = 5.f;
static const float HEADER_HEIGHT = 130.f;

PacksListScene* PacksListScene::createScene() {
    auto scene = Scene::create();
    auto layer = PacksListScene::create();
    scene->addChild(layer);
    return layer;
}

bool PacksListScene::init() {
    auto visSize = Director::getInstance()->getVisibleSize();
    
    if (!LayerColor::initWithColor(Color4B(10, 10, 10, 255)))  {
        return false;
    }
    this->setTouchEnabled(true);
    this->scheduleUpdate();
    
    //header
    auto headerBg = Sprite::create("ui/pt.png");
    headerBg->setScaleX(visSize.width);
    headerBg->setScaleY(HEADER_HEIGHT);
    headerBg->setAnchorPoint(Point(0.f, 1.f));
    headerBg->setPosition(Point(0.f, visSize.height));
    headerBg->setColor(Color3B(27, 27, 27));
    addChild(headerBg, 10);
    
    auto headerLine = Sprite::create("ui/pt.png");
    headerLine->setScaleX(visSize.width);
    headerLine->setScaleY(2);
    headerLine->setAnchorPoint(Point(0.f, 0.f));
    headerLine->setPosition(Point(0.f, visSize.height-HEADER_HEIGHT));
    headerLine->setColor(Color3B(10, 10, 10));
    addChild(headerLine, 10);
    
    //
    float y = visSize.height-70;
    
    //back button
    auto btnBack = createColorButton("〈", 56, 1.f, Color3B(240, 240, 240), Color3B(240, 240, 240), 0);
    btnBack->setTitleOffset(-14.f, 0.f);
    btnBack->setPosition(Point(70, y));
    btnBack->addTargetWithActionForControlEvents(this, cccontrol_selector(PacksListScene::back), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(btnBack, 10);
    
    //label
    auto title = LabelTTF::create(lang("Packs"), "HelveticaNeue", 44);
    title->setAnchorPoint(Point(.5f, .5f));
    title->setPosition(Point(visSize.width*.5f, y));
    title->setColor(Color3B(240, 240, 240));
    addChild(title, 10);
    
    //thumb
    _thumbWidth = (visSize.width-2.f*THUMB_MARGIN) / 3.f;
    _thumbHeight = _thumbWidth * 1.414f;
    
    //sptLoader
    _sptLoader = SptLoader::create(this);
    addChild(_sptLoader);
    
    //drag view
    _dragView = DragView::create();
    addChild(_dragView);
    float dragViewHeight = visSize.height - HEADER_HEIGHT;
    _dragView->setWindowRect(Rect(0, 0, visSize.width, dragViewHeight));
    
    //stars
    _starBatch = SpriteBatchNode::create("ui/star36.png");
    _dragView->addChild(_starBatch, 1);
    SpriteFrameCache::getInstance()->addSpriteFramesWithFile("ui/star36.plist");
    
    //lock
    _lockBatch = SpriteBatchNode::create("ui/lock.png");
    _dragView->addChild(_lockBatch, 2);
    
//    //get pack count
//    _packCount = 0;
//    _pageCount = 0;
//    postHttpRequest("pack/count", "", this, (SEL_HttpResponse)(&PacksListScene::onHttpGetCount));
    
    //loadPage(0);
    
    //
    _touch = nullptr;
    
    return true;
}

void PacksListScene::onEnter() {
    LayerColor::onEnter();
    
    _starBatch->removeAllChildren();
    _lockBatch->removeAllChildren();
    
    int packNum = _collection.packs.size();
    for (auto i = 0; i < packNum; ++i) {
        int row = i / 3;
        int col = i % 3;
        float w = _thumbWidth;
        float centerX = (w+THUMB_MARGIN)*col + .5f*w;
        float centerY = - ((_thumbHeight+THUMB_MARGIN)*row+.5f*_thumbHeight);
        
        //lock or star
        if (isLocked(i)) {
            auto sprLock = Sprite::create("ui/lock.png");
            sprLock->setPosition(Point(centerX, centerY));
            sprLock->setOpacity(150);
            sprLock->setScale(100.f/128.f);
            _lockBatch->addChild(sprLock);
        } else {
            //stars
            int starNum = CollectionStars::getInstance()->getStarNum(_collection.packs[i]);
            
            float dx = 35.f;
            float x = centerX - dx;
            float y = centerY -120.f;
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
    }
}

bool PacksListScene::isLocked(int idx) {
    if (idx == 0) {
        return false;
    }
    int starNum = CollectionStars::getInstance()->getStarNum(_collection.packs[idx]);
    int prevStarNum = CollectionStars::getInstance()->getStarNum(_collection.packs[idx-1]);
    if (starNum || prevStarNum) {
        return false;
    }
    return true;
}

PacksListScene::~PacksListScene() {
    _sptLoader->destroy();
}

void PacksListScene::loadCollection(CollectionInfo *collection) {
    _collection = *collection;
    
    //setup loading sprite
    int packNum = collection->packs.size();
    
    auto batch = SpriteBatchNode::create("ui/loading.png");
    _dragView->addChild(batch);
    
    //stars
    CollectionStars::getInstance()->load(_collection.id);
    
    for (auto i = 0; i < packNum; ++i) {
        auto loadingSpr = Sprite::create("ui/loading.png");
        batch->addChild(loadingSpr);
        loadingSpr->setUserData((void*)i);
        _thumbs.push_back(loadingSpr);
        int row = i / 3;
        int col = i % 3;
        float w = _thumbWidth;
        float x = (w+THUMB_MARGIN)*col + .5f*w;
        float y = - ((_thumbHeight+THUMB_MARGIN)*row+.5f*_thumbHeight);
        loadingSpr->setPosition(Point(x, y));
        loadingSpr->setScale(_thumbWidth/loadingSpr->getContentSize().width);
    }
    
    int rowNum = (packNum+2)/3;
    _dragView->setContentHeight(rowNum*(THUMB_MARGIN+1)+rowNum*_thumbHeight);
    
    //
    jsonxx::Object msg;
    msg << "Id" << collection->id;
    postHttpRequest("collection/listPack", msg.json().c_str(), this, (SEL_HttpResponse)(&PacksListScene::onHttpListPack));
}

void PacksListScene::onHttpListPack(HttpClient* client, HttpResponse* response) {
    std::string body;
    
    if (!response->isSucceed()) {
        lwerror("!response->isSucceed()");
        
        //load local
        sqlite3_stmt* pStmt = NULL;
        std::stringstream sql;
        sql << "SELECT value FROM collectionPacks WHERE id=" << _collection.id<< ";";
        auto r = sqlite3_prepare_v2(gSaveDb, sql.str().c_str(), -1, &pStmt, NULL);
        if (r != SQLITE_OK) {
            lwerror("sqlite error: %s", sql.str().c_str());
            return;
        }
        r = sqlite3_step(pStmt);
        if ( r == SQLITE_ROW ){
            const char* value = (const char*)sqlite3_column_text(pStmt, 0);
            if (value) {
                body = value;
            } else {
                lwerror("packs empty");
            }
        }
        sqlite3_finalize(pStmt);
    } else {
        getHttpResponseString(response, body);
        
        //sqlite
        std::stringstream sql;
        sql << "REPLACE INTO collectionPacks(id, value) VALUES(";
        sql << _collection.id << ",";
        sql << "'" << body << "');";
        char *err;
        auto r = sqlite3_exec(gSaveDb, sql.str().c_str(), NULL, NULL, &err);
        if(r != SQLITE_OK) {
            lwerror("sqlite error: %s\nsql=%s", err, sql.str().c_str());
        }
    }
    
    //load pack info
    getPacks().clear();
    
    jsonxx::Array msg;
    bool ok = msg.parse(body);
    if (!ok) {
        lwerror("json parse error: body=%s", body.c_str());
        return;
    }
    
    for (auto i = 0; i < msg.size(); ++i) {
        auto packJs = msg.get<jsonxx::Object>(i);
        PackInfo pack;
        pack.init(packJs);
        getPacks().push_back(pack);
        
        _sptLoader->download(pack.thumb.c_str(), (void*)i);
    }
}

void PacksListScene::back(Object *sender, Control::EventType controlEvent) {
    Director::getInstance()->popSceneWithTransition<TransitionFade>((Scene*)this->getParent(), .5f);
}

//void PacksListScene::onHttpGetCount(HttpClient* client, HttpResponse* response) {
//    _packCount = 0;
//    
//    if (!response->isSucceed()) {
//        _isOffline = true;
//        
//        //get pack count local
//        sqlite3_stmt* pStmt = NULL;
//        
//        std::stringstream sql;
//        sql << "SELECT value from kvs WHERE key='packCount';";
//        auto r = sqlite3_prepare_v2(gSaveDb, sql.str().c_str(), -1, &pStmt, NULL);
//        if (r != SQLITE_OK) {
//            lwerror("sqlite error: %s", sql.str().c_str());
//            return;
//        }
//        r = sqlite3_step(pStmt);
//        if ( r == SQLITE_ROW ){
//            const char * countString = (const char *)sqlite3_column_text(pStmt, 0);
//            _packCount = atoi(countString);
//        }
//        sqlite3_finalize(pStmt);
//    } else {
//        _isOffline = false;
//        
//        //get pack count
//        auto vData = response->getResponseData();
//        std::istringstream is(std::string(vData->begin(), vData->end()));
//        
//        jsonxx::Object root;
//        bool ok = root.parse(is);
//        if (!ok) {
//            lwerror("json parse error");
//            return;
//        }
//        if (!root.has<jsonxx::Number>("PackCount")) {
//            lwerror("json parse error: no number: Id");
//            return;
//        }
//        _packCount = root.get<jsonxx::Number>("PackCount");
//        
//        //save to sqlite
//        std::stringstream sql;
//        sql << "REPLACE INTO kvs(key, value) VALUES('packCount',";
//        sql << "'" << _packCount << "');";
//        char *err;
//        auto r = sqlite3_exec(gSaveDb, sql.str().c_str(), NULL, NULL, &err);
//        if(r != SQLITE_OK) {
//            lwerror("sqlite error: %s\nsql=%s", err, sql.str().c_str());
//        }
//    }
//    
//    _pageCount = (_packCount-1) / PACKS_PER_PAGE + 1;
//    _pageCount = MAX(_pageCount, 1);
//    
//    //load last page
//    loadPage(_pageCount-1);
//}

//void PacksListScene::loadPage(int page) {
//    TextureCache::getInstance()->removeUnusedTextures();
//    
//    _currPage = page;
//    
//    //
//    _packs.clear();
//    
//    //query packs info
//    int limit = PACKS_PER_PAGE*5;
//    jsonxx::Object msg;
//    msg << "UserId" << 0;
//    msg << "StartId" << 0;
//    msg << "Limit" << limit;
//    
//    postHttpRequest("pack/list", msg.json().c_str(), this, (SEL_HttpResponse)(&PacksListScene::onHttpGetPage));
//    
//    //setup loading sprite
//    int packNum = PACKS_PER_PAGE;
//    if (_currPage == _pageCount-1) {
//        packNum = _packCount % PACKS_PER_PAGE;
//        if (packNum == 0) {
//            packNum = PACKS_PER_PAGE;
//        }
//    }
//    
//    auto batch = SpriteBatchNode::create("ui/loading.png");
//    _dragView->addChild(batch);
//    
//    for (auto i = 0; i < packNum; ++i) {
//        auto loadingSpr = Sprite::create("ui/loading.png");
//        batch->addChild(loadingSpr);
//        loadingSpr->setUserData((void*)i);
//        _thumbs.push_back(loadingSpr);
//        int row = i / 3;
//        int col = i % 3;
//        float w = _thumbWidth;
//        float x = (w+THUMB_MARGIN)*col + .5f*w;
//        float y = - ((_thumbHeight+THUMB_MARGIN)*row+.5f*_thumbHeight);
//        loadingSpr->setPosition(Point(x, y));
//        loadingSpr->setScale(_thumbWidth/loadingSpr->getContentSize().width);
//        
//        //stars
//        auto starNum = rand()%4;
//        float dx = 35.f;
//        x -= dx;
//        y -= 120.f;
//        for (auto iStar = 0; iStar < 3; ++iStar) {
//            Sprite *sprStar;
//            if (iStar < starNum) {
//                sprStar = Sprite::createWithSpriteFrameName("star36Gold.png");
//            } else {
//                sprStar = Sprite::createWithSpriteFrameName("star36White.png");
//                sprStar->setOpacity(128);
//            }
//            sprStar->setPosition(Point(x, y));
//            _starBatch->addChild(sprStar);
//            x += dx;
//        }
//        
//    }
//    
//    //
//}

//static int makePageKey(int pageIdx) {
//    return pageIdx*100+PACKS_PER_PAGE;
//}

//void PacksListScene::onHttpGetPage(HttpClient* client, HttpResponse* response) {
//    int pageKey = makePageKey(_currPage);
//    std::string pageJs;
//    
//    if (!response->isSucceed()) {
//        //load local
//        sqlite3_stmt* pStmt = NULL;
//        std::stringstream sql;
//        sql << "SELECT value FROM pages WHERE key=" << pageKey << ";";
//        auto r = sqlite3_prepare_v2(gSaveDb, sql.str().c_str(), -1, &pStmt, NULL);
//        if (r != SQLITE_OK) {
//            lwerror("sqlite error: %s", sql.str().c_str());
//            return;
//        }
//        r = sqlite3_step(pStmt);
//        if ( r == SQLITE_ROW ){
//            const char* value = (const char*)sqlite3_column_text(pStmt, 0);
//            pageJs = value;
//        }
//        sqlite3_finalize(pStmt);
//    } else {
//        auto vData = response->getResponseData();
//        pageJs = std::string(vData->begin(), vData->end());
//        
//        //sqlite
//        std::stringstream sql;
//        sql << "REPLACE INTO pages(key, value) VALUES(";
//        sql << pageKey << ",";
//        sql << "'" << pageJs << "');";
//        char *err;
//        auto r = sqlite3_exec(gSaveDb, sql.str().c_str(), NULL, NULL, &err);
//        if(r != SQLITE_OK) {
//            lwerror("sqlite error: %s\nsql=%s", err, sql.str().c_str());
//        }
//    }
//    
//    _packs.clear();
//    
//    if (!pageJs.empty()) {
//        //parse json
//        std::istringstream is(pageJs);
//        
//        jsonxx::Array msg;
//        bool ok = msg.parse(is);
//        if (!ok) {
//            lwerror("json parse error");
//            return;
//        }
//        
//        for (auto i = 0; i < msg.size(); ++i) {
//            auto packJs = msg.get<jsonxx::Object>(i);
//            PackInfo pack;
//            pack.init(packJs);
//            _packs.push_back(pack);
//            
//            _sptLoader->download(pack.thumb.c_str(), (void*)i);
//        }
//    }
//}

void PacksListScene::onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData) {
    int idx = (int)userData;
    if (idx >= 0 && idx < _thumbs.size()) {
        _dragView->addChild(sprite);
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

void PacksListScene::onSptLoaderError(const char *localPath, void *userData) {
    lwerror("sprite load error");
    //fixme:
}

void PacksListScene::onTouchesBegan(const std::vector<Touch*>& touches, Event *event) {
    if (_touch){
        return;
    }
    auto touch = touches[0];
    _touch = touch;
    
    _dragView->onTouchesBegan(touch);
}

void PacksListScene::onTouchesMoved(const std::vector<Touch*>& touches, Event *event) {
    auto touch = touches[0];
    if (touch != _touch) {
        return;
    }
    _dragView->onTouchesMoved(touch);
}

void PacksListScene::onTouchesEnded(const std::vector<Touch*>& touches, Event *event) {
    auto touch = touches[0];
    if (touch != _touch) {
        return;
    }
    _touch = nullptr;
    
    if (!_dragView->isDragging() && _dragView->getWindowRect().containsPoint(touch->getLocation())) {
        for( int i = 0; i < _thumbs.size(); i++){
            if (!isLocked(i) && i < getPacks().size() ) {
                auto thumb = _thumbs[i];
                auto rect = thumb->getBoundingBox();
                rect.origin.y += _dragView->getPositionY();
                if (rect.containsPoint(touch->getLocation())) {
                    auto scene = ModeSelectScene::createScene(i);
                    Director::getInstance()->pushScene(TransitionFade::create(0.5f, scene));
                    break;
                }
            }
        }
    }
    
    _dragView->onTouchesEnded(touch);
}

void PacksListScene::onTouchesCancelled(const std::vector<Touch*>&touches, Event *event) {
    onTouchesEnded(touches, event);
}

