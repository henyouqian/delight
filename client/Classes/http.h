#ifndef __HTTP_H__
#define __HTTP_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

HttpRequest* postHttpRequest(const char *path, const char *content, const std::function<void(HttpClient*, HttpResponse*)> &callback);
HttpRequest* postHttpRequest(const char *path, const char *content, cocos2d::Object *pTarget, SEL_HttpResponse pSelector);

void getHttpRequest(const char *url, const std::function<void(HttpClient*, HttpResponse*)> &callback);
void getHttpResponseString(HttpResponse *resp, std::string &str);

#endif // __HTTP_H__
