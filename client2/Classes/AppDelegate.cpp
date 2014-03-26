#include "AppDelegate.h"
#include "HelloWorldScene.h"
#include "loginScene.h"
#include "util.h"
#include "db.h"
#include "lang.h"

USING_NS_CC;

AppDelegate::AppDelegate() {

}

AppDelegate::~AppDelegate() 
{
}

void chooseResolution(GLView *glView) {
    Size visibleSize = Director::getInstance()->getVisibleSize();
    float aspectRatio = visibleSize.width / visibleSize.height;
    
    Size resVec[] = {
        //Size(480, 800),
        Size(640, 960),
        Size(640, 1136),
        //Size(768, 1024),
        //Size(1136, 640), //for mac ccbi player
    };
    
    const int nRes = sizeof(resVec)/sizeof(resVec[0]);
    float minDiff = 100.f;
    int bestFitIdx = 0;
    for (int i = 0; i < nRes; ++i) {
        float r = resVec[i].width / resVec[i].height;
        float diff = fabs(r - aspectRatio);
        if (diff < minDiff) {
            minDiff = diff;
            bestFitIdx = i;
        }
    }
    
    Size bestFit = resVec[bestFitIdx];
    glView->setDesignResolutionSize(bestFit.width, bestFit.height, ResolutionPolicy::SHOW_ALL);
    Director::getInstance()->setContentScaleFactor(1.f);
    
    lwinfo("designRes: width=%f, height=%f", bestFit.width, bestFit.height);
    lwinfo("visRes: width=%f, height=%f", visibleSize.width, visibleSize.height);
    lwinfo("scaleFactor:%f", Director::getInstance()->getContentScaleFactor());
    
    //set resolution search dir
    std::vector<std::string> resDirOrders;
    char buf[32];
    sprintf(buf, "%dX%d", int(bestFit.width), int(bestFit.height));
    resDirOrders.push_back(buf);
    
    // default resolution
    if (bestFit.width != 1136.f) {
        resDirOrders.push_back("640X1136");
    }
    FileUtils::getInstance()->setSearchResolutionsOrder(resDirOrders);
}

bool AppDelegate::applicationDidFinishLaunching() {
    // initialize director
    auto director = Director::getInstance();
    auto glview = director->getOpenGLView();
    if(!glview) {
        glview = GLView::create("My Game");
        director->setOpenGLView(glview);
    }

    // turn on display FPS
    director->setDisplayStats(false);

    // set FPS. the default value is 1.0/60 if you don't call this
    director->setAnimationInterval(1.0 / 60);
    
    //init
    makeLocalDir();
    dbInit();
    setLang("lang/zh-s.lang");
    chooseResolution(glview);

    // run
    auto layer = LoginLayer::createWithScene();
    director->runWithScene((Scene*)(layer->getParent()));

    return true;
}

// This function will be called when the app is inactive. When comes a phone call,it's be invoked too
void AppDelegate::applicationDidEnterBackground() {
    Director::getInstance()->stopAnimation();

    // if you use SimpleAudioEngine, it must be pause
    // SimpleAudioEngine::sharedEngine()->pauseBackgroundMusic();
}

// this function will be called when the app is active again
void AppDelegate::applicationWillEnterForeground() {
    Director::getInstance()->startAnimation();

    // if you use SimpleAudioEngine, it must resume here
    // SimpleAudioEngine::sharedEngine()->resumeBackgroundMusic();
}
