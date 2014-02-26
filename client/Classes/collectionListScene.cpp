#include "collectionListScene.h"
#include "dragView.h"
#include "lang.h"
#include "http.h"
#include "util.h"
#include "packsListScene.h"
#include "db.h"
#include "jsonxx/jsonxx.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

static const float HEADER_HEIGHT = 130.f;
static const float THUMB_MARGIN = 10.f;

CollectionListScene* CollectionListScene::createScene() {
    auto scene = Scene::create();
    auto layer = CollectionListScene::create();
    scene->addChild(layer);
    layer->scene = scene;
    return layer;
}

CollectionListScene::~CollectionListScene() {
    _sptLoader->destroy();
}

bool CollectionListScene::init() {
    if ( !Layer::init() ) {
        return false;
    }
    _touch = nullptr;
    this->setTouchEnabled(true);
    
    auto visSize = Director::getInstance()->getVisibleSize();
    
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
    
    //label
    float y = visSize.height-70;
    
    auto title = LabelTTF::create(lang("Collections"), "HelveticaNeue", 44);
    title->setAnchorPoint(Point(.5f, .5f));
    title->setPosition(Point(visSize.width*.5f, y));
    title->setColor(Color3B(240, 240, 240));
    addChild(title, 10);
    
    //thumb
    _thumbWidth = visSize.width - THUMB_MARGIN*2.f;
    _thumbHeight = _thumbWidth * 0.4f;
    
    //back button
    auto btnBack = createColorButton("〈", 56, 1.f, Color3B(240, 240, 240), Color3B(240, 240, 240), 0);
    btnBack->setTitleOffset(-14.f, 0.f);
    btnBack->setPosition(Point(70, y));
    btnBack->addTargetWithActionForControlEvents(this, cccontrol_selector(CollectionListScene::back), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(btnBack, 10);
    
    //drag view
    _dragView = DragView::create();
    addChild(_dragView);
    float dragViewHeight = visSize.height - HEADER_HEIGHT;
    _dragView->setWindowRect(Rect(0, 0, visSize.width, dragViewHeight));
    //_dragView->setContentHeight(1800.f);
    
    //sptLoader
    _sptLoader = SptLoader::create(this);
    addChild(_sptLoader);
    
    //get collection list
    jsonxx::Object msg;
    msg << "UserId" << 0;
    msg << "StartId" << 0;
    msg << "Limit" << 20;
    
    postHttpRequest("collection/list", msg.json().c_str(), this, (SEL_HttpResponse)(&CollectionListScene::onHttpListCollection));
    
    return true;
}

void CollectionListScene::back(Object *sender, Control::EventType controlEvent) {
    Director::getInstance()->popSceneWithTransition<TransitionFade>((Scene*)getParent(), .5f);
}

void CollectionListScene::onHttpListCollection(HttpClient* client, HttpResponse* response) {
    jsonxx::Array msg;
    if (!response->isSucceed()) {
        //load local
        sqlite3_stmt* pStmt = NULL;
        std::stringstream sql;
        sql << "SELECT value FROM collections;";
        auto r = sqlite3_prepare_v2(gSaveDb, sql.str().c_str(), -1, &pStmt, NULL);
        if (r != SQLITE_OK) {
            lwerror("sqlite error: %s", sql.str().c_str());
            return;
        }
        while (sqlite3_step(pStmt) == SQLITE_ROW ){
            jsonxx::Object coljs;
            auto v = (const char*)sqlite3_column_text(pStmt, 0);
            string str;
            if (v) {
                str = v;
            }
            coljs.parse(str);
            msg << coljs;
        }
        sqlite3_finalize(pStmt);
    } else {
        //parse response
        std::string body;
        getHttpResponseString(response, body);
        bool ok = msg.parse(body);
        if (!ok) {
            lwerror("json parse error");
            return;
        }
        
        for (auto i = 0; i < msg.size(); ++i) {
            auto coljs = msg.get<jsonxx::Object>(i);
            
            if (!coljs.has<jsonxx::Number>("Id")) {
                lwerror("json invalid, need id");
                return;
            }
        }
        
        //del db
        std::stringstream sql;
        sql << "DELETE FROM collections;";
        char *err;
        auto r = sqlite3_exec(gSaveDb, sql.str().c_str(), NULL, NULL, &err);
        if(r != SQLITE_OK) {
            lwerror("sqlite error: %s\nsql=%s", err, sql.str().c_str());
        }
    }
    
    //parse collection and load thumbs
    for (auto i = 0; i < msg.size(); ++i) {
        auto coljs = msg.get<jsonxx::Object>(i);
        
        if (!coljs.has<jsonxx::Number>("Id")
            || !coljs.has<jsonxx::String>("Title")
            || !coljs.has<jsonxx::String>("Text")
            || !coljs.has<jsonxx::String>("Thumb")
            || !coljs.has<jsonxx::Array>("Packs")) {
            lwerror("json invalid");
            return;
        }
        CollectionInfo col;
        col.id = (uint64_t)coljs.get<jsonxx::Number>("Id");
        col.title = coljs.get<jsonxx::String>("Title");
        col.text = coljs.get<jsonxx::String>("Text");
        col.thumb = coljs.get<jsonxx::String>("Thumb");
        auto packsjs = coljs.get<jsonxx::Array>("Packs");
        
        for (auto j = 0; j < packsjs.size(); ++j) {
            auto packId = (uint64_t)packsjs.get<jsonxx::Number>(j);
            col.packs.push_back(packId);
        }
        _collections.push_back(col);
        _sptLoader->download(col.thumb.c_str(), (void*)i);
        
        if (response->isSucceed()) {
            //save to sqlite
            std::stringstream sql;
            sql << "REPLACE INTO collections(id, value) VALUES(";
            sql << col.id << ",";
            sql << "'" << coljs.json() << "');";
            char *err;
            auto r = sqlite3_exec(gSaveDb, sql.str().c_str(), NULL, NULL, &err);
            if(r != SQLITE_OK) {
                lwerror("sqlite error: %s\nsql=%s", err, sql.str().c_str());
            }
        }
        
        //thumbs
        auto thumb = Sprite::create("ui/loadingWide.png");
        _thumbs.push_back(thumb);
        _dragView->addChild(thumb);
        thumb->setAnchorPoint(Point(0.f, 1.f));
        float thumbX = THUMB_MARGIN;
        float thumbY = -(THUMB_MARGIN+_thumbHeight)*i;
        thumb->setPosition(Point(thumbX, thumbY));
        
        //resize thumbs
        auto size = thumb->getContentSize();
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
        thumb->setScale(scale);
        thumb->setTextureRect(Rect((size.width-uvw)*.5f, (size.height-uvh)*.5f, uvw, uvh));
        
        //titles
        auto label = LabelTTF::create(col.title.c_str(), "HelveticaNeue", 36);
        label->enableShadow(Size(2, -2), .6f, 1.f);
        label->setAnchorPoint(Point(0.f, 1.f));
        label->setPosition(Point(thumbX + 10, thumbY-10));
        label->setColor(Color3B(240, 240, 240));
        _dragView->addChild(label, 1);
    }
}

void CollectionListScene::onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData) {
    int i = (int)userData;
    sprite->setAnchorPoint(Point(0.f, 1.f));
    sprite->setPosition(Point(THUMB_MARGIN, -(THUMB_MARGIN+_thumbHeight)*i));
    _dragView->addChild(sprite);
    _thumbs[i] = sprite;
    _dragView->setContentHeight((THUMB_MARGIN+_thumbHeight)*i+THUMB_MARGIN);
    
    //resize
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
}

void CollectionListScene::onSptLoaderError(const char *localPath, void *userData) {
    
}

void CollectionListScene::onTouchesBegan(const std::vector<Touch*>& touches, Event *event) {
    if (_touch){
        return;
    }
    auto touch = touches[0];
    _touch = touch;
    
    _dragView->onTouchesBegan(touch);
}

void CollectionListScene::onTouchesMoved(const std::vector<Touch*>& touches, Event *event) {
    auto touch = touches[0];
    if (touch != _touch) {
        return;
    }
    _dragView->onTouchesMoved(touch);
}

void CollectionListScene::onTouchesEnded(const std::vector<Touch*>& touches, Event *event) {
    auto touch = touches[0];
    if (touch != _touch) {
        return;
    }
    _touch = nullptr;
    
    if (!_dragView->isDragging() && _dragView->getWindowRect().containsPoint(touch->getLocation())) {
        for( int i = 0; i < _thumbs.size(); i++){
            auto thumb = _thumbs[i];
            auto rect = thumb->getBoundingBox();
            rect.origin.y += _dragView->getPositionY();
            if (rect.containsPoint(touch->getLocation())) {
                if (i < _collections.size()) {
                    auto layer = PacksListScene::createScene();
                    layer->loadCollection(&_collections[i]);
                    Director::getInstance()->pushScene(TransitionFade::create(0.5f, (Scene*)layer->getParent()));
                    
                }
                break;
            }
        }
    }
    _dragView->onTouchesEnded(touch);
}

void CollectionListScene::onTouchesCancelled(const std::vector<Touch*>&touches, Event *event) {
    onTouchesEnded(touches, event);
}
