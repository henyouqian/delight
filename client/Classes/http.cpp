#include "http.h"

USING_NS_CC;
USING_NS_CC_EXT;

namespace {
    const char *g_host = "http://192.168.1.43:9999/";
    //const char *g_host = "http://192.168.2.101:9999/";
    //const char *g_host = "http://localhost:9999/";
}

HttpRequest* postHttpRequest(const char *path, const char *content,
                     const std::function<void(HttpClient*, HttpResponse*)> &callback) {
    std::string url = g_host;
    url += path;
    
    auto request = new HttpRequest();
    request->setUrl(url.c_str());
    request->setRequestType(HttpRequest::Type::POST);
    request->setRequestData(content, strlen(content));
    request->setCallback(callback);
    HttpClient::getInstance()->send(request);
    request->release();
    return request;
}

void getHttpRequest(const char *url, const std::function<void(HttpClient*, HttpResponse*)> &callback) {
    auto request = new HttpRequest();
    request->setUrl(url);
    request->setRequestType(HttpRequest::Type::GET);
    request->setCallback(callback);
    HttpClient::getInstance()->send(request);
    request->release();
}