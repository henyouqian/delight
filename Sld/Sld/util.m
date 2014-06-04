//
//  util.m
//  Sld
//
//  Created by Wei Li on 14-4-7.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "util.h"
#import "config.h"
#import "nv-ios-digest/SHA1.h"
#import <CommonCrypto/CommonHMAC.h>

NSString* getResFullPath(NSString* fileName) {
    return [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
}

NSString* makeDocPath(NSString* path) {
    NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    return [docsPath stringByAppendingPathComponent:path];
}

UIAlertView* alert(NSString *title, NSString *message) {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    return alert;
}

UIAlertView* alertNoButton(NSString *title) {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:nil
                                                   delegate:nil
                                          cancelButtonTitle:nil
                                          otherButtonTitles:nil];
    [alert show];
    return alert;
}

BOOL imageExist(NSString *imageKey) {
    NSString *path = makeImagePath(imageKey);
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

NSString* makeImagePath(NSString *imageKey) {
    Config *conf = [Config sharedConf];
    return makeDocPath([NSString stringWithFormat:@"%@/%@", conf.IMG_CACHE_DIR, imageKey]);
}

NSString* makeImagePathFromUrl(NSString *imageUrl) {
    NSString *imageName = [SldUtil sha1WithData:imageUrl];
    return makeImagePath(imageName);
}

NSString* makeImageServerUrl(NSString *imageKey) {
    Config *conf = [Config sharedConf];
    return [NSString stringWithFormat:@"%@/%@", conf.DATA_HOST, imageKey];
}

UIColor* makeUIColor(int r, int g, int b, int a) {
    return [UIColor colorWithRed:r/255.f green:g/255.f blue:b/255.f alpha:a/255.f];
}

UIStoryboard* getStoryboard() {
    UIApplication *application = [UIApplication sharedApplication];
    UIWindow *backWindow = application.windows[0];
    return backWindow.rootViewController.storyboard;
}

static NSTimeInterval serverTimeCorrect = 0;
void setServerNow(SInt64 now) {
    NSDate *nowDate = [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval dt = [nowDate timeIntervalSince1970];
    serverTimeCorrect = now - dt;
    serverTimeCorrect = floor(serverTimeCorrect);
}

NSDate *getServerNow() {
    NSDate *now = [NSDate dateWithTimeIntervalSinceNow:serverTimeCorrect];
    return now;
}

NSString* sha256(NSString* data, NSString *salt) {
    if (salt == nil) {
        salt = @"";
    }
    const char *cKey  = [salt cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cData = [data cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    
    NSString *hash;
    NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", cHMAC[i]];
    hash = output;
    return hash;
}

NSString* formatScore(int score) {
    int msec = -score;
    if (msec == 0) {
        return @"无记录";
    } else {
        int sec = msec/1000;
        int min = sec / 60;
        sec = sec % 60;
        msec = msec % 1000;
        return [NSString stringWithFormat:@"%01d:%02d.%03d", min, sec, msec];
    }
    return @"";
}

@implementation SldUtil

+ (NSString*)sha1WithData:(NSString*)data {
    SHA1 *sha1 = [SHA1 sha1WithString:data];
    NSData *nsd = [NSData dataWithBytes:sha1.buffer length:sha1.bufferSize];
    NSString *output = [nsd hexadecimalString];
    return output;
}

+ (NSString*)makeGravatarUrlWithKey:(NSString*)gravatarKey width:(UInt32)width {
    NSString *url = [NSString stringWithFormat:@"http://www.gravatar.com/avatar/%@?d=identicon&s=%u", gravatarKey, (unsigned int)width*2];
    return url;
}

@end



@implementation NSData (NSData_Conversion)

- (NSString *)hexadecimalString
{
    /* Returns hexadecimal string of NSData. Empty string if data is empty.   */
    
    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];
    
    if (!dataBuffer)
    {
        return [NSString string];
    }
    
    NSUInteger          dataLength  = [self length];
    NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < dataLength; ++i)
    {
        [hexString appendFormat:@"%02x", (unsigned int)dataBuffer[i]];
    }
    
    return [NSString stringWithString:hexString];
}

@end



