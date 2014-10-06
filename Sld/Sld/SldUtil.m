//
//  util.m
//  Sld
//
//  Created by Wei Li on 14-4-7.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldUtil.h"
#import "SldConfig.h"
#import "SldGameData.h"
#import "UIImageView+sldAsyncLoad.h"
#import "NSData+Base64.h"
#import <CommonCrypto/CommonHMAC.h>

NSString* getResFullPath(NSString* fileName) {
    return [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
}

NSString* makeDocPath(NSString* path) {
    NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    return [docsPath stringByAppendingPathComponent:path];
}

NSString* makeTempPath(NSString* fileName) {
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    return filePath;
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
    SldConfig *conf = [SldConfig getInstance];
    return makeDocPath([NSString stringWithFormat:@"%@/%@", conf.IMG_CACHE_DIR, imageKey]);
}

NSString* makeImagePathFromUrl(NSString *imageUrl) {
    NSString *imageName = [SldUtil sha1WithString:imageUrl];
    return makeImagePath(imageName);
}

NSString* makeImageServerUrl(NSString *imageKey) {
    SldConfig *conf = [SldConfig getInstance];
    return [NSString stringWithFormat:@"%@/%@", conf.DATA_HOST, imageKey];
}

NSString* makeImageServerUrl2(NSString *imageKey, NSString *host) {
    return [NSString stringWithFormat:@"%@/%@", host, imageKey];
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
        return @"暂无记录";
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

+ (NSString*)sha1WithData:(NSData*)data {
    SHA1 *md = [[SHA1 alloc] init];
    
    [md updateWith:data.bytes length:data.length];
    [md final];
    
    NSData *nsd = [NSData dataWithBytes:md.buffer length:md.bufferSize];
    return [nsd urlBase64EncodedString];
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

+ (void)setKeyChainWithKey:(NSString*)key value:(NSString*)value {
    SldConfig *conf = [SldConfig getInstance];
    [SSKeychain setPassword:value forService:conf.KEYCHAIN_KV account:key];
}

+ (NSString*)getKeyChainValueWithKey:(NSString*)key {
    SldConfig *conf = [SldConfig getInstance];
    NSString *value = [SSKeychain passwordForService:conf.KEYCHAIN_KV account:key];
    return value;
}

+ (UIColor*)getPinkColor {
    return makeUIColor(244, 75, 116, 255);
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

//============================
@interface SldBottomRefreshControl()
@end

@implementation SldBottomRefreshControl
- (instancetype)init {
    if (self = [super initWithFrame:CGRectMake(0, 0, 320, 44)]) {
        _spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        CGRect frame = _spin.frame;
        frame.origin.x = 150;
        frame.origin.y = 12;
        _spin.frame = frame;
        [self addSubview:_spin];
        _spin.hidden = YES;
        [_spin stopAnimating];
        _refreshing = NO;
    }
    return self;
}

- (void)beginRefreshing {
    _spin.hidden = NO;
    [_spin startAnimating];
    _refreshing = YES;
}

- (void)endRefreshing {
    _spin.hidden = YES;
    [_spin stopAnimating];
    _refreshing = NO;
}
@end

//============================
@implementation SldSpinFooter

- (instancetype)init {
    if (self = [super init]) {
        _spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [self addSubview:_spin];
        _spin.center = CGPointMake(self.frame.size.width*0.5, self.frame.size.height*0.5);
    }
    return self;
}

@end


//============================
@interface SldCollectionView : UICollectionView
@end

@implementation SldCollectionView

- (void)setContentInset:(UIEdgeInsets)contentInset {
    if (self.tracking) {
        CGFloat diff = contentInset.top - self.contentInset.top;
        CGPoint translation = [self.panGestureRecognizer translationInView:self];
        translation.y -= diff * 3.0 / 2.0;
        [self.panGestureRecognizer setTranslation:translation inView:self];
    }
    [super setContentInset:contentInset];
}

@end

//============================
@implementation UIWindow (PazLabs)

- (UIViewController *)visibleViewController {
    UIViewController *rootViewController = self.rootViewController;
    return [UIWindow getVisibleViewControllerFrom:rootViewController];
}

+ (UIViewController *) getVisibleViewControllerFrom:(UIViewController *) vc {
    if ([vc isKindOfClass:[UINavigationController class]]) {
        return [UIWindow getVisibleViewControllerFrom:[((UINavigationController *) vc) visibleViewController]];
    } else if ([vc isKindOfClass:[UITabBarController class]]) {
        return [UIWindow getVisibleViewControllerFrom:[((UITabBarController *) vc) selectedViewController]];
    } else {
        if (vc.presentedViewController) {
            return [UIWindow getVisibleViewControllerFrom:vc.presentedViewController];
        } else {
            return vc;
        }
    }
}

@end

//============================
@implementation SldLoadMoreCell
@end


