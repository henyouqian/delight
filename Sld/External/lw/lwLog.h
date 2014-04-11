#ifndef __LW_LOG_H__
#define	__LW_LOG_H__


#ifdef DEBUG
#   define lwInfo(fmt, ...) NSLog((@"[INFO] %s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#   define lwError(fmt, ...) NSLog((@"[ERROR] %s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#   define lwInfo(...)
#   define lwError(...)
#endif

#endif //__LW_LOG_H__