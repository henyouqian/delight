//
//  UIImageView+sldAsyncLoad.m
//  Sld
//
//  Created by Wei Li on 14-5-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "UIImageView+sldAsyncLoad.h"
#import "UIImage+animatedGIF.h"
#import "util.h"
#import "SldHttpSession.h"


@implementation UIImageView (sldAsyncLoad)


- (void)asyncLoadLocalImageWithPath:(NSString*)localPath completion:(void (^)(void))completion{
    if (localPath == nil) {
        lwError("localPath == nil");
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL isGif = [[[localPath pathExtension] lowercaseString] compare:@"gif"] == 0;
        if (isGif) {
            NSURL *url = [NSURL fileURLWithPath:localPath];
            
            NSMutableArray* frames = [UIImage imageArrayWithAnimatedGIFURL:url];
            if (frames.count <= 1) {
                return;
            }
            NSNumber *duration = [frames lastObject];
            [frames removeLastObject];
            self.animationDuration = [duration doubleValue];
            self.animationRepeatCount = 0;
            dispatch_async(dispatch_get_main_queue(), ^{
                self.animationImages = frames;
                self.image = frames[0];
                if (completion) {
                    completion();
                }
                [self startAnimating];
            });
        } else {
            UIImage *image = [UIImage imageWithContentsOfFile:localPath];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.image = image;
                self.animationImages = nil;
                if (completion) {
                    completion();
                }
            });
        }
    });
}

- (void)asyncLoadImageWithKey:(NSString*)imageKey showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion {
    UIActivityIndicatorView *indicatorView = nil;
    if (showIndicator) {
        indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        indicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin
        | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        
        [indicatorView sizeToFit];
        [indicatorView startAnimating];
        indicatorView.center = CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2);
        
        [self addSubview:indicatorView];
    }
    
    //
    NSString* localPath = makeImagePath(imageKey);
    //local
    if ([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        [self asyncLoadLocalImageWithPath:localPath completion:^{
            if (indicatorView) {
                [indicatorView removeFromSuperview];
            }
            if (completion) {
                completion();
            }
        }];
    }
    //remote
    else {
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session downloadFromUrl:makeImageServerUrl(imageKey)
                          toPath:localPath
                        withData:nil completionHandler:^(NSURL *location, NSError *error, id data)
         {
             if (error) {
                 if (indicatorView) {
                     [indicatorView removeFromSuperview];
                 }
                 lwError("Download error: %@", error.localizedDescription);
                 return;
             }
             
             [self asyncLoadLocalImageWithPath:localPath completion:^{
                 if (indicatorView) {
                     [indicatorView removeFromSuperview];
                 }
                 if (completion) {
                     completion();
                 }
             }];
         }];
    }
}

- (void)asyncLoadImageWithUrl:(NSString*)url showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion {
    NSString *imageName = [SldUtil sha1WithData:url];
    NSString *localPath = makeImagePath(imageName);
    
    UIActivityIndicatorView *indicatorView = nil;
    if (showIndicator) {
        indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        indicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin
        | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        
        [indicatorView sizeToFit];
        [indicatorView startAnimating];
        indicatorView.center = CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2);
        
        [self addSubview:indicatorView];
    }
    
    //local
    if ([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        [self asyncLoadLocalImageWithPath:localPath completion:^{
            if (indicatorView) {
                [indicatorView removeFromSuperview];
            }
            if (completion) {
                completion();
            }
        }];
    }
    //remote
    else {
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session downloadFromUrl:url
                          toPath:localPath
                        withData:nil completionHandler:^(NSURL *location, NSError *error, id data)
         {
             if (error) {
                 if (indicatorView) {
                     [indicatorView removeFromSuperview];
                 }
                 lwError("Download error: %@", error.localizedDescription);
                 return;
             }
             
             [self asyncLoadLocalImageWithPath:localPath completion:^{
                 if (indicatorView) {
                     [indicatorView removeFromSuperview];
                 }
                 if (completion) {
                     completion();
                 }
             }];
         }];
    }
}

@end
