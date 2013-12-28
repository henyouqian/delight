#ifndef __DB_H__
#define __DB_H__

#include "cocos2d.h"
#include "cocos-ext.h"
#include "sqlite/sqlite3.h"

USING_NS_CC;
USING_NS_CC_EXT;

extern sqlite3 *gSaveDb;

void dbInit();


#endif // __DB_H__
