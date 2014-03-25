#ifndef __LOGIN_SCENE_H__
#define __LOGIN_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class LoginLayer : public Layer, public EditBoxDelegate{
public:
    static LoginLayer* createWithScene();
    bool init();
    
    //callback
    void sendLoginMsg(Object *sender, Control::EventType controlEvent);
    
    //EditBoxDelegate
    virtual void editBoxReturn(EditBox* editBox);
    
    //
    void onHttpLogin(HttpClient* client, HttpResponse* response);
    
    
private:
    EditBox *_editUserName;
    EditBox *_editPassword;
};


#endif // __LOGIN_SCENE_H__
