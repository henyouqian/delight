#include "db.h"

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

