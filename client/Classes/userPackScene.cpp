#include "userPackScene.h"
#include "packsBookScene.h"
#include "util.h"
#include "lang.h"
#include "http.h"
#include "jsonxx/jsonxx.h"
#include "lw/lwLog.h"
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
    
    return true;
}

void UserPackScene::showImagePicker(Object *sender, Control::EventType controlEvent) {
    showElcPickerView(this);
}

void UserPackScene::onElcLoad(std::vector<JpgData>& jpgs) {
    auto path = FileUtils::getInstance()->getWritablePath();
    path += "userPack";
    
    mkdir(path.c_str(), S_IRWXU);
    
    for (auto it = jpgs.begin(); it != jpgs.end(); ++it) {
        auto image = new Image();
        image->autorelease();
        bool b = image->initWithImageData((const unsigned char*)it->data, it->length);
        if (b) {
            auto tex = new Texture2D();
            b = tex->initWithImage(image);
            if (b) {
                auto spt = Sprite::createWithTexture(tex);
                auto size = Director::getInstance()->getVisibleSize();
                spt->setPosition(Point(size.width*.5f, size.height*.5f));
                addChild(spt);
            }
        }
    }
}

void UserPackScene::onElcCancel() {
    
}
