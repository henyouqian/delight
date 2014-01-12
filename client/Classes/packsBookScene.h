#ifndef __PACK_BOOK_SCENE_H__
#define __PACK_BOOK_SCENE_H__

#include "spriteLoader.h"
#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class GifTexture;

class PacksBookScene : public LayerColor, public SptLoaderListener{
public:
    static cocos2d::Scene* createScene();
    CREATE_FUNC(PacksBookScene);
    virtual bool init();
    virtual ~PacksBookScene();
    
    void back(Object *sender, Control::EventType controlEvent);
    void onHttpGetCount(HttpClient* client, HttpResponse* response);
    void onHttpGetPack(HttpClient* client, HttpResponse* response);
    
private:
    //page: zero based
    void loadPage(int page);
    
    LabelTTF *_pageLabel;
    int _packCount;
    int _pageCount;
    int _currPage;
    
    GifTexture *_loadingTexture;
    std::multimap<std::string, Sprite*> _localMapLoadingSpr;
    Node *_loadingSprParent;
    float _iconWidth;
    
    struct Pack {
        int id;
        std::string date;
        std::string title;
        std::string text;
        std::string icon;
        std::string cover;
        
        struct Image {
            std::string url;
            std::string title;
            std::string text;
        };
        std::vector<Image> images;
    };
    std::vector<Pack> _packs;
    
    SptLoader *_sptLoader;
};


#endif // __PACK_BOOK_SCENE_H__
