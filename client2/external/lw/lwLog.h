#ifndef __LW_LOG_H__
#define	__LW_LOG_H__



#define FLE (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)

#ifndef REMOVE_LOGGING
    #ifdef ANDROID
        #include <android/log.h>
        #define lwerror(message, ...) \
            do { __android_log_print(ANDROID_LOG_ERROR, "lw", "[E:%s:%d] " message, FLE, __LINE__, ##__VA_ARGS__); } while (0)
        #define lwinfo(message, ...) \
            do { __android_log_print(ANDROID_LOG_INFO, "lw", "[I:%s:%d] " message, FLE, __LINE__, ##__VA_ARGS__); } while (0)
    #else
        #define lwerror(message, ...) \
            do { std::printf("[E:%s:%d] " message "\n", FLE, __LINE__,  ##__VA_ARGS__); } while(0)
        #define lwinfo(message, ...) \
            do { std::printf("[I:%s:%d] " message "\n", FLE, __LINE__,  ##__VA_ARGS__); } while(0)
    #endif
#else
    #define LOG_DEBUG(message, ...) do { } while (0)
#endif


#endif //__LW_LOG_H__