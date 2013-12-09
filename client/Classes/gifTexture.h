#ifndef __GIF_TEXTURE_H__
#define __GIF_TEXTURE_H__

#include "cocos2d.h"

USING_NS_CC;

struct GifFileType;

class GifTexture : public Texture2D
{
public:
    static GifTexture* create(const char *filename, Node* parentNode, bool turnRight);
    bool initWithFile(const char *filename, Node* parentNode, bool turnRight);
    GifTexture();
    virtual ~GifTexture();
    
    void getScreenSize(int &width, int &height);
    
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
    
    bool _turnRight;
    Node *_nodeForAction;
};

#endif // __GIF_TEXTURE_H__
