#include "SliderScene.h"
#include "gifTexture.h"
#include "lw/lwLog.h"
#include <sys/stat.h>

USING_NS_CC;

Scene* SliderScene::createScene() {
    auto scene = Scene::create();
    auto layer = SliderScene::create();
    scene->addChild(layer);
    return scene;
}

bool SliderScene::init() {
    if (!Layer::init()) {
        return false;
    }
    this->setTouchEnabled(true);
    
    _texW = _texH = 0;
    _texture = nullptr;
    
    reset("img/je1.jpg", 8);
    
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
        auto wpath = fu->getWritablePath();
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
        
        //
        auto gifTex = GifTexture::create(wpath.c_str(), this, false);
        if (!gifTex) {
            _texture = TextureCache::getInstance()->addImage("default.png");
            return;
        }
        _texture = gifTex;
        gifTex->getScreenSize(_texW, _texH);
    } else { //not gif
        _texture = TextureCache::getInstance()->addImage(filename);
        _texW = _texture->getPixelsWide();
        _texH = _texture->getPixelsHigh();
    }
}

void SliderScene::reset(const char *filename, int nPieces) {
    for (auto it = _sprites.begin(); it != _sprites.end(); ++it) {
        (*it)->removeFromParent();
    }
    _sprites.clear();
    
    loadTexture(filename);
    _texture->retain();
    
    auto spt = Sprite::createWithTexture(_texture, Rect(0, 0, _texW, _texH));
    this->addChild(spt);
    _sprites.push_back(spt);
    
    //
    auto visSize = Director::getInstance()->getVisibleSize();
    Rect dstRect(0, 0, visSize.width, visSize.height);
    float scaleW = dstRect.size.width / _texW;
    float scaleH = dstRect.size.height/ _texH;
    
    spt->setPosition(Point(dstRect.origin.x+dstRect.size.width*.5f, dstRect.origin.y+dstRect.size.height*.5f));
    if (_texW > _texH) {
        spt->setRotation(90);
        scaleW = dstRect.size.width / _texH;
        scaleH = dstRect.size.height/ _texW;
    }
    
    float scale = MAX(scaleW, scaleH);
    spt->setScale(scale);
    
}

void SliderScene::onTouchesBegan(const std::vector<Touch*>& touches, Event *event) {
    reset("img/test2.gif", 8);
}

void SliderScene::onTouchesMoved(const std::vector<Touch*>& touches, Event *event) {
    auto touch = touches[0];
    lwinfo("%f", touch->getLocation().y);
}

void SliderScene::onTouchesEnded(const std::vector<Touch*>& touches, Event *event) {
    
}

void SliderScene::onTouchesCancelled(const std::vector<Touch*>&touches, Event *event) {
    
}