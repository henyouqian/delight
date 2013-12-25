#include "spriteLoader.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

namespace {
    SptLoader *_sptLoader = nullptr;
}

SptLoader* SptLoader::getInstance() {
    if (_sptLoader) {
        return _sptLoader;
    }
    _sptLoader = new SptLoader;
    _sptLoader->_thread = new std::thread(&SptLoader::run, _sptLoader);
    return _sptLoader;
}

void SptLoader::DestroyInstance() {
    if (_sptLoader) {
        delete _sptLoader;
        _sptLoader = nullptr;
    }
    
}

SptLoader::SptLoader() {
    
}

SptLoader::~SptLoader() {
    if (_thread) {
        delete _thread;
    }
}

void SptLoader::run() {
    while(1) {
        std::unique_lock<std::mutex> lock(_mutex);
        if (!_filenames.empty()) {
            lwinfo("%s", _filenames.begin()->c_str());
            _filenames.pop_front();
        } else {
            _cv.wait(lock);
        }
    }
}

void SptLoader::setListener(SptLoaderListener *listener) {
    _listener = listener;
}

void SptLoader::load(const char* filename) {
    std::lock_guard<std::mutex> lock(_mutex);
    _filenames.push_back(filename);
    _cv.notify_all();
}



