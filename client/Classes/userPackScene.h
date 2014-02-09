#ifndef __USER_PACK_SCENE_H__
#define __USER_PACK_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"
#include "ELCPicker.h"
#include "qiniu.h"

USING_NS_CC;
USING_NS_CC_EXT;

class UserPackScene : public LayerColor, public ElcListener, public QiniuUploaderListener {
public:
    static cocos2d::Scene* createScene();
    virtual bool init();
    CREATE_FUNC(UserPackScene);
    ~UserPackScene();
    
    void showImagePicker(Object *sender, Control::EventType controlEvent);
    
    //ElcListener
    virtual void onElcLoad(std::vector<JpgData>& jpgs);
    virtual void onElcCancel();
    
    //QiniuUploaderListener
    virtual void onQiniuUploadSuccess(const char* key);
    virtual void onQiniuUploadError();
    
    void onGetUploadToken(HttpClient *c, HttpResponse *r);
    void onNewPack(HttpClient *c, HttpResponse *r);
    
private:
    std::vector<std::string> _jpgFileNames;
    QiniuUploader *_uploader;
    int _uploadingNum;
};


#endif // __USER_PACK_SCENE_H__
