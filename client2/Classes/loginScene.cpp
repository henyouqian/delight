#include "loginScene.h"
#include "eventListScene.h"
#include "http.h"
#include "util.h"
#include "button.h"
#include "jsonxx/jsonxx.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

LoginLayer* LoginLayer::createWithScene() {
    auto scene = Scene::create();
    auto layer = new LoginLayer();
    if (layer && layer->init()) {
        layer->autorelease();
        scene->addChild(layer);
        return layer;
    }
    CC_SAFE_DELETE(layer);
    return nullptr;
}

bool LoginLayer::init() {
    if (!LayerColor::initWithColor(Color4B(255, 255, 255, 255))) {
        return false;
    }
    
    auto visSize = Director::getInstance()->getVisibleSize();
    auto editBoxSize = Size(visSize.width - 100, 60);
    _waiting = false;
    
    _editUserName = EditBox::create(editBoxSize, Scale9Sprite::create("ui/pt.png"));
    _editUserName->setPosition(Point(visSize.width*.5f, visSize.height - 200));
    _editUserName->setAnchorPoint(Point(.5f, 1));
    _editUserName->setFont("HelveticaNeue", 40);
    _editUserName->setFontColor(Color3B(10, 10, 10));
    _editUserName->setPlaceHolder("Name:");
    _editUserName->setPlaceholderFontColor(Color3B::GRAY);
    _editUserName->setMaxLength(20);
    _editUserName->setInputMode(EditBox::InputMode::EMAIL_ADDRESS);
    _editUserName->setInputFlag(EditBox::InputFlag::SENSITIVE);
    _editUserName->setReturnType(EditBox::KeyboardReturnType::DONE);
    _editUserName->setText("test1");
    addChild(_editUserName, 1);
    
    _editPassword = EditBox::create(editBoxSize, Scale9Sprite::create("ui/pt.png"));
    _editPassword->setPosition(Point(visSize.width*.5f, visSize.height - 300));
    _editPassword->setAnchorPoint(Point(.5f, 1));
    _editPassword->setFont("HelveticaNeue", 40);
    _editPassword->setFontColor(Color3B(10, 10, 10));
    _editPassword->setPlaceHolder("Password:");
    _editPassword->setPlaceholderFontColor(Color3B::GRAY);
    _editPassword->setMaxLength(20);
    _editPassword->setReturnType(EditBox::KeyboardReturnType::DONE);
    _editPassword->setInputFlag(EditBox::InputFlag::PASSWORD);
    _editPassword->setText("aaa");
    addChild(_editPassword, 1);
    
    auto btnLogin = createTextButton("HelveticaNeue", "Login", 64, Color3B::WHITE);
    btnLogin->setPosition(Point(visSize.width*.5f, visSize.height - 600));
    btnLogin->setAnchorPoint(Point(.5f, 1));
    btnLogin->setTitleColorForState(Color3B(255, 0, 0), Control::State::HIGH_LIGHTED);
    btnLogin->addTargetWithActionForControlEvents(this, cccontrol_selector(LoginLayer::sendLoginMsg), Control::EventType::TOUCH_UP_INSIDE);
    addChild(btnLogin, 1);
    //btnLogin->setPreferredSize(Size(300, 300));
    
    //test
    auto btn = Button::create("ui/pt.png");
    btn->setPosition(Point(visSize.width*.5f, visSize.height - 800));
    //btn->setPosition(Point(0, 0));
    btn->setContentSize(Size(200, 100));
    this->addChild(btn);
    
    auto label = LabelTTF::create("aaabbb", "HelveticaNeue", 42);
    label->setPosition(Point(btn->getContentSize().width*.5f, btn->getContentSize().height*.5f));
    label->setColor(Color3B::RED);
    label->setAnchorPoint(Point(.5f, 0.5f));
    btn->addLabel(label, Color3B::WHITE, Color3B::BLACK);
    btn->onClick(this, (Button::Handler)&LoginLayer::onBtn);
    //label->enableStroke(Color3B::RED, 3.0f, true);
    
    //test
    label = LabelTTF::create("xxxxxiiii", "HelveticaNeue", 42);
    //label->enableStroke(Color3B::RED, 3.0f, true);
    label->disableStroke();
    //label->enableShadow(Size(2, 2), .5f, 1.f, true);
    label->setPosition(Point(visSize.width*.5f, 200));
    label->setColor(Color3B::YELLOW);
    label->setAnchorPoint(Point(.5f, 0.5f));
    
    addChild(label);
    
    
    return true;
}

void LoginLayer::onBtn(Ref* btn) {
    lwinfo("xxxxxxxxx");
}

void LoginLayer::sendLoginMsg(Ref *sender, Control::EventType controlEvent) {
    if (_waiting) {
        return;
    }
    std::string username = _editUserName->getText();
    std::string password = _editPassword->getText();
    if (username.size() > 0 && password.size() > 0) {
        jsonxx::Object loginMsg;
        loginMsg << "Username" << username;
        loginMsg << "Password" << password;
        postHttpRequest("auth/login", loginMsg.json().c_str(), this, (SEL_HttpResponse)&LoginLayer::onHttpLogin);
        _waiting = true;
    }
}

void LoginLayer::onHttpLogin(HttpClient* client, HttpResponse* resp) {
    std::string body;
    if (!checkHttpResp(resp, body)) {
        lwerror("http error:%s", body.c_str());
        _waiting = false;
        return;
    }
    
    jsonxx::Object msg;
    if (!msg.parse(body)) {
        lwerror("msg.parse(body)");
        _waiting = false;
        return;
    }
    auto token = msg.get<jsonxx::String>("Token");
    setHttpUserToken(token.c_str());
    
    //
    postHttpRequest("player/getInfo", "", this, (SEL_HttpResponse)&LoginLayer::onHttpGetPlayerInfo);
    
}

void LoginLayer::onHttpGetPlayerInfo(HttpClient* client, HttpResponse* resp) {
    _waiting = false;
    
    std::string body;
    if (!checkHttpResp(resp, body)) {
        lwerror("http error:%s", body.c_str());
        _waiting = false;
        return;
    }
    
    jsonxx::Object msg;
    if (!msg.parse(body)) {
        lwerror("msg.parse(body)");
        _waiting = false;
        return;
    }
    
    if (!msg.has<jsonxx::String>("Name")
        ||!msg.has<jsonxx::Number>("TeamId")
        ||!msg.has<jsonxx::Number>("Now")) {
        lwerror("msg need key Name, TeamId, Now");
        return;
    }
    
    auto &playerInfo = getPlayerInfo();
    playerInfo.name = msg.get<jsonxx::String>("Name");
    playerInfo.teamId = (uint32_t)msg.get<jsonxx::Number>("TeamId");
    setNow((int64_t)msg.get<jsonxx::Number>("Now"));
    
    Director::getInstance()->replaceScene(TransitionFade::create(0.5f, (Scene*)EventListLayer::createWithScene()->getParent()));
}









