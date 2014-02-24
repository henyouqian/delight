#include "gameplay.h"
#include "gifTexture.h"
#include "SimpleAudioEngine.h"
#include "lw/lwLog.h"
#include <sys/stat.h>

USING_NS_CC;
USING_NS_CC_EXT;

using namespace CocosDenshion;

static const char *SND_TINK = "audio/tink.wav";
static const char *SND_SUCCESS = "audio/success.aiff";
static const char *SND_FINISH = "audio/finish.aiff";

namespace {
    void shuffle(std::vector<int> &vec, int num) {
        vec.clear();
        std::vector<int> v;
        for (int i = 0; i < num; ++i) {
            v.push_back(i);
        }
        int last = 9999;
        for (int i = 0; i < num; ++i) {
            int r = rand() % v.size();
            if (v[r]-last == 1) {
                vec.pop_back();
                vec.push_back(v[r]);
                vec.push_back(last);
            } else {
                vec.push_back(v[r]);
                last = v[r];
            }
            
            v.erase(v.begin()+r);
        }
    }
    
    const float MOVE_DURATION = .1f;
}

Slider::Slider() {
    sprite = nullptr;
    idx = 0;
    touch = nullptr;
}

Gameplay::Gameplay(GameplayListener *listener) {
    Node::init();
    _listener = listener;
    _texW = _texH = 0;
    _texture = nullptr;
    _isCompleted = false;
    _running = false;
    _currSliderGrp = nullptr;
    _newSliderGrp = nullptr;
    _isLast = false;
    
    SimpleAudioEngine::getInstance()->preloadEffect(SND_TINK);
    SimpleAudioEngine::getInstance()->preloadEffect(SND_SUCCESS);
    SimpleAudioEngine::getInstance()->preloadEffect(SND_FINISH);
    
    _sptLoader = SptLoader::create(this);
    this->addChild(_sptLoader);
    
    auto visSize = Director::getInstance()->getVisibleSize();
    
    //bg
    auto bgBatch = SpriteBatchNode::create("ui/stripedBg.png");
    this->addChild(bgBatch);
    auto bg = Sprite::create("ui/stripedBg.png");
    float y = 0;
    while (y < visSize.height) {
        float x = 0;
        while (x < visSize.width) {
            auto bg = Sprite::create("ui/stripedBg.png");
            bg->setAnchorPoint(Point(0, 0));
            bg->setPosition(Point(x, y));
            bgBatch->addChild(bg);
            x += bg->getContentSize().width;
        }
        y += bg->getContentSize().height;
    }
}

Gameplay::~Gameplay() {
    if (_texture) {
        _texture->release();
    }
    if (_sptLoader) {
        _sptLoader->destroy();
    }
    for (auto it = _preloads.begin(); it != _preloads.end(); ++it) {
        if (it->texture) {
            it->texture->release();
        }
    }
    TextureCache::getInstance()->removeUnusedTextures();
    
    SimpleAudioEngine::getInstance()->unloadEffect(SND_TINK);
    SimpleAudioEngine::getInstance()->unloadEffect(SND_SUCCESS);
    SimpleAudioEngine::getInstance()->unloadEffect(SND_FINISH);
}

void Gameplay::preload(const char *filePath) {
    for (auto it = _preloads.begin(); it != _preloads.end(); ++it) {
        if (it->imgPath.compare(filePath) == 0) {
            lwinfo("already preload");
            return;
        }
    }
    
    while (_preloads.size() >= 2) {
        auto texture = _preloads.front().texture;
        if (texture) {
            texture->release();
        }
        _preloads.pop_front();
    }
    
    Preload pl;
    pl.imgPath = filePath;
    pl.texture = nullptr;
    _preloads.push_back(pl);
    _sptLoader->load(filePath);
}

void Gameplay::reset(const char *filePath, int sliderNum, bool isLast) {
    _resetImagePath = filePath;
    _sliderNum = sliderNum;
    _running = false;
    _isLast = isLast;
    
    bool textureLoaded = false;
    auto it = _preloads.begin();
    for (; it != _preloads.end(); ++it) {
        if (it->imgPath.compare(filePath) == 0 && it->texture) {
            textureLoaded = true;
            break;
        }
    }
    
    if (textureLoaded) {
        resetNow(it);
    } else {
        preload(filePath);
    }
}

//void Gameplay::loadTexture(const char *filePath) {
//    if (_currFileName.compare(filePath) == 0) {
//        return;
//    }
//    
//    if (_texture) {
//        _texture->release();
//        _texture = nullptr;
//    }
//    
//    //try gif first
//    auto gifTex = GifTexture::create(filePath, this, false);
//    if (gifTex) {
//        _texture = gifTex;
//        gifTex->getScreenSize(_texW, _texH);
//    } else {
//        _texture = TextureCache::getInstance()->addImage(filePath);
//        _texW = _texture->getPixelsWide();
//        _texH = _texture->getPixelsHigh();
//    }
//    
//    _currFileName = filePath;
//    _texture->retain();
//    _texW -= 1;//-1 edge problem
//    _texH -= 1;//-1 edge problem
//}


bool Gameplay::isCompleted() {
    return _isCompleted;
}

void Gameplay::onTouchesBegan(const std::vector<Touch*>& touches) {
    auto touch = touches[0];
    
    if (_isCompleted) {
        return;
    }
    for (auto it = _sliders.begin(); it != _sliders.end(); ++it) {
        if (!it->touch && it->sprite->getBoundingBox().containsPoint(touch->getLocation())) {
            it->touch = touch;
            it->sprite->setZOrder(1);
            it->sprite->stopAllActions();
            break;
        }
    }
}

void Gameplay::onTouchesMoved(const std::vector<Touch*>& touches) {
    auto touch = touches[0];
    int i = 0;
    bool resort = false;
    for (auto it = _sliders.begin(); it != _sliders.end(); ++it, ++i) {
        if (it->touch && it->touch == touch) {
            auto y = it->sprite->getPositionY()+touch->getDelta().y;
            it->sprite->setPositionY(y);
            int toI = int(roundf((_sliderY0-y)/_sliderH));
            toI = MAX(0, MIN(_sliderNum-1, toI));
            if (toI != i) {
                resort = true;
                auto slider = *it;
                _sliders.erase(it);
                auto insertIt = _sliders.begin();
                for (auto i = 0; i < toI; ++i) {
                    insertIt++;
                }
                _sliders.insert(insertIt, slider);
            }
            break;
        }
    }
    if (resort) {
        SimpleAudioEngine::getInstance()->playEffect(SND_TINK);
        int i = 0;
        for (auto it = _sliders.begin(); it != _sliders.end(); ++it, ++i) {
            float y = _sliderY0 - i * _sliderH;
            if (!it->touch && it->sprite->getPositionY() != y) {
                auto moveTo = MoveTo::create(MOVE_DURATION, Point(_sliderX0, y));
                auto easeOut = EaseSineOut::create(moveTo);
                it->sprite->stopAllActions();
                it->sprite->runAction(easeOut);
            }
        }
    }
}

void Gameplay::onTouchesEnded(const std::vector<Touch*>& touches) {
    if (_sliders.empty()) {
        return;
    }
    auto touch = touches[0];
    int i = 0;
    bool complete = true;
    for (auto it = _sliders.begin(); it != _sliders.end(); ++it, ++i) {
        if (it->touch && it->touch == touch) {
            it->touch = nullptr;
            it->sprite->setZOrder(0);
            
            float y = _sliderY0 - i * _sliderH;
            auto moveTo = MoveTo::create(MOVE_DURATION, Point(_sliderX0, y));
            auto easeOut = EaseSineOut::create(moveTo);
            it->sprite->stopAllActions();
            it->sprite->runAction(easeOut);
            //break;
        }
        if (it->idx != i) {
            complete = false;
        }
    }
    if (_isCompleted == false && complete == true && _running) {
        if (_isLast) {
            SimpleAudioEngine::getInstance()->playEffect(SND_FINISH);
        } else {
            SimpleAudioEngine::getInstance()->playEffect(SND_SUCCESS);
        }
    }
    _isCompleted = complete;
}

void Gameplay::onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData) {
    auto texture = sprite->getTexture();
    texture->retain();
    
    auto gifTexture = dynamic_cast<GifTexture*>(texture);
    if (gifTexture) {
        gifTexture->pause();
    }
    
    bool found = false;
    for (auto it = _preloads.begin(); it != _preloads.end(); ++it) {
        if (it->imgPath.compare(localPath) == 0) {
            found = true;
            if (it->texture) {
                it->texture->release();
            } else {
                it->texture = texture;
            }
            if (_resetImagePath.compare(localPath) == 0) {
                resetNow(it);
            }
            break;
        }
    }
    if (!found) {
        texture->release();
        return;
    }
}

void Gameplay::resetNow(std::list<Preload>::iterator it) {
//    for (auto it = _sliders.begin(); it != _sliders.end(); ++it) {
//        it->sprite->removeFromParent();
//    }
    
    if (_texture) {
        _texture->release();
    }
    _texture = it->texture;
    _preloads.erase(it);
    
    //
    auto gifTexture = dynamic_cast<GifTexture*>(_texture);
    if (gifTexture) {
        gifTexture->resume();
    }
    
    //
    auto sz = _texture->getContentSize();
    _texW = sz.width;
    _texH = sz.height;
    _texW -= 1;//-1 edge problem
    _texH -= 1;//-1 edge problem
    
    _isCompleted = false;
    _sliders.clear();
    
    //create sliders
    float fTexW = _texW;
    float fTexH = _texH;
    auto visSize = Director::getInstance()->getVisibleSize();
    auto size = visSize;
    
    //calc target ratio
    float texRatio = fTexW/fTexH;
    if (fTexW > fTexH) {
        texRatio = fTexH/fTexW;
    }
    float visRatio = visSize.width/visSize.height;
    texRatio += 0.001;
    float refRatios[] = {
        9.f/16.f,
        2.f/3.f,
        3.f/4.f,
    };
    float targetRatio = visRatio;
    //float minDiff = fabs(visRatio-texRatio);
    for (auto i = 0; i < sizeof(refRatios)/sizeof(refRatios[0]); ++i) {
        if (refRatios[i] > visRatio) {
            //float diff = fabs(refRatios[i]-texRatio);
//            if (diff < minDiff) {
//                minDiff = diff;
//                targetRatio = refRatios[i];
//            }
            if (texRatio >= refRatios[i]) {
                targetRatio = refRatios[i];
            }
        }
    }
    size.height = size.width/targetRatio;// 640*4.f/3.f;
    
    //scale
    float scaleW = size.width / _texW;
    float scaleH = size.height/ _texH;
    if (_texW > _texH) {
        scaleW = size.width / _texH;
        scaleH = size.height/ _texW;
    }
    float scale = MAX(scaleW, scaleH);
    
    //shuffle idx
    std::vector<int> idxVec;
    shuffle(idxVec, _sliderNum);
    
    //
    if (_newSliderGrp) {
        _newSliderGrp->removeFromParent();
    }
    _newSliderGrp = new NodeRGBA;
    _newSliderGrp->init();
    _newSliderGrp->autorelease();
    _newSliderGrp->setCascadeOpacityEnabled(true);
    addChild(_newSliderGrp);
    bool rotRight = false;
    
    //slider
    float uvW = 0;
    float uvH = 0;
    float uvX = 0;
    float uvY = 0;
    if (fTexW <= fTexH) {
        if (fTexW/fTexH <= size.width/size.height) { //slim
            uvW = fTexW;
            uvH = uvW * (size.height/size.width);
            uvY = (fTexH - uvH) * .5f;
        } else {    //fat
            uvH = fTexH;
            uvW = uvH * (size.width/size.height);
            uvX = (fTexW - uvW) * .5f;
        }
        float uvy = uvY;
        float uvh = uvH / _sliderNum;
        _sliderH = size.height / _sliderNum;
        _sliderX0 = size.width * .5f;
        _sliderY0 = (size.height + visSize.height)*.5f - _sliderH * .5f;
        
        for (auto i = 0; i < _sliderNum; ++i) {
            uvy = uvY+uvh*idxVec[i];
            auto spt = Sprite::createWithTexture(_texture, Rect(uvX, uvy, uvW, uvh));
            
            float y = _sliderY0 - i * _sliderH;
            spt->setPosition(Point(_sliderX0, y));
            
            spt->setScale(scale);
            _newSliderGrp->addChild(spt);
            Slider slider;
            slider.sprite = spt;
            slider.idx = idxVec[i];
            _sliders.push_back(slider);
        }
    } else {
        rotRight = true;
        if (fTexW/fTexH <= size.height/size.width) { //slim
            uvW = fTexW;
            uvH = uvW * (size.width/size.height);
            uvY = (fTexH - uvH) * .5f;
        } else { //fat
            uvH = fTexH;
            uvW = uvH * (size.height/size.width);
            uvX = (fTexW - uvW) * .5f;
        }
        float uvx = uvX;
        float uvw = uvW / _sliderNum;
        _sliderH = size.height / _sliderNum;
        _sliderX0 = size.width * .5f;
        _sliderY0 = (size.height + visSize.height)*.5f - _sliderH * .5f;
        for (auto i = 0; i < _sliderNum; ++i) {
            uvx = uvX+uvw*idxVec[i];
            auto spt = Sprite::createWithTexture(_texture, Rect(uvx, uvY, uvw, uvH));
            
            float y = _sliderY0 - i * _sliderH;
            spt->setPosition(Point(_sliderX0, y));
            spt->setRotation(90.f);
            
            spt->setScale(scale);
            _newSliderGrp->addChild(spt);
            
            Slider slider;
            slider.sprite = spt;
            slider.idx = idxVec[i];
            _sliders.push_back(slider);
        }
    }
    
    if (!_currSliderGrp) {
        _currSliderGrp = _newSliderGrp;
        _newSliderGrp = nullptr;
        auto fadeIn = FadeIn::create(.3f);
        auto easeFadeIn = EaseSineOut::create(fadeIn);
        _currSliderGrp->setOpacity(0);
        _currSliderGrp->runAction(easeFadeIn);
    } else {
        if (_rotRight) {
            _newSliderGrp->setPositionY(-size.width);
        } else {
            _newSliderGrp->setPositionX(size.width);
        }
        auto moveTo = MoveTo::create(.3f, Point(0.f, 0.f));
        auto ease = EaseSineOut::create(moveTo);
        auto fadeIn = FadeIn::create(.3f);
        auto easeFadeIn = EaseSineOut::create(fadeIn);
        auto spawn = Spawn::create(ease, easeFadeIn, NULL);
        
        _newSliderGrp->setOpacity(0);
        _newSliderGrp->runAction(spawn);
        
        auto delay = DelayTime::create(.3f);
        auto fadeOut = FadeOut::create(.3f);
        auto easeFadeOut = EaseSineOut::create(fadeOut);
        auto cb = CallFunc::create(std::bind(&Gameplay::onImageChanged, this));
        auto seq = Sequence::create(delay, easeFadeOut, cb, nullptr);
        _currSliderGrp->runAction(seq);
    }
    
    _rotRight = rotRight;
    
    if (rotRight) {
        _listener->onReset(90.f);
    } else {
        _listener->onReset(0.f);
    }
    
    _running = true;
}

void Gameplay::onImageChanged() {
    _currSliderGrp->removeFromParent();
    _currSliderGrp = _newSliderGrp;
    _newSliderGrp = nullptr;
    
     TextureCache::getInstance()->removeUnusedTextures();
}

void Gameplay::onSptLoaderError(const char *localPath, void *userData) {
    //CCASSERT(0, "onSptLoaderError");
    lwerror("image load error: localPath = %s", localPath);
    //fixme: add error handling
    
}
