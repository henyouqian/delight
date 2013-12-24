#include "spriteLoader.h"
#include "lw/lwLog.h"
#include "crypto/sha.h"

USING_NS_CC;
USING_NS_CC_EXT;

namespace {
    void makeLocalImagePath(std::string &outPath, const char *url) {
        outPath = FileUtils::getInstance()->getWritablePath();
        outPath += "imgs/";
        
        Sha1 sha1;
        sha1.write(url, strlen(url));
        sha1.final();
        
        outPath += sha1.getResult();
    }
}

SptLoader* SptLoader::loadFromUrl(const char *url, Sprite *placeholder) {
    CCASSERT(url, "url must not null");
    auto sptLoader = new SptLoader();
    sptLoader->url = url;
    sptLoader->placeholder = placeholder;
    
    //check local exist
    std::string localPath;
    makeLocalImagePath(localPath, url);
    if (FileUtils::getInstance()->isFileExist(localPath)) {
        
    } else {
        
    }
    
    return sptLoader;
}

SptLoader::SptLoader() {
    placeholder = nullptr;
    sprite = nullptr;
    state = READY;
}

SptLoader::~SptLoader() {
    
}

