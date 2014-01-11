#ifndef __SPRITE_LOADER_H__
#define __SPRITE_LOADER_H__

#include "cocos2d.h"
#include "cocos-ext.h"
#include "giflib/gif_lib.h"
#include <thread>
#include <mutex>
#include <condition_variable>

USING_NS_CC;
USING_NS_CC_EXT;

class SptLoaderListener {
public:
    virtual void onSptLoaderLoad(const char *localPath, Sprite* sprite, void *userData) {};
    virtual void onSptLoaderError(const char *localPath, void *userData) {};
};

class SptLoader {
public:
    static SptLoader* create(SptLoaderListener *listener, Node *gifActionParentNode);
    
    SptLoader(SptLoaderListener *listener, Node *gifActionParentNode);
    void destroy();
    
    void load(const char *filename, void *userData = nullptr);
    void download(const char *url, void *userData = nullptr);
    void mainThreadUpdate();
    
    void onTextureCreated(const char *localPath, Texture2D *texture, void *userData);

private:
    ~SptLoader();
    void loadingThread();
    void onImageDownload(HttpClient* client, HttpResponse* response, std::string localPath);

    std::thread *_thread;
    std::mutex _mutex;
    std::condition_variable _cv;
    SptLoaderListener *_listener;
    //std::list<std::string> _localPaths;
    struct LoadingGif {
        std::string local;
        void *userData;
    };
    std::list<LoadingGif> _loadingGifs;
    std::set<HttpRequest*> _requests;
    Node *_gifActionParentNode;
    
    struct LoadedGif {
        std::string localPath;
        GifFileType *gifFile;
        void *userData;
    };
    struct LoadedTexture {
        std::string localPath;
        Texture2D *texture;
        void *userData;
    };
    std::list<LoadedGif> _loadedGifs;
    std::list<LoadedTexture> _loadedTextures;
    std::list<std::string> _errorLocalPaths;
    bool _done;
};


#endif // __SPRITE_LOADER_H__
