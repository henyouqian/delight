#ifndef __LOGIN_SCENE_H__
#define __LOGIN_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"
#include "network/HttpClient.h"

USING_NS_CC;
USING_NS_CC_EXT;
using namespace cocos2d::network;


class LoginLayer : public Layer {
public:
    static LoginLayer* createWithScene();
    bool init();
    
    //callback
    void sendLoginMsg(Ref *sender, Control::EventType controlEvent);
    
    //
    void onHttpLogin(HttpClient* client, HttpResponse* response);
    void onHttpGetPlayerInfo(HttpClient* client, HttpResponse* response);
    
    void onBtn(Ref* btn);
    
    
private:
    EditBox *_editUserName;
    EditBox *_editPassword;
    bool _waiting;
};


#endif // __LOGIN_SCENE_H__
