#ifndef __GIF_TEXTURE_H__
#define __GIF_TEXTURE_H__

#include "cocos2d.h"

USING_NS_CC;

struct GifFileType;

class GifTexture : public Texture2D
{
public:
    static GifTexture* create(const char *filename, Node* parentNode, bool turnRight);
    static GifTexture* create(GifFileType *gifFileType, Node* parentNode, bool turnRight);
    static Sprite* createSprite(const char *filename, Node* parentNode);
    static bool isGif(const char *path);
    
    bool initWithFile(const char *filename, Node* parentNode, bool turnRight);
    bool initWithGifFileType(GifFileType *gifFileType, Node* parentNode, bool turnRight);
    GifTexture();
    virtual ~GifTexture();
    
    void getScreenSize(int &width, int &height);
    void setSpeed(float speed);
    
    void nextFrame();
    
private:
    void updateBuf();
    
    GifFileType *_gifFile;
    char *_buf;
    size_t _bufLen;
    int _currFrame;
    int _currFrameDuration;
    int _width2, _height2;
    int _sWidth, _sHeight;
    float _speed;
    
    bool _turnRight;
    Node *_nodeForAction;
};

#endif // __GIF_TEXTURE_H__
