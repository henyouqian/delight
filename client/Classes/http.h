#ifndef __HTTP_H__
#define __HTTP_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

HttpRequest* postHttpRequest(const char *path, const char *content, const std::function<void(HttpClient*, HttpResponse*)> &callback);

void getHttpRequest(const char *url, const std::function<void(HttpClient*, HttpResponse*)> &callback);

#endif // __HTTP_H__
