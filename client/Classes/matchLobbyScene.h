#ifndef __MATCH_LOBBY_SCENE_H__
#define __MATCH_LOBBY_SCENE_H__

#include "pack.h"
#include "spriteLoader.h"
#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class PacksListScene;

class MatchLobbyLayer : public LayerColor, public SptLoaderListener {
public:
    static MatchLobbyLayer* create(PackInfo &packInfo);
    bool init(PackInfo &packInfo);
    
    virtual ~MatchLobbyLayer();
    
    void enterCasualMode(Object *sender, Control::EventType controlEvent);
    //void enterTimeAttackMode(Object *sender, Control::EventType controlEvent);
    void back(Object *sender, Control::EventType controlEvent);
    
    //
    virtual void onEnter();
    
    //SptLoaderListener
    virtual void onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData);
    virtual void onSptLoaderError(const char *localPath, void *userData);
    
private:
    //PackDownloader *_packDownloader;
    LabelTTF *_progressLabel;
    SptLoader *_sptLoader;
    PackInfo _packInfo;
    
    Sprite *_bg;
};

#endif // __MATCH_LOBBY_SCENE_H__
