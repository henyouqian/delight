#include "HelloWorldScene.h"
#include "giflib/gif_lib.h"
#include "gifSprite.h"

USING_NS_CC;

Scene* HelloWorld::createScene()
{
    // 'scene' is an autorelease object
    auto scene = Scene::create();
    
    // 'layer' is an autorelease object
    auto layer = HelloWorld::create();

    // add layer as a child to scene
    scene->addChild(layer);

    // return the scene
    return scene;
}

class gifCloser {
public:
    gifCloser(GifFileType *gifinfo) { _gifinfo = gifinfo;}
    ~gifCloser() {
        DGifCloseFile(_gifinfo);
    }
    
private:
    GifFileType *_gifinfo;
};

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


bool readGif(Node* node) {
    auto path = FileUtils::getInstance()->fullPathForFilename("test.gif");
    int err = GIF_OK;
    GifFileType *gifFile = DGifOpenFileName(path.c_str(), &err);
    gifCloser _closer(gifFile);
    err = DGifSlurp(gifFile);
    
    int pwr2Width = pwr2Size(gifFile->SWidth);
    int pwr2Height = pwr2Size(gifFile->SHeight);
    
    size_t len = pwr2Width*pwr2Height*4;
    char *buf = new char[len];
    memset(buf, 0, len);
    
    auto *img = gifFile->SavedImages + 10;
    auto imgDesc = img->ImageDesc;
    auto colorMap = imgDesc.ColorMap;
    auto imgBuf = img->RasterBits;
    if (!colorMap) {
        colorMap = gifFile->SColorMap;
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
    
    auto spt = Sprite::createWithTexture(texture);
    spt->setPosition(Point(300, 300));
    node->addChild(spt);
    
    spt->getTexture()->getName();
    
    delete [] buf;
    return true;
}

// on "init" you need to initialize your instance
bool HelloWorld::init()
{
    //////////////////////////////
    // 1. super init first
    if ( !Layer::init() )
    {
        return false;
    }
    
    Size visibleSize = Director::getInstance()->getVisibleSize();
    Point origin = Director::getInstance()->getVisibleOrigin();

    /////////////////////////////
    // 2. add a menu item with "X" image, which is clicked to quit the program
    //    you may modify it.

    // add a "close" icon to exit the progress. it's an autorelease object
    auto closeItem = MenuItemImage::create(
                                           "CloseNormal.png",
                                           "CloseSelected.png",
                                           CC_CALLBACK_1(HelloWorld::menuCloseCallback, this));
    
	closeItem->setPosition(Point(origin.x + visibleSize.width - closeItem->getContentSize().width/2 ,
                                origin.y + closeItem->getContentSize().height/2));

    // create menu, it's an autorelease object
    auto menu = Menu::create(closeItem, NULL);
    menu->setPosition(Point::ZERO);
    this->addChild(menu, 1);

    /////////////////////////////
    // 3. add your codes below...

    // add a label shows "Hello World"
    // create and initialize a label
    
    auto label = LabelTTF::create("Hello World", "Arial", 24);
    
    // position the label on the center of the screen
    label->setPosition(Point(origin.x + visibleSize.width/2,
                            origin.y + visibleSize.height - label->getContentSize().height));

    // add the label as a child to this layer
    this->addChild(label, 1);
    
    //readGif(this);
    
    
    auto gifSpt = GifSprite::create("test.gif");
    this->addChild(gifSpt);
    gifSpt->setAnchorPoint(Point(0, 0));
    gifSpt->setPosition(Point(0, 0));
    return true;
}


void HelloWorld::menuCloseCallback(Object* pSender)
{
    Director::getInstance()->end();

#if (CC_TARGET_PLATFORM == CC_PLATFORM_IOS)
    exit(0);
#endif
}
