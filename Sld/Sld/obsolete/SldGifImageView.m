//
//  SldGifImage.m
//  Sld
//
//  Created by Wei Li on 14-5-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldGifImageView.h"
#import "UIImage+animatedGIF.h"
#import "MSWeakTimer.h"
#import "util.h"
#import "SldHttpSession.h"

@interface SldGifImageView()
@property (nonatomic) NSMutableArray *frames;
@property (nonatomic) int frameIndex;
@property (nonatomic) double interval;

@property (nonatomic) MSWeakTimer *msTimer;
@property (nonatomic) NSURL *url;
@end


@implementation SldGifImageView

- (instancetype)init {
    self = [super initWithImage:nil];
    _isGif = NO;
    return self;
}

- (void)dealloc {
    [_msTimer invalidate];
}

- (void)bindGifByURL:(NSURL *)url {
    if ([url isEqual:_url]) {
        return;
    }
    _url = url;
    _frames = [UIImage imageArrayWithAnimatedGIFURL:url];
    if (_frames.count == 0) {
        return;
    }
    
    _frameIndex = 0;
    NSNumber *duration = [_frames lastObject];
    [_frames removeLastObject];
    _interval = [duration doubleValue] / _frames.count;
    
    _msTimer = [MSWeakTimer scheduledTimerWithTimeInterval:(NSTimeInterval)_interval
                                                    target:(id)self
                                                  selector:@selector(onFrame:)
                                                  userInfo:nil
                                                   repeats:YES
                                             dispatchQueue:dispatch_get_main_queue()];
}

- (void)unbindGif {
    _url = nil;
    [_msTimer invalidate];
    _msTimer = nil;
    _frames = nil;
}

- (void)asyncLoadLocalImageWithPath:(NSString*)localPath completion:(void (^)(void))completion{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *image = nil;
        _isGif = [[[localPath pathExtension] lowercaseString] compare:@"gif"] == 0;
        if (_isGif) {
            NSURL *url = [NSURL fileURLWithPath:localPath];
            image = [UIImage animatedImageWithAnimatedGIFURL:url];
            //image = [UIImage imageWithContentsOfFile:localPath];
            //[self bindGifByURL:url];
        } else {
            image = [UIImage imageWithContentsOfFile:localPath];
            [self unbindGif];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.image = image;
            if (completion) {
                completion();
            }
        });
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
    NSString *imageName = [SldUtil sha1WithData:url salt:@""];
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

- (void)onFrame:(MSWeakTimer *)timer {
    if (_frameIndex >= _frames.count) {
        _frameIndex = 0;
    }
    self.image = _frames[_frameIndex];
    _frameIndex++;
}

@end
