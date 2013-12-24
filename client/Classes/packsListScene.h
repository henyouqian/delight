#ifndef __PACKS_LIST_SCENE_H__
#define __PACKS_LIST_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class PacksListScene : public Layer {
public:
    static cocos2d::Scene* createScene();
    CREATE_FUNC(PacksListScene);
    virtual bool init();
    virtual ~PacksListScene();
    
    void onPackList(HttpClient* client, HttpResponse* response);
    
private:
    struct PackInfo {
        int Id;
        std::string Date;
        std::string Title;
        std::string Cover;
        std::string Text;
        Sprite *image;
    };
    std::vector<PackInfo> _packInfos;
};

#endif // __PACKS_LIST_SCENE_H__
