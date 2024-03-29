//
//  UIImageView+sldAsyncLoad.h
//  Sld
//
//  Created by Wei Li on 14-5-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImageView (sldAsyncLoad)

- (void)asLoadLocalImageWithPath:(NSString*)localPath completion:(void (^)(void))completion;
- (void)asLoadImageWithKey:(NSString*)imageKey host:(NSString*)host showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion;
- (void)asLoadImageWithKey:(NSString*)imageKey showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion;
- (void)asLoadUploadedImageWithKey:(NSString*)imageKey showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion;
- (void)asLoadImageWithUrl:(NSString*)url showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion;

@end


@interface SldAsyncImageView : UIImageView
@property (atomic) BOOL loading;
@property (atomic) BOOL loadCanceling;
@property (atomic) NSString *serverUrl;
@property (atomic) NSString *localPath;
@property (atomic) NSURLSessionDownloadTask *task;
@property (atomic) NSString *key;

- (void)asyncLoadLocalImageWithPath:(NSString*)localPath anim:(BOOL)anim thumbSize:(int)thumbSize completion:(void (^)(void))completion;
- (void)asyncLoadImageWithKey:(NSString*)imageKey host:(NSString*)host showIndicator:(BOOL)showIndicator anim:(BOOL)anim thumbSize:(int)thumbSize completion:(void (^)(void))completion;
- (void)asyncLoadImageWithKey:(NSString*)imageKey showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion;
- (void)asyncLoadUploadImageWithKey:(NSString*)imageKey showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion;

- (void)asyncLoadUploadImageNoAnimWithKey:(NSString*)imageKey thumbSize:(int)thumbSize showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion;

- (void)asyncLoadImageWithUrl:(NSString*)url showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion;
- (void)asyncLoadPrivateImageWithUrl:(NSString*)url key:(NSString*)key completion:(void (^)(void))completion;
- (void)releaseImage;
@end