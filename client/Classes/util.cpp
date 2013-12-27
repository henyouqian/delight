#include "util.h"
#include "crypto/sha.h"
#include <sys/stat.h>

USING_NS_CC;
USING_NS_CC_EXT;

namespace {
    std::string _imageDir;
    std::string _packDir;
    std::string _localGifDir;
}

void makeLocalDir() {
    _imageDir = FileUtils::getInstance()->getWritablePath();
    _imageDir += "images/";
    mkdir(_imageDir.c_str(), S_IRWXU);
    
    _packDir = FileUtils::getInstance()->getWritablePath();
    _packDir += "packs/";
    mkdir(_packDir.c_str(), S_IRWXU);
    
    _localGifDir = FileUtils::getInstance()->getWritablePath();
    _localGifDir += "localGif/";
    mkdir(_localGifDir.c_str(), S_IRWXU);
}

void makeLocalPackPath(std::string &outPath, int packIdx) {
    outPath = _packDir;
    char buf[64];
    snprintf(buf, 64, "%d.pack", packIdx);
    outPath += buf;
}

void makeLocalImagePath(std::string &outPath, const char *url) {
    Sha1 sha1;
    sha1.write(url, strlen(url));
    sha1.final();
    
    outPath = _imageDir;
    outPath += sha1.getResult();
}

void makeLocalGifPath(std::string &outPath, const char *fullPath) {
    Sha1 sha1;
    sha1.write(fullPath, strlen(fullPath));
    sha1.final();
    
    outPath = _localGifDir;
    outPath += sha1.getResult();
}