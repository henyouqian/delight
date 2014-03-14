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
    static MatchLobbyLayer* create(MatchInfo &matchInfo);
    bool init(MatchInfo &matchInfo);
    virtual ~MatchLobbyLayer();
    
    //http
    void onHttpMatchInfo(HttpClient* client, HttpResponse* response);
    
    void enterFreePlayMode(Object *sender, Control::EventType controlEvent);
    void enterMatchMode(Object *sender, Control::EventType controlEvent);
    void back(Object *sender, Control::EventType controlEvent);
    
    //
    virtual void onEnter();
    
    //SptLoaderListener
    virtual void onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData);
    virtual void onSptLoaderError(const char *localPath, void *userData);
    
private:
    SptLoader *_sptLoader;
    MatchInfo _matchInfo;
    
    LabelTTF *_freePlayLabel;
    LabelTTF *_matchLabel;
};

#endif // __MATCH_LOBBY_SCENE_H__
