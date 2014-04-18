#ifndef __HTTP_H__
#define __HTTP_H__

#include "cocos2d.h"
#include "cocos-ext.h"
#include "network/HttpClient.h"

USING_NS_CC;
USING_NS_CC_EXT;
using namespace cocos2d::network;

HttpRequest* postHttpRequest(const char *path, const char *content, Ref *pTarget, SEL_HttpResponse pSelector);

//void getHttpRequest(const char *url, const std::function<void(HttpClient*, HttpResponse*)> &callback);
void getHttpResponseString(HttpResponse *resp, std::string &str);
bool checkHttpResp(HttpResponse *resp, std::string &str);
void setHttpUserToken(const char* token);

#endif // __HTTP_H__