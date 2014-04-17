#ifndef __LW_LOG_H__
#define	__LW_LOG_H__

#define FLE (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)

#ifdef DEBUG
//#   define lwInfo(fmt, ...) NSLog((@"[INFO] %s [%s][Line %d] " fmt), __PRETTY_FUNCTION__, FLE, __LINE__, ##__VA_ARGS__)
//#   define lwError(fmt, ...) NSLog((@"[ERROR] %s [%s][Line %d] " fmt), __PRETTY_FUNCTION__, FLE, __LINE__, ##__VA_ARGS__)
#   define lwInfo(fmt, ...) NSLog((@"[INFO:%s:%d:%s] " fmt), FLE, __LINE__, __PRETTY_FUNCTION__, ##__VA_ARGS__)
#   define lwError(fmt, ...) NSLog((@"[ERROR:%s:%d:%s] " fmt), FLE, __LINE__, __PRETTY_FUNCTION__, ##__VA_ARGS__)
#else
#   define lwInfo(...)
#   define lwError(...)
#endif

#endif //__LW_LOG_H__