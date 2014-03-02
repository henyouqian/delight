LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := cocos2dcpp_shared

LOCAL_MODULE_FILENAME := libcocos2dcpp

LOCAL_SRC_FILES := hellocpp/main.cpp \
                  ../../Classes/mainMenuScene.cpp \
                  ../../Classes/collectionListScene.cpp \
                  ../../Classes/packsListScene.cpp \
                  ../../Classes/modeSelectScene.cpp \
                  ../../Classes/sliderScene.cpp \
                  ../../Classes/dragView.cpp \
                  ../../Classes/spriteLoader.cpp \
                  ../../Classes/gameplay.cpp \
                  ../../Classes/pack.cpp \
                  ../../Classes/gifTexture.cpp \
                  ../../Classes/menuBar.cpp \
                  ../../Classes/http.cpp \
                  ../../Classes/util.cpp \
                  ../../Classes/db.cpp \
                  ../../Classes/lang.cpp \
                  ../../Classes/AppDelegate.cpp \
                  ../../external/giflib/dgif_lib.c \
                  ../../external/giflib/gif_err.c \
                  ../../external/giflib/gif_font.c \
                  ../../external/giflib/gif_hash.c \
                  ../../external/giflib/gifalloc.c \
                  ../../external/giflib/quantize.c \
                  ../../external/jsonxx/jsonxx.cc \
                  ../../external/crypto/sha.cpp \
                  ../../external/sqlite/sqlite3.c \
                  ../../external/qiniu/b64/b64.c \
                  ../../external/qiniu/b64/urlsafe_b64.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../../Classes \
					$(LOCAL_PATH)/../../external

LOCAL_WHOLE_STATIC_LIBRARIES += cocos2dx_static
LOCAL_WHOLE_STATIC_LIBRARIES += cocosdenshion_static
LOCAL_WHOLE_STATIC_LIBRARIES += box2d_static
LOCAL_WHOLE_STATIC_LIBRARIES += cocos_extension_static
LOCAL_WHOLE_STATIC_LIBRARIES += cocos2dxandroid_static

include $(BUILD_SHARED_LIBRARY)

$(call import-module,cocos2dx)
$(call import-module,cocos2dx/platform/third_party/android/prebuilt/libcurl)
$(call import-module,CocosDenshion/android)
$(call import-module,extensions)
$(call import-module,external/Box2D)
$(call import-module,cocos2dx/platform/android)
