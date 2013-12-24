#include "gifTexture.h"
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

GifTexture* GifTexture::create(const char *filename, Node* parentNode, bool turnRight)
{
    GifTexture *p = new GifTexture();
    if (p && p->initWithFile(filename, parentNode, turnRight)) {
        p->autorelease();
        return p;
    }
    CC_SAFE_DELETE(p);
    return nullptr;
}

GifTexture::GifTexture()
:_buf(nullptr), _turnRight(false){
    
}

bool GifTexture::initWithFile(const char *filename, Node* parentNode, bool turnRight)
{
    CCASSERT(filename != NULL, "Invalid filename for sprite");
    _nodeForAction = Node::create();
    _nodeForAction->retain();
    parentNode->addChild(_nodeForAction);
    
    auto path = FileUtils::getInstance()->fullPathForFilename(filename);
    int err = GIF_OK;
    _gifFile = DGifOpenFileName(path.c_str(), &err);
    if (err != GIF_OK) {
        return false;
    }
    err = DGifSlurp(_gifFile);
    if (err != GIF_OK) {
        return false;
    }
    
    _turnRight = turnRight;
    
    _width2 = _height2 = 0;
    _currFrame = 0;
    _sWidth = _gifFile->SWidth;
    _sHeight = _gifFile->SHeight;
    if (_turnRight) {
        _sWidth = _gifFile->SHeight;
        _sHeight = _gifFile->SWidth;
    }
    
    updateBuf();
    
    this->initWithData(_buf, _bufLen, Texture2D::PixelFormat::RGBA8888, _width2, _height2, Size(_sWidth, _sHeight));
    
    //palyback
    if (_gifFile->ImageCount > 1) {
        auto delayTime = DelayTime::create(_currFrameDuration*0.001f);
        auto cb = CallFunc::create(std::bind(&GifTexture::nextFrame, this));
        auto seq = Sequence::create(delayTime, cb, NULL);
        
        _nodeForAction->runAction(seq);
    }
    
#if CC_ENABLE_CACHE_TEXTURE_DATA
    VolatileTexture::addDataTexture(this, _buf, _bufLen, Texture2D::PixelFormat::RGBA8888, Size(_width2, _height2));
#endif
    
    return true;
}

GifTexture::~GifTexture() {
    if (_buf)
        delete [] _buf;
    _nodeForAction->stopAllActions();
    _nodeForAction->release();
    _nodeForAction->removeFromParent();
    DGifCloseFile(_gifFile);
}

void GifTexture::getScreenSize(int &width, int &height) {
    width = _sWidth;
    height = _sHeight;
}

void GifTexture::nextFrame() {
    _currFrame++;
    if (_currFrame >= _gifFile->ImageCount) {
        _currFrame = 0;
    }
    
    updateBuf();
    
    auto glid = this->getName();
    GL::bindTexture2D(glid);
    
    const Texture2D::PixelFormatInfo& info = Texture2D::getPixelFormatInfoMap().at(this->getPixelFormat());
    glTexImage2D(GL_TEXTURE_2D, 0, info.internalFormat, (GLsizei)_width2, (GLsizei)_height2, 0, info.format, info.type, _buf);

    
    //palyback
    if (_gifFile->ImageCount > 1) {
        auto delayTime = DelayTime::create(_currFrameDuration*0.001f);
        auto cb = CallFunc::create(std::bind(&GifTexture::nextFrame, this));
        auto seq = Sequence::create(delayTime, cb, NULL);
        _nodeForAction->runAction(seq);
    }
}

void GifTexture::updateBuf() {
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



