#include "http.h"

USING_NS_CC;
USING_NS_CC_EXT;

namespace {
    //const char *g_host = "http://192.168.1.43:9999/";
    //const char *g_host = "http://42.121.107.155:9999/";
    const char *g_host = "http://192.168.2.55:9999/";
    //const char *g_host = "http://localhost:9999/";
}

static std::string g_cookie;

HttpRequest* postHttpRequest(const char *path, const char *content, cocos2d::Ref *pTarget, SEL_HttpResponse pSelector) {
    std::string url = g_host;
    url += path;
    
    auto request = new HttpRequest();
    request->setUrl(url.c_str());
    request->setRequestType(HttpRequest::Type::POST);
    request->setRequestData(content, strlen(content));
    request->setResponseCallback(pTarget, pSelector);
    
    std::vector<std::string> headers;
    headers.push_back(g_cookie);
    request->setHeaders(headers);
    
    HttpClient::getInstance()->send(request);
    request->release();
    return request;
}

//void getHttpRequest(const char *url, const std::function<void(HttpClient*, HttpResponse*)> &callback) {
//    auto request = new HttpRequest();
//    request->setUrl(url);
//    request->setRequestType(HttpRequest::Type::GET);
//    request->setCallback(callback);
//    HttpClient::getInstance()->send(request);
//    request->release();
//}

void getHttpResponseString(HttpResponse *resp, std::string &str) {
    str.clear();
    auto vData = resp->getResponseData();
    std::istringstream is(std::string(vData->begin(), vData->end()));
    str = is.str();
}

bool checkHttpResp(HttpResponse *resp, std::string &str) {
    auto vData = resp->getResponseData();
    std::istringstream is(std::string(vData->begin(), vData->end()));
    str = is.str();
    return resp->isSucceed();
}

void setHttpUserToken(const char* token) {
    g_cookie = "Cookie: usertoken=";
    g_cookie.append(token);
}
