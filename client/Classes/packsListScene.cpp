#include "packsListScene.h"
#include "http.h"
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
    if (!Layer::init()) {
        return false;
    }
    
    //get list
    std::string url;
    char buf[256];
    snprintf(buf, 256, "{\"LastPackId\": %d, \"Limit\": %d}", 0, 16);
    postHttpRequest("pack/list", buf, std::bind(&PacksListScene::onPackList, this, std::placeholders::_1, std::placeholders::_2));
    
    
    return true;
}

PacksListScene::~PacksListScene() {
    
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
        packInfo.Id = (int)(pack.get<jsonxx::Number>("Id"));
        packInfo.Date = pack.get<jsonxx::String>("Date");
        packInfo.Cover = pack.get<jsonxx::String>("Cover");
        packInfo.Title = pack.get<jsonxx::String>("Title");
        packInfo.Text = pack.get<jsonxx::String>("Text");
        packInfo.image = nullptr;
        
        _packInfos.push_back(packInfo);
    }
}