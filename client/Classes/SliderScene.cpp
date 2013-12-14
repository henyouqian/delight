#include "SliderScene.h"
#include "gifTexture.h"
#include "lw/lwLog.h"
#include "SimpleAudioEngine.h"
#include <sys/stat.h>

USING_NS_CC;
USING_NS_CC_EXT;
using namespace CocosDenshion;

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
    
//    void shuffle(std::vector<int> &vec, int num) {
//        int n = 0;
//        while (true) {
//            vec.clear();
//            std::vector<int> v;
//            for (int i = 0; i < num; ++i) {
//                v.push_back(i);
//            }
//            int serial = 0;
//            int last = -11111;
//            for (int i = 0; i < num; ++i) {
//                int r = rand() % v.size();
//                vec.push_back(v[r]);
//                if (v[r] - last == 1) {
//                    serial++;
//                    break;
//                }
//                last = v[r];
//                v.erase(v.begin()+r);
//            }
//            if (serial == 0) {
//                break;
//            }
//            ++n;
//        }
//        lwinfo("aaaaa:%d", n);
//    }
   
    
    const float MOVE_DURATION = .1f;
}

Slider::Slider() {
    sprite = nullptr;
    idx = 0;
    touch = nullptr;
}

Scene* SliderScene::createScene() {
    auto scene = Scene::create();
    auto layer = SliderScene::create();
    scene->addChild(layer);
    return scene;
}

bool SliderScene::init() {
    auto t = time(nullptr);
    srand(t);
    if (!Layer::init()) {
        return false;
    }
    this->setTouchEnabled(true);
    
    _texW = _texH = 0;
    _texture = nullptr;
    
    //reset("img/railway.gif", 8);
    reset("img/fiat500.jpg", 8);
    
    //sound
    SimpleAudioEngine::getInstance()->preloadEffect("audio/tik.wav");
    
    //http test
    auto request = new HttpRequest();
    request->setUrl("http://24.media.tumblr.com/9be497a28c1722b65d0ddb28fdec5654/tumblr_muchr73aKt1skebbwo1_500.gif");//设置请求地址
    request->setRequestType(HttpRequest::Type::GET);
    request->setCallback(std::bind(&SliderScene::onHttpGet, this, std::placeholders::_1, std::placeholders::_2));
    HttpClient::getInstance()->send(request);//发送请求
    request->release();
    
    return true;
}

SliderScene::~SliderScene() {
    if (_texture) {
        _texture->release();
    }
}

void SliderScene::loadTexture(const char *filename) {
    if (_currFileName.compare(filename) == 0) {
        return;
    }
    
    if (_texture) {
        _texture->release();
        _texture = nullptr;
    }
    
    //gif or other
    auto gifptr = strstr(filename, ".gif");
    if (gifptr) {
        //copy gif to writeable dir and read from that
        auto fu = FileUtils::getInstance();
        std::string wpath = filename;
        if (!fu->isAbsolutePath(filename)) {
            wpath = fu->getWritablePath();
            wpath += "tmp/";
            wpath += filename;
            
            if (!fu->isFileExist(wpath)) {
                unsigned long sz;
                auto fdata = fu->getFileData(filename, "rb", &sz);
                auto full = fu->fullPathForFilename(filename);
                if (!fdata) {
                    //fixme
                    CCASSERT(fdata, "file error");
                }
                
                //find dir
                std::string dir = "";
                size_t pos = wpath.find_last_of("/");
                if (pos != std::string::npos) {
                    dir = wpath.substr(0, pos+1);
                    mkdir(dir.c_str(), S_IRWXU);
                }
                
                auto f = fopen(wpath.c_str(), "wb");
                fwrite(fdata, sz, 1, f);
                fclose(f);
                
                delete [] fdata;
            }
        }
        
        //
        auto gifTex = GifTexture::create(wpath.c_str(), this, false);
        if (!gifTex) {
            _texture = TextureCache::getInstance()->addImage("default.png");
            _texture->retain();
            _texW -= 1;//-1 edge problem
            _texH -= 1;//-1 edge problem
            return;
        }
        _texture = gifTex;
        gifTex->getScreenSize(_texW, _texH);
    } else { //not gif
        _texture = TextureCache::getInstance()->addImage(filename);
        _texW = _texture->getPixelsWide();
        _texH = _texture->getPixelsHigh();
    }
    _currFileName = filename;
    _texture->retain();
    _texW -= 1;//-1 edge problem
    _texH -= 1;//-1 edge problem
}

void SliderScene::reset(const char *filename, int sliderNum) {
    for (auto it = _sliders.begin(); it != _sliders.end(); ++it) {
        it->sprite->removeFromParent();
    }
    _sliders.clear();
    
    _sliderNum = sliderNum;
    
    loadTexture(filename);
    
    //create sliders
    float fTexW = _texW;
    float fTexH = _texH;
    auto visSize = Director::getInstance()->getVisibleSize();
    Rect dstRect(0, 0, visSize.width, visSize.height);
    auto dstSize = dstRect.size;
    
    //scale
    float scaleW = dstRect.size.width / _texW;
    float scaleH = dstRect.size.height/ _texH;
    if (_texW > _texH) {
        scaleW = dstRect.size.width / _texH;
        scaleH = dstRect.size.height/ _texW;
    }
    float scale = MAX(scaleW, scaleH);
    
    //shuffle idx
    std::vector<int> idxVec;
    shuffle(idxVec, sliderNum);
    
    //slider
    float uvW = 0;
    float uvH = 0;
    float uvX = 0;
    float uvY = 0;
    if (fTexW <= fTexH) {
        if (fTexW/fTexH <= dstSize.width/dstSize.height) { //slim
            uvW = fTexW;
            uvH = uvW * (dstSize.height/dstSize.width);
            uvY = (fTexH - uvH) * .5f;
        } else {    //fat
            uvH = fTexH;
            uvW = uvH * (dstSize.width/dstSize.height);
            uvX = (fTexW - uvW) * .5f;
        }
        float uvy = uvY;
        float uvh = uvH / sliderNum;
        _sliderH = dstRect.size.height / sliderNum;
        _sliderX0 = dstRect.origin.x + dstRect.size.width * .5f;
        _sliderY0 = dstRect.origin.y + dstRect.size.height - _sliderH * .5f;
        
        for (auto i = 0; i < sliderNum; ++i) {
            uvy = uvY+uvh*idxVec[i];
            auto spt = Sprite::createWithTexture(_texture, Rect(uvX, uvy, uvW, uvh));
            
            float y = _sliderY0 - i * _sliderH;
            spt->setPosition(Point(_sliderX0, y));
            
            spt->setScale(scale);
            this->addChild(spt);
            Slider slider;
            slider.sprite = spt;
            slider.idx = idxVec[i];
            _sliders.push_back(slider);
        }
    } else {
        if (fTexW/fTexH <= dstSize.height/dstSize.width) { //slim
            uvW = fTexW;
            uvH = uvW * (dstSize.width/dstSize.height);
            uvY = (fTexH - uvH) * .5f;
        } else { //fat
            uvH = fTexH;
            uvW = uvH * (dstSize.height/dstSize.width);
            uvX = (fTexW - uvW) * .5f;
        }
        float uvx = uvX;
        float uvw = uvW / sliderNum;
        _sliderH = dstRect.size.height / sliderNum;
        _sliderX0 = dstRect.origin.x + dstRect.size.width * .5f;
        _sliderY0 = dstRect.origin.y + dstRect.size.height - _sliderH * .5f;
        for (auto i = 0; i < sliderNum; ++i) {
            uvx = uvX+uvw*idxVec[i];
            auto spt = Sprite::createWithTexture(_texture, Rect(uvx, uvY, uvw, uvH));
            
            float y = _sliderY0 - i * _sliderH;
            spt->setPosition(Point(_sliderX0, y));
            spt->setRotation(90.f);
            
            spt->setScale(scale);
            this->addChild(spt);
            
            Slider slider;
            slider.sprite = spt;
            slider.idx = idxVec[i];
            _sliders.push_back(slider);
        }
    }
}

void SliderScene::onHttpGet(HttpClient* client, HttpResponse* response) {
    auto fu = FileUtils::getInstance();
    auto wpath = fu->getWritablePath();
    wpath += "imgPack/";
    mkdir(wpath.c_str(), S_IRWXU);
    wpath += "test.gif";
    
    auto f = fopen(wpath.c_str(), "wb");
    auto data = response->getResponseData();
    fwrite(data->data(), data->size(), 1, f);
    fclose(f);
    
    reset(wpath.c_str(), 10);
}

void SliderScene::onTouchesBegan(const std::vector<Touch*>& touches, Event *event) {
    auto touch = touches[0];
    for (auto it = _sliders.begin(); it != _sliders.end(); ++it) {
        if (!it->touch && it->sprite->getBoundingBox().containsPoint(touch->getLocation())) {
            it->touch = touch;
            it->sprite->setZOrder(100);
            it->sprite->stopAllActions();
            break;
        }
    }
    
    if (touch->getLocation().y < 60) {
        if (touch->getLocation().x < 60) {
            reset("img/railway.gif", 8);
        } else if (touch->getLocation().x > Director::getInstance()->getVisibleSize().width-60){
            reset("img/test2.gif", 10);
        }
    }
}

void SliderScene::onTouchesMoved(const std::vector<Touch*>& touches, Event *event) {
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
        SimpleAudioEngine::getInstance()->playEffect("audio/tik.wav");
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

void SliderScene::onTouchesEnded(const std::vector<Touch*>& touches, Event *event) {
    auto touch = touches[0];
    int i = 0;
    for (auto it = _sliders.begin(); it != _sliders.end(); ++it, ++i) {
        if (it->touch && it->touch == touch) {
            it->touch = nullptr;
            it->sprite->setZOrder(0);
            
            float y = _sliderY0 - i * _sliderH;
            auto moveTo = MoveTo::create(MOVE_DURATION, Point(_sliderX0, y));
            auto easeOut = EaseSineOut::create(moveTo);
            it->sprite->stopAllActions();
            it->sprite->runAction(easeOut);
            break;
        }
    }
}

void SliderScene::onTouchesCancelled(const std::vector<Touch*>&touches, Event *event) {
    onTouchesEnded(touches, event);
}