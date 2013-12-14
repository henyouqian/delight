#ifndef __SLIDER_SCENE_H__
#define __SLIDER_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

struct Slider {
    Slider();
    Sprite *sprite;
    unsigned int idx;
    Touch *touch;
};

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
    
    void onHttpGet(HttpClient* client, HttpResponse* response);
    
private:
    void loadTexture(const char *filename);
    std::list<Slider> _sliders;
    Texture2D *_texture;
    int _texW, _texH;
    std::string _currFileName;
    int _sliderNum;
    float _sliderX0;
    float _sliderY0;
    float _sliderH;
};

#endif // __SLIDER_SCENE_H__
