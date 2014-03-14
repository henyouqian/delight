#include "matchBoardScene.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT; 

namespace {
    class CCBLoader:public cocos2d::extension::LayerLoader{
    public:
        CCB_STATIC_NEW_AUTORELEASE_OBJECT_METHOD(CCBLoader, loader);
    protected:
        CCB_VIRTUAL_NEW_AUTORELEASE_CREATECCNODE_METHOD(MatchBoardLayer);
    };
}

Scene* MatchBoardLayer::createScene() {
    lwinfo("MatchBoardLayer::createScene()");
    auto scene = Scene::create();
    
    auto *lib = NodeLoaderLibrary::newDefaultNodeLoaderLibrary();
    lib->registerNodeLoader("MatchBoardLayer", CCBLoader::loader());
    auto *ccbReader = new CCBReader(lib);
    auto *ccbNode = ccbReader->readNodeGraphFromFile("ccb/matchBoardLayer.ccbi", scene);
    ccbReader->release();
    
    scene->addChild(ccbNode);
    return scene;
}

MatchBoardLayer::~MatchBoardLayer() {
    SpriteFrameCache::getInstance()->removeUnusedSpriteFrames();
}

bool MatchBoardLayer::init() {
    if (!Layer::init()) {
        return false;
    }
    //this->setTouchEnabled(true);
    
    return true;
}

bool MatchBoardLayer::onAssignCCBMemberVariable(Object *pTarget, const char *pMemberVariableName, Node *pNode){
    //CCB_MEMBERVARIABLEASSIGNER_GLUE(this, "_editSearch", EditBox*, _editSearch);
    CCB_MEMBERVARIABLEASSIGNER_GLUE(this, "_label", Node*, _label);
    return true;
}

void MatchBoardLayer::onNodeLoaded(Node *pNode, NodeLoader *pNodeLoader){
    //helloLabel->setString("ccb loaded");
//    aaa->removeFromParent();
//    aaa->release();
}

SEL_MenuHandler MatchBoardLayer::onResolveCCBCCMenuItemSelector(Object * pTarget, const char* pSelectorName)
{
    //CCB_SELECTORRESOLVER_CCMENUITEM_GLUE(this, "onButtonPress", MatchBoardLayer::onButtonPress);
    return NULL;
}

Control::Handler MatchBoardLayer::onResolveCCBCCControlSelector(Object * pTarget, const char* pSelectorName){
    CCB_SELECTORRESOLVER_CCCONTROL_GLUE(this, "onButtonPress", MatchBoardLayer::onButtonPress);
    return NULL;
}

void MatchBoardLayer::onButtonPress(Object *sender, Control::EventType et){
    lwinfo("onButtonPress");
}

void MatchBoardLayer::onTouchesBegan(const std::vector<cocos2d::Touch*>& touches, cocos2d::Event *event) {
    //Touch* touch = touches.front();
}

void MatchBoardLayer::onTouchesMoved(const std::vector<Touch*>& touches, Event *event) {
    
}

void MatchBoardLayer::onTouchesEnded(const std::vector<Touch*>& touches, Event *event) {
    
}

