#ifndef __UTIL_H__
#define __UTIL_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

void makeLocalDir();
void makeLocalPackPath(std::string &outPath, int packIdx);
void makeLocalImagePath(std::string &outPath, const char *url);
void makeLocalGifPath(std::string &outPath, const char *fullPath);

ControlButton *createButton(const char *text, float fontSize, float bgScale);
ControlButton *createRingButton(const char *text, float fontSize, float bgScale, const Color3B &color);

#endif // __UTIL_H__
