;//
//  SldUtil.h
//  Sld
//
//  Created by Wei Li on 14-4-7.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

//#import "DMInterstitialAdController.h"

@class SldAsyncImageView;

NSString* getResFullPath(NSString* fileName);
NSString* makeDocPath(NSString* path);
NSString* makeTempPath(NSString* fileName);
UIAlertView* alert(NSString *title, NSString *message);
UIAlertView* alertNoButton(NSString *title);
UIAlertView* alertWithButton(NSString *title, NSString *message, NSString *buttonTitle);

BOOL imageExist(NSString *imageKey);
NSString* makeImagePath(NSString *imageKey);
NSString* makeImagePathFromUrl(NSString *imageUrl);
NSString* makeImageServerUrl(NSString *imageKey);
NSString* makeImageServerUrl2(NSString *imageKey, NSString *host);

UIColor* makeUIColor(int r, int g, int b, int a);

UIStoryboard* getStoryboard();

void setServerNow(SInt64 now);
NSDate* getServerNow();
UInt64 getServerNowSec();

NSString* sha256(NSString* data, NSString *salt);

NSString* formatScore(int score);
NSString* formatInterval(int sec);

@interface SldUtil : NSObject
+ (NSString*)sha1WithString:(NSString*)string;
+ (NSString*)sha1WithData:(NSData*)data;
+ (NSString*)makeGravatarUrlWithKey:(NSString*)gravatarKey width:(UInt32)width;
+ (BOOL)validateEmail:(NSString *) candidate;
+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize;
+ (void)loadAvatar:(SldAsyncImageView*)imageView gravatarKey:(NSString*)gravatarKey customAvatarKey:(NSString*)customAvatarKey;

+ (void)setKeyChainWithKey:(NSString*)key value:(NSString*)value;
+ (NSString*)getKeyChainValueWithKey:(NSString*)key;

+ (UIColor*)getPinkColor;

+ (void)sendWithSocket:(SRWebSocket*)socket type:(NSString*)type data:(NSDictionary*)dict;

+ (NSString *)genUUID;

+ (void)secureSetString:(NSString*)str withKey:(NSString*)key;
+ (NSString*)secureGetStringWithKey:(NSString*)key;
+ (void)secureSetInt:(int)value withKey:(NSString*)key;
+ (int)secureGetIntWithKey:(NSString*)key;
+ (void)secureSetDouble:(double)value withKey:(NSString*)key;
+ (double)secureGetDoubleWithKey:(NSString*)key;

@end

@interface NSData (NSData_Conversion)
- (NSString *)hexadecimalString;
@end

//@interface SldAds : NSObject<DMInterstitialAdControllerDelegate>
//- (instancetype)initWithRootViewController:(UIViewController*)vc;
//- (void)present;
//@end

@interface SldBottomRefreshControl : UIView
@property (nonatomic) UIActivityIndicatorView *spin;
@property (nonatomic, readonly) BOOL refreshing;

- (instancetype)init;
- (void)beginRefreshing;
- (void)endRefreshing;
@end

//=============================
@interface SldSpinFooter : UICollectionReusableView
@property (nonatomic) UIActivityIndicatorView *spin;

- (instancetype)init;
@end

//============================
@interface UIWindow (PazLabs)

- (UIViewController *) visibleViewController;

@end

//=================
@interface SldLoadMoreCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spin;
@property (weak, nonatomic) IBOutlet UIButton *moreButton;

- (void)startSpin;
- (void)stopSpin;
- (void)noMore;

@end



