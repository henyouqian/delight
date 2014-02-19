#include "AppDelegate.h"
#include "sliderScene.h"
#include "mainMenuScene.h"
#include "util.h"
#include "qiniu.h"
#include "db.h"
#include "lang.h"
#include "lw/lwLog.h"
#include <thread>

USING_NS_CC;

namespace {
    void chooseResolution(EGLView *eglView) {
        Size visibleSize = Director::getInstance()->getVisibleSize();
        float aspectRatio = visibleSize.width / visibleSize.height;
        
        Size resVec[] = {
            //Size(480, 800),
            //Size(640, 960),
            Size(640, 1136),
            //Size(768, 1024),
            //Size(1136, 640), //for mac ccbi player
        };
        
        const int nRes = sizeof(resVec)/sizeof(resVec[0]);
        float minDiff = 100.f;
        int minDiffIdx = 0;
        for (int i = 0; i < nRes; ++i) {
            float r = resVec[i].width / resVec[i].height;
            float diff = fabs(r - aspectRatio);
            if (diff < minDiff) {
                minDiff = diff;
                minDiffIdx = i;
            }
        }
        
        Size bestFit = resVec[minDiffIdx];
        eglView->setDesignResolutionSize(bestFit.width, bestFit.height, ResolutionPolicy::SHOW_ALL);
        Director::getInstance()->setContentScaleFactor(1.f);
        
        lwinfo("designRes: width=%f, height=%f", bestFit.width, bestFit.height);
        lwinfo("visRes: width=%f, height=%f", visibleSize.width, visibleSize.height);
        lwinfo("scaleFactor:%f", Director::getInstance()->getContentScaleFactor());
        
        //set search dir
        std::vector<std::string> dirOrders;
        dirOrders.push_back("default");
        ////for ccbi player
        dirOrders.push_back("ccbiPlayer/res");
        FileUtils::getInstance()->setSearchPaths(dirOrders);
        
        //set resolution search dir
        std::vector<std::string> resDirOrders;
        char buf[32];
        sprintf(buf, "%dX%d", int(bestFit.width), int(bestFit.height));
        resDirOrders.push_back(buf);
        resDirOrders.push_back("high");
        ////for ccbi player
        resDirOrders.push_back("iphonehd");
        
        // default resolution
        if (bestFit.width != 1136.f) {
            resDirOrders.push_back("640X1136");
        }
        FileUtils::getInstance()->setSearchResolutionsOrder(resDirOrders);
    }
}

AppDelegate::AppDelegate() {
    //test
    
}

AppDelegate::~AppDelegate() 
{
    qiniuQuit();
}

bool AppDelegate::applicationDidFinishLaunching() {
    // initialize director
    auto director = Director::getInstance();
    auto eglView = EGLView::getInstance();
   
    director->setOpenGLView(eglView);
	
    // turn on display FPS
    director->setDisplayStats(false);

    // set FPS. the default value is 1.0/60 if you don't call this
    director->setAnimationInterval(1.0 / 60);
    
    // choose resolution
    chooseResolution(eglView);
    
    //init
    makeLocalDir();
    dbInit();
    setLang("lang/zh-s.lang");
    qiniuInit();

    //auto scene = SliderScene::createScene();
    auto scene = MainMenuScene::createScene();
    
    // run
    director->runWithScene(scene);

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
    
    std::chrono::milliseconds dura(1000);
    std::this_thread::sleep_for(dura);
}
