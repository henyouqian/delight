#ifndef __DB_H__
#define __DB_H__

#include "cocos2d.h"
#include "cocos-ext.h"
#include "sqlite/sqlite3.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

extern sqlite3 *gSaveDb;

void dbInit();

template<typename T1, typename T2>
bool setKv(T1 key, T2 value) {
    std::stringstream sql;
    sql << "REPLACE INTO kvs(key, value) VALUES(";
    sql << "'" << key << "',";
    sql << "'" << value << "');";
    char *err;
    auto r = sqlite3_exec(gSaveDb, sql.str().c_str(), NULL, NULL, &err);
    if(r != SQLITE_OK) {
        lwerror("sqlite error: %s\nsql=%s", err, sql.str().c_str());
        return false;
    }
    return true;
}

template<typename T>
bool getKv(T key, std::string &value) {
    sqlite3_stmt* pStmt = NULL;
    std::stringstream sql;
    sql << "SELECT value FROM kvs WHERE key='" << key << "';";
    auto r = sqlite3_prepare_v2(gSaveDb, sql.str().c_str(), -1, &pStmt, NULL);
    if (r != SQLITE_OK) {
        lwerror("sqlite error: %s", sql.str().c_str());
        sqlite3_finalize(pStmt);
        return false;
    }
    if (sqlite3_step(pStmt) == SQLITE_ROW ){
        value = (const char*)sqlite3_column_text(pStmt, 0);
    } else {
        sqlite3_finalize(pStmt);
        return false;
    }
    sqlite3_finalize(pStmt);
    return true;
}

class CollectionStars {
public:
    static CollectionStars* getInstance();
    void load(uint64_t collectionId);
    int getStarNum(uint64_t packId);
    void setStarNum(uint64_t packId, int starNum);
    
private:
    uint64_t _collectionId;
    std::map<int, int> _starMap; //<packId, stars>
};

#endif // __DB_H__





