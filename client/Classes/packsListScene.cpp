#include "packsListScene.h"
#include "http.h"
#include "spriteLoader.h"
#include "gifTexture.h"
#include "util.h"
#include "db.h"
#include "HelloWorldScene.h"
#include "sliderScene.h"
#include "jsonxx/jsonxx.h"
#include "lw/lwLog.h"
#include <limits>
#include <thread>

USING_NS_CC;
USING_NS_CC_EXT;

using namespace std::chrono;

namespace {
    int PACK_LIST_LIMIT = 16;
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
    
    _sptLoader = SptLoader::create(this, this);
    
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
    addChild(_sptParent);

    return true;
}

PacksListScene::~PacksListScene() {
    if (_packListRequest) {
        _packListRequest->release();
    }
    _loadingTexture->release();
    delete _pack;
    _sptLoader->destroy();
}

void PacksListScene::update(float delta) {
    _sptLoader->mainThreadUpdate();
    updateRoll();
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
        ss << "SELECT id, date, cover, title, text, images from packs WHERE id<="<<fromId<<" ORDER BY id DESC LIMIT "<<PACK_LIST_LIMIT<<";";
        auto r = sqlite3_prepare_v2(gSaveDb, ss.str().c_str(), -1, &pStmt, NULL);
        if (r != SQLITE_OK) {
            lwerror("sqlite error: %s", ss.str().c_str());
            return;
        }
        while ( 1 ){
            r = sqlite3_step(pStmt);
            if ( r == SQLITE_ROW ){
                PackInfo packInfo;
                packInfo.id = sqlite3_column_int(pStmt, 0);
                packInfo.date = (const char*)sqlite3_column_text(pStmt, 1);
                packInfo.cover = (const char*)sqlite3_column_text(pStmt, 2);
                packInfo.title = (const char*)sqlite3_column_text(pStmt, 3);
                packInfo.text = (const char*)sqlite3_column_text(pStmt, 4);
                packInfo.images = (const char*)sqlite3_column_text(pStmt, 5);
                packInfo.sprite = nullptr;
                _packInfos[packInfo.id] = packInfo;
                
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
            if (!pack.has<jsonxx::String>("Images")) {
                lwerror("json parse error: no string: Images");
                return;
            }
            
            PackInfo packInfo;
            packInfo.id = (int)(pack.get<jsonxx::Number>("Id"));
            packInfo.date = pack.get<jsonxx::String>("Date");
            packInfo.cover = pack.get<jsonxx::String>("Cover");
            packInfo.title = pack.get<jsonxx::String>("Title");
            packInfo.text = pack.get<jsonxx::String>("Text");
            packInfo.images = pack.get<jsonxx::String>("Images");
            packInfo.sprite = nullptr;
            _packInfos[packInfo.id] = packInfo;
            
            //save to sqlite
            PackInfo &pi = packInfo;
            sql << "REPLACE INTO packs(id, date, cover, title, text, images) VALUES(";
            sql << pi.id << ",";
            sql << "'" << pi.date.c_str() << "',";
            sql << "'" << pi.cover.c_str() << "',";
            sql << "'" << pi.title.c_str() << "',";
            sql << "'" << pi.text.c_str() << "',";
            sql << "'" << pi.images.c_str() << "');";
        }
        
        sql << "COMMIT;";
        char *err;
        auto r = sqlite3_exec(gSaveDb, sql.str().c_str(), NULL, NULL, &err);
        if(r != SQLITE_OK) {
            lwerror("sqlite error: %s\nsql=%s", err, sql.str().c_str());
        }
    }
    
    int i = 0;
    for (auto it = _packInfos.rbegin(); it != _packInfos.rend(); ++it, ++i) {
        //loading sprite
        float margin = 10.f;
        auto loadingSpt = Sprite::createWithTexture(_loadingTexture);
        _sptParent->addChild(loadingSpt);
        int row = i / 3;
        int col = i % 3;
        auto visSize = Director::getInstance()->getVisibleSize();
        float w = (visSize.width-2.f*margin) / 3.f;
        float x = (w+margin)*col + .5f*w;
        float y = visSize.height - ((w+margin)*row+.5f*w);
        loadingSpt->setPosition(Point(x, y));
        loadingSpt->setScale(2.f);
        _thumbWidth = w;
        
        //async load cover
        std::string localPath;
        makeLocalImagePath(localPath, it->second.cover.c_str());
        
        _loadingSpts.insert(std::make_pair(localPath, loadingSpt));
        _sptLoader->download(it->second.cover.c_str());
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
    _parentTouchY = _sptParent->getPositionY();
    _dragPointInfos.clear();
    _rollSpeed = 0.f;
    
    //
    auto touch = touches[0];
    if (touch->getLocation().y < 60) {
        if (touch->getLocation().x < 200) {
            auto pi = _packInfos[5];
            Director::getInstance()->pushScene(TransitionFade::create(0.5f, SliderScene::createScene(pi.title.c_str(), pi.text.c_str(), pi.images.c_str())));
        } else if (touch->getLocation().x > 640-200) {
            auto pi = _packInfos[3];
            Director::getInstance()->pushScene(TransitionFade::create(0.5f, SliderScene::createScene(pi.title.c_str(), pi.text.c_str(), pi.images.c_str())));
        } else {
            auto pi = _packInfos[4];
            Director::getInstance()->pushScene(TransitionFade::create(0.5f, SliderScene::createScene(pi.title.c_str(), pi.text.c_str(), pi.images.c_str())));
        }
    }
}

void PacksListScene::onTouchesMoved(const std::vector<Touch*>& touches, Event *event) {
    auto touch = touches[0];
    _sptParent->setPositionY(_parentTouchY+touch->getLocation().y-touch->getStartLocation().y);
    
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
    
}





