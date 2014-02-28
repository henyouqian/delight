#include "lang.h"
#include "jsonxx/jsonxx.h"
#include "lw/lwLog.h"

USING_NS_CC;
USING_NS_CC_EXT;

#ifdef __APPLE__
const float FORWARD_BACK_FONT_SIZE = 56;
const float FORWARD_BACK_FONT_OFFSET = 14;
#else
const float FORWARD_BACK_FONT_SIZE = 36;
const float FORWARD_BACK_FONT_OFFSET = 7;
#endif

static std::map<std::string, std::string> g_dict;

void setLang(const char *langFile) {
    g_dict.empty();
    
    auto fu = FileUtils::getInstance();
    unsigned long size;
    char* data = (char*)(fu->getFileData(langFile, "rb", &size));
    jsonxx::Object dictJs;
    if (!dictJs.parse(data)) {
        lwerror("lang file parse error: %s", langFile);
    } else {
        auto map = dictJs.kv_map();
        for (auto it = map.begin(); it != map.end(); it++) {
            if (it->second->is<jsonxx::String>()) {
                g_dict[it->first] = it->second->get<jsonxx::String>();
            }
        }
    }
}

const char* lang(const char *text) {
    auto it = g_dict.find(text);
    if (it == g_dict.end()) {
        return text;
    }
    return it->second.c_str();
}