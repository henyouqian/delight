#ifndef __SLIDER_SCENE_H__
#define __SLIDER_SCENE_H__

#include "cocos2d.h"

USING_NS_CC;

class SliderScene : public cocos2d::Layer
{
public:
    static cocos2d::Scene* createScene();
    virtual bool init();
    CREATE_FUNC(SliderScene);
    virtual ~SliderScene();
    
    void reset(const char *filename, int nPieces);
    
    virtual void onTouchesBegan(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesMoved(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesEnded(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesCancelled(const std::vector<Touch*>&touches, Event *event);
    
private:
    void loadTexture(const char *filename);
    std::vector<Sprite*> _sprites;
    Texture2D *_texture;
    int _texW, _texH;
    std::string _currFileName;
};

#endif // __SLIDER_SCENE_H__
