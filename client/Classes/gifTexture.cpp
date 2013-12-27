#include "gifTexture.h"
#include "util.h"
#include "giflib/gif_lib.h"
#include "lw/lwLog.h"

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

GifTexture* GifTexture::create(const char *filename, Node* parentNode, bool turnRight) {
    GifTexture *p = new GifTexture();
    if (p && p->initWithFile(filename, parentNode, turnRight)) {
        p->autorelease();
        return p;
    }
    CC_SAFE_DELETE(p);
    return nullptr;
}

GifTexture* GifTexture::create(GifFileType *gifFileType, Node* parentNode, bool turnRight) {
    GifTexture *p = new GifTexture();
    if (p && p->initWithGifFileType(gifFileType, parentNode, turnRight)) {
        p->autorelease();
        return p;
    }
    CC_SAFE_DELETE(p);
    return nullptr;
}

Sprite* GifTexture::createSprite(const char *filename, Node* parentNode) {
    auto texture = GifTexture::create(filename, parentNode, false);
    if (!texture) {
        lwerror("GifTexture::create failed: %s", filename);
        return nullptr;
    }
    auto sprite = Sprite::createWithTexture(texture);
    return sprite;
}

bool GifTexture::isGif(const char *path) {
    auto fu = FileUtils::getInstance();
    std::string fullpath = path;
    if (!fu->isAbsolutePath(fullpath)) {
        fullpath = fu->fullPathForFilename(path);
        if (fullpath.empty()) {
            return false;
        }
    }
    auto f = fopen(fullpath.c_str(), "rb");
    char buf[3];
    fread(buf, 3, 1, f);
    bool isGif = false;
    if (buf[0] == 'G' && buf[1] == 'I' && buf[2] == 'F') {
        isGif = true;
    }
    fclose(f);
    return isGif;
}

GifTexture::GifTexture()
:_buf(nullptr), _turnRight(false){
    
}

bool GifTexture::initWithFile(const char *filename, Node* parentNode, bool turnRight) {
    CCASSERT(filename != NULL, "Invalid filename for sprite");
    _nodeForAction = Node::create();
    _nodeForAction->retain();
    parentNode->addChild(_nodeForAction);
    
    auto fu = FileUtils::getInstance();
    auto path = fu->fullPathForFilename(filename);
    //try load from writeable dir
    std::string finalPath;
    makeLocalGifPath(finalPath, path.c_str());
    if (!fu->isFileExist(finalPath)) {
        //copy to writeable dir
        unsigned long size;
        auto data = fu->getFileData(path.c_str(), "rb", &size);
        auto f = fopen(finalPath.c_str(), "wb");
        fwrite(data, size, 1, f);
        fclose(f);
        delete [] data;
    }
    
    int err = GIF_OK;
    _gifFile = DGifOpenFileName(finalPath.c_str(), &err);
    if (err != GIF_OK) {
        return false;
    }
    err = DGifSlurp(_gifFile);
    if (err != GIF_OK) {
        return false;
    }
    
    _turnRight = turnRight;
    _speed = 1.f;
    
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
    _contentSize.setSize(_sWidth, _sHeight);
    
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

bool GifTexture::initWithGifFileType(GifFileType *gifFile, Node* parentNode, bool turnRight) {
    _nodeForAction = Node::create();
    _nodeForAction->retain();
    parentNode->addChild(_nodeForAction);
    
    _gifFile = gifFile;
    
    _turnRight = turnRight;
    _speed = 1.f;
    
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
    
    _contentSize.setSize(_sWidth, _sHeight);
    
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

void GifTexture::setSpeed(float speed) {
    _speed = speed;
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
        auto delayTime = DelayTime::create(_currFrameDuration*0.001f/_speed);
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
    GraphicsControlBlock gcb;
    for (auto i = 0; i < img->ExtensionBlockCount; ++i) {
        auto extBlk = img->ExtensionBlocks + i;
        if (extBlk->Function == GRAPHICS_EXT_FUNC_CODE) {
            auto ext = extBlk->Bytes;
            if( ext[0] & 1 ) {
                hasTrans = true;
                transIdx = ext[3];
            }
            DGifExtensionToGCB(extBlk->ByteCount, extBlk->Bytes, &gcb);
            _currFrameDuration = gcb.DelayTime * 10;
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
                    if (gcb.DisposalMode == DISPOSE_BACKGROUND) {
                        char *p = _buf + (_width2*y+x)*4;
                        auto bgColor = &(colorMap->Colors[_gifFile->SBackGroundColor]);
                        p[0] = bgColor->Red;
                        p[1] = bgColor->Green;
                        p[2] = bgColor->Blue;
                        p[3] = 0x00;
                    }
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
                    if (gcb.DisposalMode == DISPOSE_BACKGROUND) {
                        char *p = _buf + (_width2*y+x)*4;
                        auto bgColor = &(colorMap->Colors[_gifFile->SBackGroundColor]);
                        p[0] = bgColor->Red;
                        p[1] = bgColor->Green;
                        p[2] = bgColor->Blue;
                        p[3] = 0x00;
                    }
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



