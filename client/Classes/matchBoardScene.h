#ifndef __MATCHBOARD_SCENE_H__
#define __MATCHBOARD_SCENE_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

class MatchBoardLayer : public cocos2d::Layer
,public CCBMemberVariableAssigner
,public CCBSelectorResolver
,public NodeLoaderListener {
public:
    static Scene* createScene();
    CREATE_FUNC(MatchBoardLayer);
    ~MatchBoardLayer();
    virtual bool init();
    
    virtual bool onAssignCCBMemberVariable(Object* pTarget, const char* pMemberVariableName, Node* pNode);
    virtual void onNodeLoaded(Node * pNode, NodeLoader * pNodeLoader);
    virtual SEL_MenuHandler onResolveCCBCCMenuItemSelector(Object * pTarget, const char* pSelectorName);
    virtual extension::Control::Handler onResolveCCBCCControlSelector(Object * pTarget, const char* pSelectorName);

    void onButtonPress(Object *sender, Control::EventType et);

    virtual void onTouchesBegan(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesMoved(const std::vector<Touch*>& touches, Event *event);
    virtual void onTouchesEnded(const std::vector<Touch*>& touches, Event *event);
    
    
private:
    EditBox *_editSearch;
    Node *_label;
};

#endif // __MATCHBOARD_SCENE_H__
