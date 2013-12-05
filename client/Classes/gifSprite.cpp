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
    
    //for test
    _turnRight = true;
    
    _width2 = _height2 = 0;
    _buf = nullptr;
    _currFrame = 0;
    auto sWidth = _gifFile->SWidth;
    auto sHeight = _gifFile->SHeight;
    if (_turnRight) {
        sWidth = _gifFile->SHeight;
        sHeight = _gifFile->SWidth;
    }
    
    
    updateBuf();
    
    auto texture = new Texture2D();
    texture->initWithData(_buf, _bufLen, Texture2D::PixelFormat::RGBA8888, _width2, _height2, Size(_width2, _height2));
    
    Rect rect(0, 0, sWidth, sHeight);
    Sprite::initWithTexture(texture, rect);
    
    //palyback
    if (_gifFile->ImageCount > 1) {
        auto delayTime = DelayTime::create(_currFrameDuration*0.001f);
        auto cb = CallFunc::create(std::bind(&GifSprite::nextFrame, this));
        auto seq = Sequence::create(delayTime, cb, NULL);
        this->runAction(seq);
    }
    
    return true;
}

GifSprite::~GifSprite() {
    delete [] _buf;
    DGifCloseFile(_gifFile);
}

void GifSprite::nextFrame() {
    _currFrame++;
    if (_currFrame >= _gifFile->ImageCount) {
        _currFrame = 0;
    }
    
    updateBuf();
    
    auto texture = getTexture();
    auto glid = texture->getName();
    GL::bindTexture2D(glid);
    
    const Texture2D::PixelFormatInfo& info = Texture2D::getPixelFormatInfoMap().at(texture->getPixelFormat());
    glTexImage2D(GL_TEXTURE_2D, 0, info.internalFormat, (GLsizei)_width2, (GLsizei)_height2, 0, info.format, info.type, _buf);

    
    //palyback
    if (_gifFile->ImageCount > 1) {
        auto delayTime = DelayTime::create(_currFrameDuration*0.001f);
        auto cb = CallFunc::create(std::bind(&GifSprite::nextFrame, this));
        auto seq = Sequence::create(delayTime, cb, NULL);
        this->runAction(seq);
    }
}

void GifSprite::updateBuf() {
    CCASSERT(_currFrame < _gifFile->ImageCount, "invalid frameIdx");
    
    if (_buf == nullptr) {
        _width2 = pwr2Size(_gifFile->SWidth);
        _height2 = pwr2Size(_gifFile->SHeight);
        
        if (_turnRight) {
            auto tmp = _width2;
            _width2 = _height2;
            _height2 = tmp;
        }
        
        _bufLen = _width2*_height2*4;
        _buf = new char[_bufLen];
        memset(_buf, 0, _bufLen);
    }
    
    
    auto *img = _gifFile->SavedImages + _currFrame;
    auto imgDesc = img->ImageDesc;
    auto colorMap = imgDesc.ColorMap;
    auto imgBuf = img->RasterBits;
    if (!colorMap) {
        colorMap = _gifFile->SColorMap;
    }
    
    //ext code
    _currFrameDuration = 0;
    bool hasTrans = false;
    unsigned char transIdx = 0;
    for (auto i = 0; i < img->ExtensionBlockCount; ++i) {
        auto extBlk = img->ExtensionBlocks + i;
        if (extBlk->Function == GRAPHICS_EXT_FUNC_CODE) {
            auto ext = extBlk->Bytes;
            _currFrameDuration = (ext[2] << 8 | ext[1]) * 10;
            if( ext[0] & 1 ) {
                hasTrans = true;
                transIdx = ext[3];
            }
            break;
        }
    }
    
    //read pixel
    int i = 0;
    
    if (_turnRight) {
        for (auto x = _gifFile->SHeight-imgDesc.Top-1; x >= _gifFile->SHeight-imgDesc.Top-imgDesc.Height; --x) {
            for (auto y = imgDesc.Left; y < imgDesc.Left+imgDesc.Width; ++y) {
                unsigned char colorIdx = imgBuf[i];
                
                if (hasTrans && colorIdx == transIdx) {
                    ++i;
                    continue;
                }
                
                auto color = &(colorMap->Colors[imgBuf[i]]);
                char *p = _buf + (_width2*y+x)*4;
                p[0] = color->Red;
                p[1] = color->Green;
                p[2] = color->Blue;
                p[3] = 0xff;
                ++i;
            }
        }
    } else {
        for (auto y = imgDesc.Top; y < imgDesc.Top+imgDesc.Height; ++y) {
            for (auto x = imgDesc.Left; x < imgDesc.Left+imgDesc.Width; ++x) {
                unsigned char colorIdx = imgBuf[i];
                
                if (hasTrans && colorIdx == transIdx) {
                    ++i;
                    continue;
                }
                
                auto color = &(colorMap->Colors[imgBuf[i]]);
                char *p = _buf + (_width2*y+x)*4;
                p[0] = color->Red;
                p[1] = color->Green;
                p[2] = color->Blue;
                p[3] = 0xff;
                ++i;
            }
        }
    }
}
