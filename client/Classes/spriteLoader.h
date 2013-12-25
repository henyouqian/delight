#ifndef __SPRITE_LOADER_H__
#define __SPRITE_LOADER_H__

#include "cocos2d.h"
#include "cocos-ext.h"
#include <thread>
#include <mutex>
#include <condition_variable>

USING_NS_CC;
USING_NS_CC_EXT;

class SptLoaderListener {
    
};

class SptLoader {
public:
    static SptLoader* getInstance();
    static void DestroyInstance();
    SptLoader();
    ~SptLoader();
    
    void setListener(SptLoaderListener *listener);
    void load(const char* filename);
    
private:
    void run();
    std::thread *_thread;
    std::mutex _mutex;
    std::condition_variable _cv;
    SptLoaderListener *_listener;
    std::list<std::string> _filenames;
};


#endif // __SPRITE_LOADER_H__
