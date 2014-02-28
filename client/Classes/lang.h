#ifndef __LANG_H__
#define __LANG_H__

#include "cocos2d.h"
#include "cocos-ext.h"

USING_NS_CC;
USING_NS_CC_EXT;

void setLang(const char *langFile);
const char* lang(const char *text);

extern const float FORWARD_BACK_FONT_SIZE;
extern const float FORWARD_BACK_FONT_OFFSET;

#endif // __LANG_H__
