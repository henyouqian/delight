#include "collectionListScene.h"
#include "matchListScene.h"
#include "dragView.h"
#include "lang.h"
#include "http.h"
#include "util.h"
#include "packsListScene.h"
#include "db.h"
#include "menuBar.h"
#include "jsonxx/jsonxx.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

static const float HEADER_HEIGHT = 130.f;
static const float THUMB_MARGIN = 10.f;
static const float MENUBAR_HEIGHT = 100.f;

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
    auto btnBack = createColorButton("〈", FORWARD_BACK_FONT_SIZE, 1.f, Color3B(240, 240, 240), Color3B(240, 240, 240), 0);
    btnBack->setTitleOffset(-FORWARD_BACK_FONT_OFFSET, 0.f);
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
    Director::getInstance()->popSceneWithTransition<TransitionFade>((Scene*)getParent()->getParent(), .5f);
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

//========================================

bool SearchLayer::init() {
    if (!Layer::init()) {
        return false;
    }
    _thumbNum = 0;
    _dragViewHeight = 0.f;
    _minPackId = std::numeric_limits<uint64_t>::max();
    
    auto visSize = EGLView::getInstance()->getVisibleSize();
    auto editBoxSize = Size(visSize.width - 100, 60);
    
    _editSearch = EditBox::create(editBoxSize, Scale9Sprite::create("ui/pt.png"));
    _editSearch->setPosition(Point(visSize.width*.5f, visSize.height));
    _editSearch->setAnchorPoint(Point(.5f, 1));
    _editSearch->setFontSize(25);
    _editSearch->setFontColor(Color3B(10, 10, 10));
    _editSearch->setPlaceHolder("Tag:");
    _editSearch->setPlaceholderFontColor(Color3B::GRAY);
    _editSearch->setMaxLength(20);
    _editSearch->setReturnType(EditBox::KeyboardReturnType::SEARCH);
    _editSearch->setDelegate(this);
    addChild(_editSearch, 1);
    
    //thumb
    _thumbWidth = (visSize.width-2.f*THUMB_MARGIN) / 3.f;
    _thumbHeight = _thumbWidth * 1.414f;
    
    //sptLoader
    _sptLoader = SptLoader::create(this);
    addChild(_sptLoader);
    
    //drag view
    _dragView = DragView::create();
    addChild(_dragView);
    float dragViewHeight = visSize.height - HEADER_HEIGHT - MENUBAR_HEIGHT;
    _dragView->setWindowRect(Rect(0, MENUBAR_HEIGHT, visSize.width, dragViewHeight));
    
    return true;
}

void SearchLayer::editBoxReturn(EditBox* editBox) {
    if (editBox->ignoreKeyboardReturn()) {
        return;
    }
    _thumbNum = 0;
    _dragViewHeight = 0;
    _minPackId = std::numeric_limits<uint64_t>::max();
    _dragView->setContentHeight(0);
    _dragView->removeAllChildren();
    _dragView->resetY();
    
    //
    std::string text = editBox->getText();
    if (text.empty()) {
        return;
    }
    jsonxx::Object obj;
    obj << "Tag" << text;
    obj << "StartId" << 0;
    obj << "Limit" << 12;
    lwinfo("%s", obj.json().c_str());
    HttpClient::getInstance()->cancelAllRequest();
    postHttpRequest("pack/listByTag", obj.json().c_str(), this, (SEL_HttpResponse)(&SearchLayer::onHttpListByTag));
}

void SearchLayer::onHttpListByTag(HttpClient* client, HttpResponse* response) {
    std::string body;
    getHttpResponseString(response, body);
    
    if (!response->isSucceed()) {
        lwerror("onHttpListByTag error");
        lwerror("%s", body.c_str());
        return;
    } else {
        //parse response
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
            
            _sptLoader->download(pack.cover.c_str(), (void*)i);
            _minPackId = MIN(pack.id, _minPackId);
        }
    }
}

void SearchLayer::onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData) {
    //    auto idx = _thumbNum;
    //    _dragView->addChild(sprite);
    //    _thumbNum++;
    //
    //    int row = idx / 3;
    //    int col = idx % 3;
    //    float w = _thumbWidth;
    //    float x = (w+THUMB_MARGIN)*col + .5f*w;
    //    float y = - ((_thumbHeight+THUMB_MARGIN)*row+.5f*_thumbHeight);
    //    sprite->setPosition(Point(x, y));
    //
    //    auto size = sprite->getContentSize();
    //    auto scaleW = _thumbWidth/size.width;
    //    auto scaleH = _thumbHeight/size.height;
    //    auto scale = MAX(scaleW, scaleH);
    //    float uvw = size.width;
    //    float uvh = size.height;
    //    if (scaleW <= scaleH) {
    //        uvw = size.height * _thumbWidth/_thumbHeight;
    //    } else {
    //        uvh = size.width * _thumbHeight/_thumbWidth;
    //    }
    //    sprite->setScale(scale);
    //    sprite->setTextureRect(Rect((size.width-uvw)*.5f, (size.height-uvh)*.5f, uvw, uvh));
    //
    //    //
    //    _dragView->setContentHeight(row*(THUMB_MARGIN+1)+row*_thumbHeight);
    //
    
    sprite->setAnchorPoint(Point(.5f, 1.f));
    _dragView->addChild(sprite);
    _thumbNum++;
    
    //    float w = _thumbWidth;
    float margin = 10.f;
    float w = Director::getInstance()->getVisibleSize().width-margin*2.f;
    float x = margin + .5f*w;
    float y = -_dragViewHeight;
    sprite->setPosition(Point(x, y));
    
    auto size = sprite->getContentSize();
    auto scale = w/size.width;
    sprite->setScale(scale);
    
    
    //
    _dragViewHeight += size.height * scale + margin;
    _dragView->setContentHeight(_dragViewHeight+40);
}

void SearchLayer::onSptLoaderError(const char *localPath, void *userData) {
    lwerror("SearchLayer::onSptLoaderError");
}

//touch
void SearchLayer::onTouchesBegan(const std::vector<Touch*>& touches, Event *event) {
    auto touch = touches[0];
    
    _editSearch->closeKeyboard();
    _dragView->onTouchesBegan(touch);
}

void SearchLayer::onTouchesMoved(const std::vector<Touch*>& touches, Event *event) {
    auto touch = touches[0];
    _dragView->onTouchesMoved(touch);
}

void SearchLayer::onTouchesEnded(const std::vector<Touch*>& touches, Event *event) {
    auto touch = touches[0];
    if (_dragView->beyondBottom()) {
        std::string text = _editSearch->getText();
        if (text.empty()) {
            return;
        }
        jsonxx::Object obj;
        obj << "Tag" << text;
        obj << "StartId" << _minPackId;
        obj << "Limit" << 12;
        lwinfo("%s", obj.json().c_str());
        HttpClient::getInstance()->cancelAllRequest();
        postHttpRequest("pack/listByTag", obj.json().c_str(), this, (SEL_HttpResponse)(&SearchLayer::onHttpListByTag));
        
    }
    _dragView->onTouchesEnded(touch);
}

void SearchLayer::onTouchesCancelled(const std::vector<Touch*>&touches, Event *event) {
    onTouchesEnded(touches, event);
}

//========================================

MainContainerLayer* MainContainerLayer::create() {
    MainContainerLayer *p = new MainContainerLayer();
    if (p && p->init()) {
        p->autorelease();
        return p;
    }
    CC_SAFE_DELETE(p);
    return nullptr;
}

bool MainContainerLayer::init() {
    if (!Layer::init()) {
        return false;
    }
    this->setTouchEnabled(true);
    auto visSize = Director::getInstance()->getVisibleSize();
    
    //layers
    _layers[0] = CollectionListScene::create();
    this->addChild(_layers[0]);
    _layers[1] = SearchLayer::create();
    this->addChild(_layers[1]);
    _layers[2] = MatchListLayer::create();
    this->addChild(_layers[2]);
    _layers[3] = nullptr;
    
    //menu bar
    auto menuBar = MenuBar::create(this);
    menuBar->setPosition(Point(0, 0));
    menuBar->setAnchorPoint(Point(0, 0));
    menuBar->setContentSize(Size(visSize.width, 100.f));
    ((LayerRGBA*)menuBar)->setColor(Color3B(27, 27, 27));
    ((LayerRGBA*)menuBar)->setOpacity(255);
    this->addChild(menuBar, 111);
    
    menuBar->addElem("ui/glyphish_home.png", .5f, nullptr);
    menuBar->addElem("ui/glyphish_search.png", .5f, nullptr);
    menuBar->addElem("ui/glyphish_upload.png", .5f, nullptr);
    menuBar->addElem("ui/glyphish_user.png", .5f, nullptr);
    
    menuBar->select(0);
    
    //scene
    auto scene = Scene::create();
    scene->addChild(this);
    return true;
}

Scene* MainContainerLayer::getScene() {
    return (Scene*)(this->getParent());
}

void MainContainerLayer::onMenuBarSelect(uint32_t idx) {
    for (auto i = 0; i < LAYER_NUM; ++i) {
        if (_layers[i]) {
            if (i == idx) {
                _layers[i]->setVisible(true);
                _layers[i]->setTouchEnabled(true);
            } else {
                _layers[i]->setVisible(false);
                _layers[i]->setTouchEnabled(false);
            }
        }
    }
}









