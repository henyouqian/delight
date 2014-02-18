#include "collectionListScene.h"
#include "dragView.h"
#include "lang.h"

USING_NS_CC;
USING_NS_CC_EXT;

static const float HEADER_HEIGHT = 130.f;

Scene* CollectionListScene::createScene() {
    auto scene = Scene::create();
    auto layer = CollectionListScene::create();
    scene->addChild(layer);
    return scene;
}

bool CollectionListScene::init() {
    if ( !Layer::init() ) {
        return false;
    }
    
    auto visSize = Director::getInstance()->getVisibleSize();
    
    //header
    auto headerBg = Sprite::create("ui/pt.png");
    headerBg->setScaleX(visSize.width);
    headerBg->setScaleY(HEADER_HEIGHT);
    headerBg->setAnchorPoint(Point(0.f, 1.f));
    headerBg->setPosition(Point(0.f, visSize.height));
    headerBg->setColor(Color3B(27, 27, 27));
    addChild(headerBg, 10);
    
    auto headerLine = Sprite::create("ui/pt.png");
    headerLine->setScaleX(visSize.width);
    headerLine->setScaleY(2);
    headerLine->setAnchorPoint(Point(0.f, 0.f));
    headerLine->setPosition(Point(0.f, visSize.height-HEADER_HEIGHT));
    headerLine->setColor(Color3B(10, 10, 10));
    addChild(headerLine, 10);
    
    //label
    float y = visSize.height-70;
    auto title = LabelTTF::create(lang("Collections"), "HelveticaNeue", 44);
    title->setAnchorPoint(Point(.5f, .5f));
    title->setPosition(Point(visSize.width*.5f, y));
    title->setColor(Color3B(240, 240, 240));
    addChild(title, 10);
    
    //drag view
    _dragView = DragView::create();
    addChild(_dragView);
    float dragViewHeight = visSize.height - HEADER_HEIGHT;
    _dragView->setWindowRect(Rect(0, 0, visSize.width, dragViewHeight));
    _dragView->setContentHeight(1800.f);
    
    //list collection
    
    
    return true;
}

void CollectionListScene::onHttpListCollection(HttpClient* client, HttpResponse* response) {
    
}

