#ifndef __COLLECTION_LIST_SCENE_H__
#define __COLLECTION_LIST_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"
#include "spriteLoader.h"
#include "menuBar.h"

USING_NS_CC;
USING_NS_CC_EXT;

class DragView;

struct CollectionInfo {
    uint64_t id;
    std::string title;
    std::string text;
    std::string thumb;
    std::vector<uint64_t> packs;
};

class CollectionListScene : public cocos2d::Layer, public SptLoaderListener, public MenuBarListener{
public:
    virtual bool init();
    CREATE_FUNC(CollectionListScene);
    ~CollectionListScene();
    
    Scene *scene;
    
    void onHttpListCollection(HttpClient* client, HttpResponse* response);
    void back(Object *sender, Control::EventType controlEvent);
    
    //SptLoaderListener
    virtual void onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData);
    virtual void onSptLoaderError(const char *localPath, void *userData);
    
    //touch
    virtual void onTouchesBegan(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesMoved(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesEnded(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesCancelled(const std::vector<Touch*>&touches, Event *event);
    
private:
    DragView *_dragView;
    std::vector<CollectionInfo> _collections;
    SptLoader *_sptLoader;
    Touch* _touch;
    float _thumbWidth;
    float _thumbHeight;
    std::vector<Sprite*> _thumbs;
};

class SearchLayer : public Layer, public EditBoxDelegate, public SptLoaderListener{
public:
    CREATE_FUNC(SearchLayer);
    bool init();
    
    //
    void onHttpListByTag(HttpClient* client, HttpResponse* response);
    
    //touch
    virtual void onTouchesBegan(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesMoved(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesEnded(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesCancelled(const std::vector<Touch*>&touches, Event *event);
    
    //EditBoxDelegate
    virtual void editBoxReturn(EditBox* editBox);
    
    //SptLoaderListener
    virtual void onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData);
    virtual void onSptLoaderError(const char *localPath, void *userData);
    
private:
    int _thumbNum;
    int _dragViewHeight;
    EditBox *_editSearch;
    
    std::vector<Sprite*> _thumbs;
    float _thumbWidth;
    float _thumbHeight;
    DragView *_dragView;
    
    SptLoader *_sptLoader;
    uint64_t _minPackId;
};

class MainContainerLayer : public Layer,  public MenuBarListener {
public:
    static MainContainerLayer* create();
    bool init();
    Scene* getScene();
    
    //MenuBarListener
    virtual void onMenuBarSelect(uint32_t idx);

    
private:
    enum {
        LAYER_NUM = 5,
    };
    Layer* _layers[LAYER_NUM];
};

#endif // __COLLECTION_LIST_SCENE_H__
