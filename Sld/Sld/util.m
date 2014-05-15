//
//  util.m
//  Sld
//
//  Created by Wei Li on 14-4-7.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "util.h"
#import "config.h"
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

BOOL imageExist(NSString *imageKey) {
    NSString *path = makeImagePath(imageKey);
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

NSString* makeImagePath(NSString *imageKey) {
    Config *conf = [Config sharedConf];
    return makeDocPath([NSString stringWithFormat:@"%@/%@", conf.IMG_CACHE_DIR, imageKey]);
}

NSString* makeImagePathFromUrl(NSString *imageUrl) {
    NSString *imageName = [SldUtil sha1WithData:imageUrl salt:@""];
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



@implementation SldUtil

+ (NSString*)sha1WithData:(NSString*)data salt:(NSString*)salt {
    const char *cKey  = [salt cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cData = [data cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    
    NSString *hash;
    NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", cHMAC[i]];
    hash = output;
    return hash;
}

+ (NSString*)makeGravatarUrlWithKey:(NSString*)gravatarKey width:(UInt32)width {
    NSString *url = [NSString stringWithFormat:@"http://www.gravatar.com/avatar/%@?d=identicon&s=%u", gravatarKey, (unsigned int)width*2];
    return url;
}


@end








