#ifndef __GAMEPLAY_H__
#define __GAMEPLAY_H__

#include "spriteLoader.h"
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

class GameplayListener {
public:
    virtual ~GameplayListener(){};
    virtual void onImageRotate(float rotate){}
};

class Gameplay : public Node, public SptLoaderListener{
public:
    Gameplay(Rect &rect, GameplayListener *listener);
    ~Gameplay();
    void preload(const char *filePath);
    void reset(const char *filePath, int sliderNum);
    bool isCompleted();
    
    void onTouchesBegan(const std::vector<Touch*>& touches);
    void onTouchesMoved(const std::vector<Touch*>& touches);
    void onTouchesEnded(const std::vector<Touch*>& touches);
    
    //SptLoaderListener
    virtual void onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData);
    virtual void onSptLoaderError(const char *localPath, void *userData);
    
private:
    void loadTexture(const char *filename);
    void onChangeImage();
    
    GameplayListener *_listener;
    Rect _rect;
    int _sliderNum;
    std::list<Slider> _sliders;
    Texture2D *_texture;
    int _texW, _texH;
    std::string _currFileName;
    float _sliderX0;
    float _sliderY0;
    float _sliderH;
    bool _isCompleted;
    
    SptLoader *_sptLoader;
    
    struct Preload {
        std::string imgPath;
        Texture2D *texture;
    };
    std::list<Preload> _preloads;
    std::string _resetImagePath;
    void resetNow(std::list<Preload>::iterator it);
    
    Node *_currSliderGrp;
    Node *_newSliderGrp;
    bool _rotRight;
    
    bool _running;
};


#endif // __GAMEPLAY_H__
