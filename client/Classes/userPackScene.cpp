#include "userPackScene.h"
#include "packsBookScene.h"
#include "lang.h"
#include "http.h"
#include "util.h"
#include "jsonxx/jsonxx.h"
#include "lw/lwLog.h"
#include "crypto/sha.h"
#include "qiniu/io.h"
#include <sys/stat.h>

USING_NS_CC;
USING_NS_CC_EXT;

Scene* UserPackScene::createScene() {
    auto scene = Scene::create();
    auto layer = UserPackScene::create();
    scene->addChild(layer);
    return scene;
}

bool UserPackScene::init() {
    if (!LayerColor::initWithColor(Color4B(255, 255, 255, 255)))  {
        return false;
    }

    Size visibleSize = Director::getInstance()->getVisibleSize();
    
    //buttons
    auto button = createButton(lang("选"), 48, 2.f);
    button->setPosition(Point(visibleSize.width/2, visibleSize.height/2));
    button->addTargetWithActionForControlEvents(this, cccontrol_selector(UserPackScene::showImagePicker), Control::EventType::TOUCH_UP_INSIDE);
    this->addChild(button, 1);
    
    //test
    _uploader = new QiniuUploader(this);
    
    return true;
}

UserPackScene::~UserPackScene() {
    _uploader->destroy();
}

void UserPackScene::showImagePicker(Object *sender, Control::EventType controlEvent) {
    showElcPickerView(this);
}

void UserPackScene::onElcLoad(std::vector<JpgData>& jpgs) {
    auto path = FileUtils::getInstance()->getWritablePath();
    path += "userPack";
    
    mkdir(path.c_str(), S_IRWXU);
    
    _jpgFileNames.clear();
    
    jsonxx::Array jsMsg;
    for (auto it = jpgs.begin(); it != jpgs.end(); ++it) {
        Sha1 sha;
        sha.write((const char*)(it->data), it->length);
        sha.final();
        auto b64 = sha.getBase64();
        
        std::string fileName = b64;
        fileName += ".jpg";
        _jpgFileNames.push_back(fileName);
        
        std::string path = getUploadPackDir();
        path += fileName;
        
        if (!FileUtils::getInstance()->isFileExist(path)) {
            auto f = fopen(path.c_str(), "wb");
            fwrite(it->data, it->length, 1, f);
            fclose(f);
        }
        
        jsMsg << fileName;
        
//        Qiniu_Error err;
//        err = Qiniu_Io_PutFile(qiniuGetClient(), nullptr, nullptr, key, path.c_str(), NULL);
        
//        auto image = new Image();
//        image->autorelease();
//        bool b = image->initWithImageData((const unsigned char*)it->data, it->length);
//        if (b) {
//            auto tex = new Texture2D();
//            b = tex->initWithImage(image);
//            if (b) {
//                auto spt = Sprite::createWithTexture(tex);
//                auto size = Director::getInstance()->getVisibleSize();
//                spt->setPosition(Point(size.width*.5f, size.height*.5f));
//                addChild(spt);
//            }
//        }
    }
    
    //request upload token
    postHttpRequest("userPack/getUploadToken", jsMsg.json().c_str(), this, (SEL_HttpResponse)&UserPackScene::onGetUploadToken);
}

void UserPackScene::onQiniuUploadSuccess(const char* key) {
    --_uploadingNum;
    if (_uploadingNum == 0) {
        jsonxx::Object msg;
        jsonxx::Array images;
        for (auto it = _jpgFileNames.begin(); it != _jpgFileNames.end(); ++it) {
            jsonxx::Object image;
            std::string url = "http://slideruserpack.qiniudn.com/";
            url += it->c_str();
            image << "Url" << url;
            images << image;
        }
        msg << "Images" << images;
        
        lwinfo("%s", msg.json().c_str());
        
        postHttpRequest("userPack/newPack", msg.json().c_str(), this, (SEL_HttpResponse)&UserPackScene::onNewPack);
    }
}

void UserPackScene::onNewPack(HttpClient *c, HttpResponse *r) {
    auto vData = r->getResponseData();
    std::istringstream is(std::string(vData->begin(), vData->end()));
    
    jsonxx::Object msg;
    bool ok = msg.parse(is);
    if (!ok) {
        lwerror("json parse error");
        return;
    }
    
    lwinfo("packId: %d", (int)msg.get<jsonxx::Number>("Id"));
}

void UserPackScene::onQiniuUploadError() {
    
}

void UserPackScene::onGetUploadToken(HttpClient *c, HttpResponse *r) {
    auto vData = r->getResponseData();
    std::istringstream is(std::string(vData->begin(), vData->end()));
    
    jsonxx::Array jsMsg;
    bool ok = jsMsg.parse(is);
    if (!ok) {
        lwerror("json parse error");
        return;
    }
    
    _uploadingNum = jsMsg.size();
    for (auto i = 0; i < jsMsg.size(); ++i) {
        auto elem = jsMsg.get<jsonxx::Object>(i);
        auto key = elem.get<jsonxx::String>("Key");
        auto token = elem.get<jsonxx::String>("Token");
        
        std::string path = getUploadPackDir();
        path += key;
        _uploader->addFile(token.c_str(), key.c_str(), path.c_str());
    }
}

void UserPackScene::onElcCancel() {
    
}
