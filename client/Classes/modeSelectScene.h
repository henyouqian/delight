#ifndef __MODE_SELECT_SCENE_H__
#define __MODE_SELECT_SCENE_H__

#include "pack.h"
#include "spriteLoader.h"
#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class PacksListScene;

class ModeSelectScene : public LayerColor, public PackListener, public SptLoaderListener {
public:
    static cocos2d::Scene* createScene(PackInfo *packInfo);
    bool init(PackInfo *packInfo);
    virtual ~ModeSelectScene();
    
    void enterCasualMode(Object *sender, Control::EventType controlEvent);
    void enterTimeAttackMode(Object *sender, Control::EventType controlEvent);
    void back(Object *sender, Control::EventType controlEvent);
    
    //PackListener
    virtual void onPackError();
    virtual void onPackImageDownload();
    virtual void onPackDownloadComplete();
    
    //SptLoaderListener
    virtual void onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData);
    virtual void onSptLoaderError(const char *localPath, void *userData);
    
private:
    PackInfo *_packInfo;
    PackDownloader *_packDownloader;
    LabelTTF *_progressLabel;
    SptLoader *_sptLoader;
    
    Sprite *_x;
};

#endif // __MODE_SELECT_SCENE_H__
