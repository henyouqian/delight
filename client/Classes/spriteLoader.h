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
    virtual void onSptLoaderLoad(const char *localPath, Sprite* sprite) {};
    virtual void onSptLoaderError(const char *localPath) {};
};

class SptLoader {
public:
    static SptLoader* create(SptLoaderListener *listener, Node *gifActionParentNode);
    
    SptLoader(SptLoaderListener *listener, Node *gifActionParentNode);
    void destroy();
    
    void load(const char *filename);
    void download(const char *url);
    void mainThreadUpdate();
    
    void onTextureCreated(const char *localPath, Texture2D *texture);

private:
    ~SptLoader();
    void loadingThread();
    void onImageDownload(HttpClient* client, HttpResponse* response, std::string localPath);

    std::thread *_thread;
    std::mutex _mutex;
    std::condition_variable _cv;
    SptLoaderListener *_listener;
    std::list<std::string> _localPaths;
    std::set<HttpRequest*> _requests;
    Node *_gifActionParentNode;
    
    struct LoadedGif {
        std::string localPath;
        GifFileType *gifFile;
    };
    struct LoadedTexture {
        std::string localPath;
        Texture2D *texture;
    };
    std::list<LoadedGif> _loadedGifs;
    std::list<LoadedTexture> _loadedTextures;
    std::list<std::string> _errorLocalPaths;
    bool _done;
};


#endif // __SPRITE_LOADER_H__
