//
//  util.m
//  Sld
//
//  Created by Wei Li on 14-4-7.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldUtil.h"
#import "config.h"
#import "SldGameData.h"
#import "UIImageView+sldAsyncLoad.h"
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

UIAlertView* alertWithButton(NSString *title, NSString *message, NSString *buttonTitle) {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:buttonTitle
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
    NSString *imageName = [SldUtil sha1WithString:imageUrl];
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

NSString* formatInterval(int sec) {
    int hour = sec / 3600;
    int minute = (sec % 3600)/60;
    sec = (sec % 60);
    return [NSString stringWithFormat:@"%02d:%02d:%02d", hour, minute, sec];
}

@implementation SldUtil

+ (NSString*)sha1WithString:(NSString*)string {
    SHA1 *sha1 = [SHA1 sha1WithString:string];
    NSData *nsd = [NSData dataWithBytes:sha1.buffer length:sha1.bufferSize];
    NSString *output = [nsd hexadecimalString];
    return output;
}

+ (NSString*)makeGravatarUrlWithKey:(NSString*)gravatarKey width:(UInt32)width {
    NSString *url = [NSString stringWithFormat:@"http://www.gravatar.com/avatar/%@?d=identicon&s=%u", gravatarKey, (unsigned int)width*2];
    return url;
}

+ (BOOL)validateEmail:(NSString *) candidate {
    NSString *emailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,6}";
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    
    return [emailTest evaluateWithObject:candidate];
}

+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

+ (void)loadAvatar:(UIImageView*)imageView gravatarKey:(NSString*)gravatarKey customAvatarKey:(NSString*)customAvatarKey {
    
    imageView.image = nil;
    if (customAvatarKey && customAvatarKey.length > 0) {
        [imageView asyncLoadImageWithKey:customAvatarKey showIndicator:NO completion:nil];
    } else if (gravatarKey && gravatarKey.length > 0){
        NSString *url = [SldUtil makeGravatarUrlWithKey:gravatarKey width:imageView.frame.size.width];
        [imageView asyncLoadImageWithUrl:url showIndicator:NO completion:nil];
    }
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

//static SldAds *_ads = nil;
//
//@interface SldAds()
//@property (nonatomic) DMInterstitialAdController *dmInterstitial;
//@end
//
//@implementation SldAds
//
//- (instancetype)initWithRootViewController:(UIViewController*)vc {
//    if (self = [super init]) {
//        _dmInterstitial = [[DMInterstitialAdController alloc]
//                            initWithPublisherId:@"56OJyJPouM8jf7a4AW"
//                                    placementId:@"16TLwo3vAc2U4NUERQaZtLGs"
//                             rootViewController:vc
//                                           size:DOMOB_AD_SIZE_300x250];
//        
//        _dmInterstitial.delegate = self;
//        [_dmInterstitial loadAd];
//        
//        SldGameData *gd = [SldGameData getInstance];
//        if (gd.gender == 0) {
//            [_dmInterstitial setUserGender:DMUserGenderFemale];
//        } else {
//            [_dmInterstitial setUserGender:DMUserGenderMale];
//        }
//    }
//    return self;
//}
//
//- (void)present {
//    if (_dmInterstitial.isReady){
//        [_dmInterstitial present];
//    } else {
//        [_dmInterstitial loadAd];
//    }
//}
//
//- (void)dmInterstitialDidDismissScreen:(DMInterstitialAdController *)dmInterstitial {
//    [_dmInterstitial loadAd];
//}
//
//@end

