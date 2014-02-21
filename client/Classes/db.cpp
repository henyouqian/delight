#include "db.h"
#include "jsonxx/jsonxx.h"

USING_NS_CC;
USING_NS_CC_EXT;

sqlite3 *gSaveDb = nullptr;

class DbCloser {
public:
    ~DbCloser() {
        if (gSaveDb) {
            sqlite3_close(gSaveDb);
        }
    }
};

DbCloser _dbCloser;

void dbInit() {
    auto fu = FileUtils::getInstance();
    auto saveDbPath = fu->getWritablePath();
    saveDbPath += "save.db";
    
    if (!fu->isFileExist(saveDbPath)) {
        unsigned long size;
        auto data = fu->getFileData("db/save.db", "rb", &size);
        auto f = fopen(saveDbPath.c_str(), "wb");
        fwrite(data, size, 1, f);
        fclose(f);
        delete [] data;
    }
    
    auto ok = sqlite3_open(saveDbPath.c_str(), &gSaveDb);
    CCASSERT(ok==SQLITE_OK, "sqlite3_open failed");
}


CollectionStars* CollectionStars::getInstance() {
    static CollectionStars *p = nullptr;
    if (!p) {
        p = new CollectionStars;
    }
    return p;
}

void CollectionStars::load(uint64_t collectionId) {
    std::string value;
    std::stringstream ss;
    ss << "stars/" << collectionId;
    getKv(ss.str().c_str(), value);
    jsonxx::Object obj;
    obj.parse(value);
    auto map = obj.kv_map();
    for (auto it = map.begin(); it != map.end(); ++it) {
        auto packId = atoi(it->first.c_str());
        _starMap[packId] = it->second->get<jsonxx::Number>();
    }
    _collectionId = collectionId;
}

int CollectionStars::getStarNum(uint64_t packId) {
    int starNum = 0;
    auto it = _starMap.find(packId);
    if (it != _starMap.end()) {
        starNum = it->second;
    }
    return starNum;
}

void CollectionStars::setStarNum(uint64_t packId, int starNum) {
    _starMap[packId] = starNum;
    jsonxx::Object obj;
    for (auto it = _starMap.begin(); it != _starMap.end(); ++it) {
        std::stringstream key;
        key << it->first;
        obj << key.str() << it->second;
    }
    
    std::stringstream key;
    key << "stars/" << _collectionId;
    
    setKv(key.str(), obj.json());
}




