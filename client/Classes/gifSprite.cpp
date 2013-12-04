#include "gifSprite.h"
#include "giflib/gif_lib.h"

USING_NS_CC;

namespace {
    int pwr2Size(int in) {
        int out = 2;
        while (1) {
            if (out >= in)
                return out;
            out *= 2;
        }
    }
}

GifSprite* GifSprite::create(const char *filename)
{
    GifSprite *sprite = new GifSprite();
    if (sprite && sprite->initWithFile(filename))
    {
        sprite->autorelease();
        return sprite;
    }
    CC_SAFE_DELETE(sprite);
    return nullptr;
}

bool GifSprite::initWithFile(const char *filename)
{
    CCASSERT(filename != NULL, "Invalid filename for sprite");
    
    auto path = FileUtils::getInstance()->fullPathForFilename(filename);
    int err = GIF_OK;
    _gifFile = DGifOpenFileName(path.c_str(), &err);
    err = DGifSlurp(_gifFile);
    
    if (err == GIF_ERROR) {
        return false;
    }
    
    int pwr2Width = pwr2Size(_gifFile->SWidth);
    int pwr2Height = pwr2Size(_gifFile->SHeight);
    
    size_t len = pwr2Width*pwr2Height*4;
    char *buf = new char[len];
    memset(buf, 0, len);
    
    auto *img = _gifFile->SavedImages;
    auto imgDesc = img->ImageDesc;
    auto colorMap = imgDesc.ColorMap;
    auto imgBuf = img->RasterBits;
    if (!colorMap) {
        colorMap = _gifFile->SColorMap;
    }
    
    //ext code
    int delay = 0;
    bool hasTrans = false;
    unsigned char transIdx = 0;
    for (auto i = 0; i < img->ExtensionBlockCount; ++i) {
        auto extBlk = img->ExtensionBlocks + i;
        if (extBlk->Function == GRAPHICS_EXT_FUNC_CODE) {
            auto ext = extBlk->Bytes;
            delay = (ext[2] << 8 | ext[1]) * 10;
            if( ext[0] & 1 ) {
                hasTrans = true;
                transIdx = ext[3];
            }
            break;
        }
    }
    
    //read pixel
    int i = 0;
    for (auto y = imgDesc.Top; y < imgDesc.Top+imgDesc.Height; ++y) {
        for (auto x = imgDesc.Left; x < imgDesc.Left+imgDesc.Width; ++x) {
            unsigned char colorIdx = imgBuf[i];
            
            if (hasTrans && colorIdx == transIdx) {
                ++i;
                continue;
            }
            
            auto color = &(colorMap->Colors[imgBuf[i]]);
            char *p = buf + (pwr2Width*y+x)*4;
            p[0] = color->Red;
            p[1] = color->Green;
            p[2] = color->Blue;
            p[3] = 0xff;
            ++i;
        }
    }
    
    auto texture = new Texture2D();
    texture->initWithData(buf, len, Texture2D::PixelFormat::RGBA8888, pwr2Width, pwr2Height, Size(pwr2Width, pwr2Height));
    
    Rect rect(0, 0, _gifFile->SWidth, _gifFile->SHeight);
    Sprite::initWithTexture(texture, rect);
    
    //palyback
    if (_gifFile->ImageCount > 1) {
        auto delayTime = DelayTime::create(delay*0.001f);
        auto cb = CallFunc::create(std::bind(&GifSprite::nextFrame, this));
        auto seq = Sequence::create(delayTime, cb, NULL);
        this->runAction(seq);
    }
    
    //clean up
    delete [] buf;
    DGifCloseFile(_gifFile);
    return true;
}

GifSprite::~GifSprite() {
    DGifCloseFile(_gifFile);
}

void GifSprite::nextFrame() {
    
}
