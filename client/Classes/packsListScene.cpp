#include "packsListScene.h"
#include "http.h"
#include "spriteLoader.h"
#include "gifTexture.h"
#include "util.h"
#include "db.h"
#include "pack.h"
#include "HelloWorldScene.h"
#include "sliderScene.h"
#include "modeSelectScene.h"
#include "jsonxx/jsonxx.h"
#include "lw/lwLog.h"
#include <limits>
#include <thread>

USING_NS_CC;
USING_NS_CC_EXT;

using namespace std::chrono;

namespace {
    int PACK_LIST_LIMIT = 16;
    float ICON_MARGIN = 5.f;
}

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
    
    sptLoader = SptLoader::create(this, this);
    
    //get list
    std::string url;
    char buf[256];
    int fromId = 0;
    snprintf(buf, 256, "{\"FromId\": %d, \"Limit\": %d}", fromId, PACK_LIST_LIMIT);
    _packListRequest = postHttpRequest("pack/list", buf, std::bind(&PacksListScene::onPackListDownloaded, this, std::placeholders::_1, std::placeholders::_2, fromId));
    _packListRequest->retain();
    
    //loading texture
    _loadingTexture = GifTexture::create("ui/loading.gif", this, false);
    _loadingTexture->retain();
    _loadingTexture->setSpeed(2.f);

    //
    _sptParent = Node::create();
    addChild(_sptParent, 1);
    
    //back button
    auto btnBack = createButton("<", 48, 1.f);
    btnBack->setPosition(Point(70, 70));
    btnBack->addTargetWithActionForControlEvents(this, cccontrol_selector(PacksListScene::back), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(btnBack);

    return true;
}

PacksListScene::~PacksListScene() {
    if (_packListRequest) {
        _packListRequest->release();
    }
    _loadingTexture->release();
    delete _pack;
    sptLoader->destroy();
}

void PacksListScene::update(float delta) {
    sptLoader->mainThreadUpdate();
    updateRoll();
}

void PacksListScene::back(Object *sender, Control::EventType controlEvent) {
    Director::getInstance()->popSceneWithTransition<TransitionFade>(.5f);
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

void PacksListScene::onPackListDownloaded(HttpClient* client, HttpResponse* response, int fromId) {
    lwinfo("onPackListDownloaded");
    
    if (!response->isSucceed()) {
        //load local
        sqlite3_stmt* pStmt = NULL;
        std::stringstream ss;
        if (fromId == 0) {
            fromId = std::numeric_limits<int>::max();
        }
        ss << "SELECT id, date, icon, cover, title, text, images from packs WHERE id<="<<fromId<<" ORDER BY id DESC LIMIT "<<PACK_LIST_LIMIT<<";";
        auto r = sqlite3_prepare_v2(gSaveDb, ss.str().c_str(), -1, &pStmt, NULL);
        if (r != SQLITE_OK) {
            lwerror("sqlite error: %s", ss.str().c_str());
            return;
        }
        while ( 1 ){
            r = sqlite3_step(pStmt);
            if ( r == SQLITE_ROW ){
                auto id = sqlite3_column_int(pStmt, 0);
                auto pack = Pack::create(id);
                pack->id = id;
                pack->date = (const char*)sqlite3_column_text(pStmt, 1);
                pack->icon = (const char*)sqlite3_column_text(pStmt, 2);
                pack->cover = (const char*)sqlite3_column_text(pStmt, 3);
                pack->title = (const char*)sqlite3_column_text(pStmt, 4);
                pack->text = (const char*)sqlite3_column_text(pStmt, 5);
                pack->images = (const char*)sqlite3_column_text(pStmt, 6);
            }else if ( r == SQLITE_DONE ){
                break;
            }else{
                //lwassert(0);
                break;
            }
        }
        sqlite3_finalize(pStmt);
    } else {
        //response succeed
        auto v = response->getResponseData();
        std::istringstream is(std::string(v->begin(), v->end()));
        
        jsonxx::Array packs;
        bool ok = packs.parse(is);
        if (!ok) {
            lwerror("json parse error");
            return;
        }
        
        std::stringstream sql;
        sql << "BEGIN TRANSACTION;";
        
        for (auto i = 0; i < packs.size(); ++i) {
            auto packJs = packs.get<jsonxx::Object>(i);
            
            if (!packJs.has<jsonxx::Number>("Id")) {
                lwerror("json parse error: no number: Id");
                return;
            }
            if (!packJs.has<jsonxx::String>("Date")) {
                lwerror("json parse error: no string: Date");
                return;
            }
            if (!packJs.has<jsonxx::String>("Title")) {
                lwerror("json parse error: no string: Title");
                return;
            }
            if (!packJs.has<jsonxx::String>("Icon")) {
                lwerror("json parse error: no string: Icon");
                return;
            }
            if (!packJs.has<jsonxx::String>("Cover")) {
                lwerror("json parse error: no string: Cover");
                return;
            }
            if (!packJs.has<jsonxx::String>("Text")) {
                lwerror("json parse error: no string: Text");
                return;
            }
            if (!packJs.has<jsonxx::String>("Images")) {
                lwerror("json parse error: no string: Images");
                return;
            }
            
            auto id = (int)(packJs.get<jsonxx::Number>("Id"));
            auto pack = Pack::create(id);
            pack->id = id;
            pack->date = packJs.get<jsonxx::String>("Date");
            pack->icon = packJs.get<jsonxx::String>("Icon");
            pack->cover = packJs.get<jsonxx::String>("Cover");
            pack->title = packJs.get<jsonxx::String>("Title");
            pack->text = packJs.get<jsonxx::String>("Text");
            pack->images = packJs.get<jsonxx::String>("Images");
            
            //save to sqlite
            sql << "REPLACE INTO packs(id, date, icon, cover, title, text, images) VALUES(";
            sql << pack->id << ",";
            sql << "'" << pack->date.c_str() << "',";
            sql << "'" << pack->icon.c_str() << "',";
            sql << "'" << pack->cover.c_str() << "',";
            sql << "'" << pack->title.c_str() << "',";
            sql << "'" << pack->text.c_str() << "',";
            sql << "'" << pack->images.c_str() << "');";
        }
        
        sql << "COMMIT;";
        char *err;
        auto r = sqlite3_exec(gSaveDb, sql.str().c_str(), NULL, NULL, &err);
        if(r != SQLITE_OK) {
            lwerror("sqlite error: %s\nsql=%s", err, sql.str().c_str());
        }
    }
    
    int i = 0;
    auto &packs = PackManager::getInstance()->packs;
    for (auto it = packs.rbegin(); it != packs.rend(); ++it, ++i) {
        //loading sprite
        auto loadingSpt = Sprite::createWithTexture(_loadingTexture);
        _sptParent->addChild(loadingSpt);
        int row = i / 3;
        int col = i % 3;
        auto visSize = Director::getInstance()->getVisibleSize();
        float w = (visSize.width-2.f*ICON_MARGIN) / 3.f;
        float x = (w+ICON_MARGIN)*col + .5f*w;
        float y = visSize.height - ((w+ICON_MARGIN)*row+.5f*w);
        loadingSpt->setPosition(Point(x, y));
        loadingSpt->setScale(2.f);
        _thumbWidth = w;
        
        //async load icon
        std::string localPath;
        makeLocalImagePath(localPath, it->second->icon.c_str());
        
        _loadingSpts.insert(std::make_pair(localPath, loadingSpt));
        sptLoader->download(it->second->icon.c_str());
    }
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
    lwerror("onSptLoaderError: %s", localPath);
}

void PacksListScene::onTouchesBegan(const std::vector<Touch*>& touches, Event *event) {
    //
    _dragging = false;
    _parentTouchY = _sptParent->getPositionY();
    _dragPointInfos.clear();
    _rollSpeed = 0.f;
    
    //
    auto touch = touches[0];
    auto children = _sptParent->getChildren();
    if (!children) {
        return;
    }
    auto &packs = PackManager::getInstance()->packs;
    auto it = packs.rbegin();
    selPack = nullptr;
    for( int i = 0; i < children->count() && it != packs.rend() ; i++, it++ ){
        auto node = static_cast<Node*>( children->getObjectAtIndex(i) );
        auto rect = node->getBoundingBox();
        rect.origin.y += _sptParent->getPositionY();
        if (rect.containsPoint(touch->getLocation())) {
            selPack = it->second;
            break;
        }
    }
    
//    //
//    if (touch->getLocation().y < 60) {
//        if (touch->getLocation().x < 200) {
//            auto pi = _packInfos[5];
//            Director::getInstance()->pushScene(TransitionFade::create(0.5f, SliderScene::createScene(pi.title.c_str(), pi.text.c_str(), pi.images.c_str())));
//        } else if (touch->getLocation().x > 640-200) {
//            auto pi = _packInfos[3];
//            Director::getInstance()->pushScene(TransitionFade::create(0.5f, SliderScene::createScene(pi.title.c_str(), pi.text.c_str(), pi.images.c_str())));
//        } else {
//            auto pi = _packInfos[4];
//            Director::getInstance()->pushScene(TransitionFade::create(0.5f, SliderScene::createScene(pi.title.c_str(), pi.text.c_str(), pi.images.c_str())));
//        }
//    }
}

void PacksListScene::onTouchesMoved(const std::vector<Touch*>& touches, Event *event) {
    auto touch = touches[0];
    
    if (_dragging == false && fabs(touch->getLocation().y-touch->getStartLocation().y) > 10) {
        _dragging = true;
        _touchBeginY = touch->getLocation().y;
    }
    
    if (_dragging) {
        _sptParent->setPositionY(_parentTouchY+touch->getLocation().y-_touchBeginY);
    }
    
    DragPointInfo dpi;
    dpi.y = touch->getLocation().y;
    dpi.t = steady_clock::now();
    _dragPointInfos.push_back(dpi);
    if (_dragPointInfos.size() > 5) {
        _dragPointInfos.pop_front();
    }
    
//    auto now = steady_clock::now();
//    auto dtn = now.time_since_epoch();
//    
//    long long t = dtn.count();
//    lwinfo("%lld", t-_ll);
//    _ll = t;
    
}

void PacksListScene::onTouchesEnded(const std::vector<Touch*>& touches, Event *event) {
    auto touch = touches[0];
    _rollSpeed = 0.f;
    auto now = steady_clock::now();
    float minDt = 0.1f;
    for (auto it = _dragPointInfos.begin(); it != _dragPointInfos.end(); ++it) {
        auto dt = duration_cast<duration<float>>(now - it->t).count();
        if (dt < minDt) {
            _rollSpeed = (touch->getLocation().y - it->y) / dt / 60.f;
            _rollSpeed = MIN(100.f, MAX(-100.f, _rollSpeed));
            lwinfo("%f", _rollSpeed);
            _parentY = _sptParent->getPositionY();
            break;
        }
    }
    
    if (!_dragging && selPack) {
        auto scene = ModeSelectScene::createScene(this);
        Director::getInstance()->pushScene(TransitionFade::create(0.5f, scene));
    }
    _dragging = false;
}

void PacksListScene::updateRoll() {
    if (_rollSpeed) {
        _parentY += _rollSpeed;
        _sptParent->setPositionY(floor(_parentY));
        
        bool neg = _rollSpeed < 0;
        float v = fabs(_rollSpeed);
        //v -= 2;
        float brk = v * .08f;
        brk = MAX(brk, 0.1f);
        v -= brk;
        if (v < 0.01f) {
            v = 0;
        }
        _rollSpeed = v;
        if (neg) {
            _rollSpeed = -_rollSpeed;
        }
    }
}

void PacksListScene::onTouchesCancelled(const std::vector<Touch*>&touches, Event *event) {
    _dragging = false;
    //fixme
}





