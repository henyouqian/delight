#ifndef __GAMEPLAY_H__
#define __GAMEPLAY_H__

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

class Gameplay {
public:
    Gameplay(Rect &rect, Node *parentNode);
    ~Gameplay();
    void reset(const char *filename, int sliderNum);
    
    void onTouchesBegan(const std::vector<Touch*>& touches);
    void onTouchesMoved(const std::vector<Touch*>& touches);
    void onTouchesEnded(const std::vector<Touch*>& touches);
    
private:
    void loadTexture(const char *filename);
    
    Rect _rect;
    int _sliderNum;
    std::list<Slider> _sliders;
    Texture2D *_texture;
    int _texW, _texH;
    std::string _currFileName;
    float _sliderX0;
    float _sliderY0;
    float _sliderH;
    Node *_parentNode;
};


#endif // __GAMEPLAY_H__
