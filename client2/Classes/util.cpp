#include "util.h"
#include "lang.h"
#include "crypto/sha.h"
#include <sys/stat.h>

USING_NS_CC;
USING_NS_CC_EXT;

namespace {
    std::string _imageDir;
    std::string _packDir;
    std::string _localGifDir;
    std::string _uploadPack;
}

static const char *g_res = "http://sliderpack.qiniudn.com/";

void makeLocalDir() {
    auto wpath = FileUtils::getInstance()->getWritablePath();
    _imageDir = wpath;
    _imageDir += "images/";
    mkdir(_imageDir.c_str(), S_IRWXU);
    
    _packDir = wpath;
    _packDir += "packs/";
    mkdir(_packDir.c_str(), S_IRWXU);
    
    _localGifDir = wpath;
    _localGifDir += "localGif/";
    mkdir(_localGifDir.c_str(), S_IRWXU);
    
    _uploadPack = wpath;
    _uploadPack += "uploadPack/";
    mkdir(_uploadPack.c_str(), S_IRWXU);
}

const char* getUploadPackDir() {
    return _uploadPack.c_str();
}

void makeLocalPackPath(std::string &outPath, int packIdx) {
    outPath = _packDir;
    char buf[64];
    snprintf(buf, 64, "%d.pack", packIdx);
    outPath += buf;
}

void makeLocalImagePath(std::string &outPath, const char *key) {
    outPath = _imageDir;
    outPath += key;
}

void makeLocalGifPath(std::string &outPath, const char *fullPath) {
    Sha1 sha1;
    sha1.write(fullPath, strlen(fullPath));
    sha1.final();
    
    outPath = _localGifDir;
    outPath += sha1.getResult();
}

void makeUrl(std::string &url, const char *key) {
    url = g_res;
    url += key;
}

ControlButton *createButton(const char *text, float fontSize, float bgScale) {
    auto label = LabelTTF::create(text, "HelveticaNeue", fontSize);
    auto spr = Scale9Sprite::create("ui/btnBg.png");
    spr->setScale(bgScale);
    spr->setOpacity(180);
    auto button = ControlButton::create(label, spr);
    button->setAdjustBackgroundImage(false);
    return button;
}

ControlButton *createRingButton(const char *text, float fontSize, float bgScale, const Color3B &color) {
    auto label = LabelTTF::create(text, "HelveticaNeue", fontSize);
    label->setColor(color);
    auto spr = Scale9Sprite::create("ui/whiteRing96.png");
    spr->setScale(bgScale);
    spr->setColor(color);
    auto button = ControlButton::create(label, spr);
    button->setAdjustBackgroundImage(false);
    return button;
}

ControlButton *createColorButton(const char *text, float fontSize, float bgScale, const Color3B &labelColor, const Color3B &bgColor, GLubyte bgOpacity) {
    auto label = LabelTTF::create(text, "HelveticaNeue", fontSize);
    label->setColor(labelColor);
    auto spr = Scale9Sprite::create("ui/btnBgWhite.png");
    spr->setScale(bgScale);
    spr->setColor(bgColor);
    spr->setOpacity(bgOpacity);
    auto button = ControlButton::create(label, spr);
    button->setAdjustBackgroundImage(false);
    return button;
}

ControlButton *createButton(const char* textFont, const char *text, float textSize, const Color3B &textColor, const char *bgFile, float bgScale, const Color3B &bgColor, GLubyte bgOpacity) {
    auto label = LabelTTF::create(text, textFont, textSize);
    label->setColor(textColor);
    auto spr = Scale9Sprite::create(bgFile);
    spr->setScale(bgScale);
    spr->setColor(bgColor);
    spr->setOpacity(bgOpacity);
    auto button = ControlButton::create(label, spr);
    button->setAdjustBackgroundImage(false);
    return button;
}

ControlButton *createTextButton(const char* textFont, const char *text, float textSize, const Color3B &textColor) {
    auto label = LabelTTF::create(text, textFont, textSize);
    label->setColor(textColor);
    auto spr = Scale9Sprite::create("ui/empty.png");
    auto button = ControlButton::create(label, spr);
    button->setZoomOnTouchDown(false);
    button->setAdjustBackgroundImage(false);
    button->setContentSize(label->getContentSize());
    return button;
}

const char* getTeamName(uint32_t id) {
    char buf[64];
    snprintf(buf, 64, "teamName%d", id);
    return lang(buf);
}

static PlayerInfo g_playerInfo;

PlayerInfo& getPlayerInfo() {
    return g_playerInfo;
}

static int64_t g_now_diff = 0;
void setNow(int64_t now) {
    g_now_diff = now - time(nullptr);
}

int64_t getNow() {
    return time(nullptr) + g_now_diff;
}


