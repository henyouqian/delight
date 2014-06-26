;//
//  SldUtil.h
//  Sld
//
//  Created by Wei Li on 14-4-7.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

//#import "DMInterstitialAdController.h"

NSString* getResFullPath(NSString* fileName);
NSString* makeDocPath(NSString* path);
UIAlertView* alert(NSString *title, NSString *message);
UIAlertView* alertNoButton(NSString *title);
UIAlertView* alertWithButton(NSString *title, NSString *message, NSString *buttonTitle);

BOOL imageExist(NSString *imageKey);
NSString* makeImagePath(NSString *imageKey);
NSString* makeImagePathFromUrl(NSString *imageUrl);
NSString* makeImageServerUrl(NSString *imageKey);

UIColor* makeUIColor(int r, int g, int b, int a);

UIStoryboard* getStoryboard();

void setServerNow(SInt64 now);
NSDate* getServerNow();

NSString* sha256(NSString* data, NSString *salt);

NSString* formatScore(int score);
NSString* formatInterval(int sec);

@interface SldUtil : NSObject
+ (NSString*)sha1WithString:(NSString*)string;
+ (NSString*)makeGravatarUrlWithKey:(NSString*)gravatarKey width:(UInt32)width;
+ (BOOL)validateEmail:(NSString *) candidate;
+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize;
+ (void)loadAvatar:(UIImageView*)imageView gravatarKey:(NSString*)gravatarKey customAvatarKey:(NSString*)customAvatarKey;
@end

@interface NSData (NSData_Conversion)
- (NSString *)hexadecimalString;
@end

//@interface SldAds : NSObject<DMInterstitialAdControllerDelegate>
//- (instancetype)initWithRootViewController:(UIViewController*)vc;
//- (void)present;
//@end
