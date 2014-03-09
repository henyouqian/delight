#include "matchListScene.h"
#include "packLoadingScene.h"
#include "matchLobbyScene.h"
#include "jsonxx/jsonxx.h"
#include "db.h"
#include "http.h"
#include "dragView.h"
#include "util.h"

USING_NS_CC;
USING_NS_CC_EXT;

static const float THUMB_MARGIN = 3;

MatchListLayer* MatchListLayer::createWithScene() {
    auto scene = Scene::create();
    auto layer = new MatchListLayer();
    if (layer && layer->init()) {
        layer->autorelease();
        scene->addChild(layer);
        return layer;
    }
    CC_SAFE_DELETE(layer);
    return nullptr;
}

bool MatchListLayer::init() {
    if (!Layer::init()) {
        return false;
    }
    
    setTouchEnabled(true);
    this->setTouchMode(Touch::DispatchMode::ONE_BY_ONE);
    auto visSize = Director::getInstance()->getVisibleSize();
    
    //
    _sptLoader = SptLoader::create(this);
    addChild(_sptLoader);
    
    //drag view
    _dragView = DragView::create();
    addChild(_dragView);
    float dragViewHeight = visSize.height;
    _dragView->setWindowRect(Rect(0, 0, visSize.width, dragViewHeight));
    
    //thumb width and height
    _thumbWidth = (visSize.width - THUMB_MARGIN) * .5f;
    _thumbHeight = _thumbWidth;
    
    //get match pack list
    jsonxx::Object msg;
    msg << "StartMatchId" << 0;
    msg << "Limit" << 20;
    
    postHttpRequest("match/list", msg.json().c_str(), this, (SEL_HttpResponse)(&MatchListLayer::onHttpListMatch));
    
    return true;
}

void MatchListLayer::onHttpListMatch(HttpClient* client, HttpResponse* response) {
    jsonxx::Array msg;
    if (!response->isSucceed()) {
//        //load local
//        sqlite3_stmt* pStmt = NULL;
//        std::stringstream sql;
//        sql << "SELECT value FROM matches;";
//        auto r = sqlite3_prepare_v2(gSaveDb, sql.str().c_str(), -1, &pStmt, NULL);
//        if (r != SQLITE_OK) {
//            lwerror("sqlite error: %s", sql.str().c_str());
//            return;
//        }
//        while (sqlite3_step(pStmt) == SQLITE_ROW ){
//            jsonxx::Object coljs;
//            auto v = (const char*)sqlite3_column_text(pStmt, 0);
//            string str;
//            if (v) {
//                str = v;
//            }
//            coljs.parse(str);
//            msg << coljs;
//        }
//        sqlite3_finalize(pStmt);
        lwerror("MatchListLayer::onHttpListMatch http error");
        return;
    } else {
        //parse response
        std::string body;
        getHttpResponseString(response, body);
        bool ok = msg.parse(body);
        if (!ok) {
            lwerror("json parse error");
            return;
        }
    }
    
    float minY = 0.f;
    for (auto i = 0; i < msg.size(); ++i) {
        auto matchJs = msg.get<jsonxx::Object>(i);
        if (!matchJs.has<jsonxx::Number>("Id")
            || !matchJs.has<jsonxx::String>("BeginTime")
            || !matchJs.has<jsonxx::String>("EndTime")
            || !matchJs.has<jsonxx::Object>("Pack")) {
            lwerror("json invalid, need Id, BeginTime, EndTime, Pack");
            return;
        }
        
        MatchInfo matchInfo;
        matchInfo.matchId = (uint64_t)matchJs.get<jsonxx::Number>("Id");
        matchInfo.beginTime = matchJs.get<jsonxx::String>("BeginTime");
        matchInfo.endTime = matchJs.get<jsonxx::String>("EndTime");
        
        auto packJs = matchJs.get<jsonxx::Object>("Pack");
        matchInfo.packInfo.init(packJs);
        matchInfo.loaded = false;
        
        auto idx = _matchInfos.size();
        auto firstW = _thumbWidth * 2.f + THUMB_MARGIN;
        if (idx == 0) {
            matchInfo.thumbRect.setRect(THUMB_MARGIN, -THUMB_MARGIN-firstW, firstW, firstW);
        } else {
            float x = (idx-1)%2 == 0 ? THUMB_MARGIN : THUMB_MARGIN*2+_thumbWidth;
            float y = -(THUMB_MARGIN*2 + firstW + ((idx-1)/2)*(_thumbHeight+THUMB_MARGIN) + _thumbHeight);
            
            matchInfo.thumbRect.setRect(x, y, _thumbWidth, _thumbHeight);
        }
        _matchInfos.push_back(matchInfo);
        _sptLoader->download(matchInfo.packInfo.cover.c_str(), (void*)(uint32_t)matchInfo.packInfo.id);
        minY = MIN(minY, matchInfo.thumbRect.origin.y - THUMB_MARGIN);
    }
    
    _dragView->setContentHeight(-minY);
}

//SptLoaderListener
void MatchListLayer::onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData) {
    uint32_t packId = (uint32_t)userData;
    for (auto it = _matchInfos.rbegin(); it != _matchInfos.rend(); ++it) {
        if (it->packInfo.id == packId) {
            //
            it->loaded = true;
            it->thumbFilePath = localPath;
            
            //
            _dragView->addChild(sprite);
            sprite->setAnchorPoint(Point(0.f, 0.f));
            sprite->setPosition(it->thumbRect.origin);
            
            //
            auto thumbWidth = it->thumbRect.size.width;
            auto thumbHeight = it->thumbRect.size.height;
            auto size = sprite->getContentSize();
            auto scaleW = thumbWidth/size.width;
            auto scaleH = thumbHeight/size.height;
            auto scale = MAX(scaleW, scaleH);
            float uvw = size.width;
            float uvh = size.height;
            if (scaleW <= scaleH) {
                uvw = size.height * thumbWidth/thumbHeight;
            } else {
                uvh = size.width * thumbHeight/thumbWidth;
            }
            sprite->setScale(scale);
            sprite->setTextureRect(Rect((size.width-uvw)*.5f, (size.height-uvh)*.5f, uvw, uvh));
            break;
        }
    }
}

void MatchListLayer::onSptLoaderError(const char *localPath, void *userData) {
    lwerror("MatchListLayer::onSptLoaderError");
}

//touch
bool MatchListLayer::onTouchBegan(Touch* touch, Event  *event) {
    _dragView->onTouchesBegan(touch);
    return true;
}

void MatchListLayer::onTouchMoved(Touch* touch, Event  *event) {
    _dragView->onTouchesMoved(touch);
}

void MatchListLayer::onTouchEnded(Touch* touch, Event  *event) {
    if (!_dragView->isDragging() && _dragView->getWindowRect().containsPoint(touch->getLocation())) {
        for(auto it = _matchInfos.begin(); it != _matchInfos.end(); ++it){
            Point touchLocation = touch->getLocation();
            touchLocation = _dragView->convertToNodeSpace(touchLocation);
            if (it->thumbRect.containsPoint(touchLocation)) {
                auto matchLobbyLayer = MatchLobbyLayer::create(it->packInfo);
                if (isPackDownloaded(it->packInfo)) {
                    Director::getInstance()->pushScene(TransitionFade::create(0.5f, (Scene*)matchLobbyLayer->getParent()));
                } else {
                    auto loadingLayer = PackLoadingLayer::create(it->packInfo, (Scene*)matchLobbyLayer->getParent());
                    Director::getInstance()->pushScene(TransitionFade::create(0.5f, (Scene*)loadingLayer->getParent()));
                }

                return;
            }
        }
    }
    
    _dragView->onTouchesEnded(touch);
}

void MatchListLayer::onTouchCancelled(Touch *touch, Event *event) {
    onTouchEnded(touch, event);
}

