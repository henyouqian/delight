#ifndef __GIF_SPRITE_H__
#define __GIF_SPRITE_H__

#include "cocos2d.h"

USING_NS_CC;

struct GifFileType;

class GifSprite : public Sprite
{
public:
    static GifSprite* create(const char *filename);
    bool initWithFile(const char *filename);
    virtual ~GifSprite();
    
    void nextFrame();
    
private:
    GifFileType *_gifFile;
    char *_buf;
    size_t _bufLen;
    int _currFrame;
};

#endif // __GIF_SPRITE_H__
