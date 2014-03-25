#include "loginScene.h"
#include "eventListScene.h"
#include "http.h"
#include "util.h"
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
    if (!Layer::init()) {
        return false;
    }
    
    auto visSize = EGLView::getInstance()->getVisibleSize();
    auto editBoxSize = Size(visSize.width - 100, 60);
    
    _editUserName = EditBox::create(editBoxSize, Scale9Sprite::create("ui/pt.png"));
    _editUserName->setPosition(Point(visSize.width*.5f, visSize.height - 200));
    _editUserName->setAnchorPoint(Point(.5f, 1));
    _editUserName->setFontSize(25);
    _editUserName->setFontColor(Color3B(10, 10, 10));
    _editUserName->setPlaceHolder("Name:");
    _editUserName->setPlaceholderFontColor(Color3B::GRAY);
    _editUserName->setMaxLength(20);
    _editUserName->setInputMode(EditBox::InputMode::EMAIL_ADDRESS);
    _editUserName->setInputFlag(EditBox::InputFlag::SENSITIVE);
    _editUserName->setReturnType(EditBox::KeyboardReturnType::DONE);
    _editUserName->setDelegate(this);
    _editUserName->setText("aa");
    addChild(_editUserName, 1);
    
    _editPassword = EditBox::create(editBoxSize, Scale9Sprite::create("ui/pt.png"));
    _editPassword->setPosition(Point(visSize.width*.5f, visSize.height - 300));
    _editPassword->setAnchorPoint(Point(.5f, 1));
    _editPassword->setFontSize(25);
    _editPassword->setFontColor(Color3B(10, 10, 10));
    _editPassword->setPlaceHolder("Password:");
    _editPassword->setPlaceholderFontColor(Color3B::GRAY);
    _editPassword->setMaxLength(20);
    _editPassword->setReturnType(EditBox::KeyboardReturnType::GO);
    _editPassword->setDelegate(this);
    _editPassword->setInputFlag(EditBox::InputFlag::PASSWORD);
    _editPassword->setText("aa");
    addChild(_editPassword, 1);
    
    auto btnLogin = createTextButton("HelveticaNeue", "Login", 48, Color3B::WHITE);
    btnLogin->setPosition(Point(visSize.width*.5f, visSize.height - 600));
    btnLogin->setAnchorPoint(Point(.5f, 1));
    btnLogin->setTitleColorForState(Color3B(255, 0, 0), Control::State::HIGH_LIGHTED);
    btnLogin->addTargetWithActionForControlEvents(this, cccontrol_selector(LoginLayer::sendLoginMsg), Control::EventType::TOUCH_UP_INSIDE);
    addChild(btnLogin, 1);
    
    return true;
}

void LoginLayer::sendLoginMsg(Object *sender, Control::EventType controlEvent) {
    std::string username = _editUserName->getText();
    std::string password = _editPassword->getText();
    if (username.size() > 0 && password.size() > 0) {
        jsonxx::Object loginMsg;
        loginMsg << "Username" << username;
        loginMsg << "Password" << password;
        postHttpRequest("auth/login", loginMsg.json().c_str(), this, (SEL_HttpResponse)&LoginLayer::onHttpLogin);
    }
}

void LoginLayer::editBoxReturn(EditBox* editBox) {
    if (editBox->ignoreKeyboardReturn()) {
        return;
    }
    if (editBox == _editPassword) {
        sendLoginMsg(nullptr, Control::EventType::TOUCH_UP_INSIDE);
    }
}

void LoginLayer::onHttpLogin(HttpClient* client, HttpResponse* resp) {
    std::string body;
    if (!checkHttpResp(resp, body)) {
        lwerror("http error:%s", body.c_str());
        return;
    }
    
    jsonxx::Object msg;
    if (!msg.parse(body)) {
        lwerror("msg.parse(body)");
        return;
    }
    auto token = msg.get<jsonxx::String>("Token");
    setHttpUserToken(token.c_str());
    
    Director::getInstance()->replaceScene(TransitionFade::create(0.5f, (Scene*)EventListLayer::createWithScene()->getParent()));
    
}