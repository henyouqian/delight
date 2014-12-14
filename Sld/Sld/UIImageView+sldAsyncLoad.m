//
//  UIImageView+sldAsyncLoad.m
//  Sld
//
//  Created by Wei Li on 14-5-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "UIImageView+sldAsyncLoad.h"
#import "UIImage+animatedGIF.h"
#import "SldUtil.h"
#import "SldHttpSession.h"
#import "SldConfig.h"


@implementation UIImageView (sldAsyncLoad)


- (void)asLoadLocalImageWithPath:(NSString*)localPath completion:(void (^)(void))completion{
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

- (void)asLoadImageWithKey:(NSString*)imageKey host:(NSString*)host showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion {
    if (imageKey == nil) {
        return;
    }
    UIActivityIndicatorView *indicatorView = nil;
    if (showIndicator) {
        indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
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
        [self asLoadLocalImageWithPath:localPath completion:^{
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
        [session downloadFromUrl:makeImageServerUrl2(imageKey, host)
                          toPath:localPath
                        withData:nil completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error, id data)
         {
             if (error) {
                 if (indicatorView) {
                     [indicatorView removeFromSuperview];
                 }
                 lwError("imageKey:%@, host:%@", imageKey, host);
                 lwError("Download error: %@, url:%@", error.localizedDescription, location);
                 return;
             }
             
             [self asLoadLocalImageWithPath:localPath completion:^{
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

- (void)asLoadImageWithKey:(NSString*)imageKey showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion {
    //NSString *host = [SldConfig getInstance].DATA_HOST;
    NSString *host = [SldConfig getInstance].UPLOAD_HOST;
    [self asLoadImageWithKey:imageKey host:host showIndicator:showIndicator completion:completion];
}

- (void)asLoadUploadedImageWithKey:(NSString*)imageKey showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion {
    NSString *host = [SldConfig getInstance].UPLOAD_HOST;
    [self asLoadImageWithKey:imageKey host:host showIndicator:showIndicator completion:completion];
}

- (void)asLoadImageWithUrl:(NSString*)url showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion {
    NSString *imageName = [SldUtil sha1WithString:url];
    NSString *localPath = makeImagePath(imageName);
    
    UIActivityIndicatorView *indicatorView = nil;
    if (showIndicator) {
        indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        indicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin
        | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        
        [indicatorView sizeToFit];
        [indicatorView startAnimating];
        indicatorView.center = CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2);
        
        [self addSubview:indicatorView];
    }
    
    //local
    if ([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        [self asLoadLocalImageWithPath:localPath completion:^{
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
                        withData:nil completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error, id data)
         {
             if (error) {
                 if (indicatorView) {
                     [indicatorView removeFromSuperview];
                 }
                 lwError("Download error: %@, url:%@", error.localizedDescription, location);
                 return;
             }
             
             [self asLoadLocalImageWithPath:localPath completion:^{
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

//==========================

@implementation SldAsyncImageView

- (void)asyncLoadLocalImageWithPath:(NSString*)localPath anim:(BOOL)anim thumbSize:(int)thumbSize completion:(void (^)(void))completion{
    if (localPath == nil) {
        lwError("localPath == nil");
        return;
    }
    
    if (self.image && _localPath && [_localPath compare:localPath] == 0) {
        return;
    }
    
    if (_loading) {
        return;
    }
    _loading = YES;
    _localPath = localPath;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL isGif = [[[localPath pathExtension] lowercaseString] compare:@"gif"] == 0;
        if (isGif && anim) {
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
                if ([_localPath compare:localPath] != 0) {
                    return;
                }
                self.animationImages = frames;
                self.image = frames[0];
                if (completion) {
                    completion();
                }
                _loading = false;
                if (_loadCanceling) {
                    _loadCanceling = NO;
                    self.image = nil;
                    self.animationImages = nil;
                } else {
                    [self startAnimating];
                }
            });
        } else {
            UIImage *image = nil;
            if (thumbSize > 0) {
                int size = thumbSize;
                if ( thumbSize > 256 ) {
                    size = 256;
                }
                float fSize = (float)size;
                NSString *path = [NSString stringWithFormat:@"%@_thumb%d", localPath, size];
                if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                    image = [UIImage imageWithContentsOfFile:path];
                } else {
                    image = [UIImage imageWithContentsOfFile:localPath];
                    float s = MIN(image.size.width, image.size.height);
                    float scale = fSize/s;
                    float w = image.size.width * scale;
                    float h = image.size.height * scale;
                    image = [SldUtil imageWithImage:image scaledToSize:CGSizeMake(w, h)];
                    CGRect cropRect = CGRectMake(0, 0, fSize, fSize);
                    if (image.size.width >= image.size.height) {
                        cropRect.origin.x = w*0.5-fSize*0.5;
                    } else {
                        cropRect.origin.y = h*0.5-fSize*0.5;
                    }
                    
                    CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], cropRect);
                    image = [UIImage imageWithCGImage:imageRef];
                    
                    //thumb save
                    NSData *data = UIImageJPEGRepresentation(image, 0.85);
                    [data writeToFile:path atomically:YES];
                }
            } else {
                image = [UIImage imageWithContentsOfFile:localPath];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([_localPath compare:localPath] != 0) {
                    return;
                }
                self.image = image;
                self.animationImages = nil;
                if (completion) {
                    completion();
                }
                _loading = false;
                if (_loadCanceling) {
                    _loadCanceling = NO;
                    self.image = nil;
                    self.animationImages = nil;
                }
            });
        }
    });
}

- (void)asyncLoadImageWithKey:(NSString*)imageKey host:(NSString *)host showIndicator:(BOOL)showIndicator anim:(BOOL)anim thumbSize:(int)thumbSize completion:(void (^)(void))completion {
    if (imageKey == nil || _loading) {
        return;
    }
    if (self.image && _key && [_key compare:imageKey] == 0) {
        return;
    } else {
        _key = imageKey;
    }
    self.image = nil;
    UIActivityIndicatorView *indicatorView = nil;
    if (showIndicator) {
        indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        indicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin
        | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        
        [indicatorView sizeToFit];
        [indicatorView startAnimating];
        indicatorView.center = CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2);
        indicatorView.frame = self.bounds;
        
        [self addSubview:indicatorView];
    }
    
    //
    NSString* localPath = makeImagePath(imageKey);
    //local
    if ([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        [self asyncLoadLocalImageWithPath:localPath anim:anim thumbSize:thumbSize completion:^{
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
        if (_task) {
            [_task cancel];
        }
        
        _serverUrl = makeImageServerUrl2(imageKey, host);
        SldHttpSession *session = [SldHttpSession defaultSession];
        _task = [session downloadFromUrl:_serverUrl
                          toPath:localPath
                        withData:nil completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error, id data)
         {
             if (indicatorView) {
                 [indicatorView removeFromSuperview];
             }
             
             _task = nil;
             NSURL *nsurl = [NSURL URLWithString:_serverUrl];
             if (![response.URL isEqual:nsurl]) {
                 lwInfo("![response.URL isEqual:nsurl]");
                 return;
             }
             if (error) {
                 lwError("Download error: %@, url:%@", error.localizedDescription, location);
                 return;
             }
             
             [self asyncLoadLocalImageWithPath:localPath anim:anim thumbSize:thumbSize completion:^{
                 if (completion) {
                     completion();
                 }
             }];
         }];
    }
}

- (void)asyncLoadImageWithKey:(NSString*)imageKey showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion {
//    [self asyncLoadImageWithKey:imageKey host:[SldConfig getInstance].DATA_HOST showIndicator:showIndicator completion:completion];
    [self asyncLoadImageWithKey:imageKey host:[SldConfig getInstance].UPLOAD_HOST showIndicator:showIndicator anim:YES thumbSize:0 completion:completion];
}

- (void)asyncLoadUploadImageWithKey:(NSString*)imageKey showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion {
    [self asyncLoadImageWithKey:imageKey host:[SldConfig getInstance].UPLOAD_HOST showIndicator:showIndicator anim:YES thumbSize:0 completion:completion];
}

- (void)asyncLoadUploadImageNoAnimWithKey:(NSString*)imageKey thumbSize:(int)thumbSize showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion {
    [self asyncLoadImageWithKey:imageKey host:[SldConfig getInstance].UPLOAD_HOST showIndicator:showIndicator anim:NO thumbSize:thumbSize completion:completion];
}

- (void)asyncLoadImageWithUrl:(NSString*)url showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion {
    if (_loading) {
        return;
    }
    if (self.image && _key && [_key compare:url] == 0) {
        return;
    } else {
        _key = url;
    }
    
    self.image = nil;
    
    NSString *imageName = [SldUtil sha1WithString:url];
    NSString *localPath = makeImagePath(imageName);
    
    UIActivityIndicatorView *indicatorView = nil;
    if (showIndicator) {
        indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        indicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin
        | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        
        [indicatorView sizeToFit];
        [indicatorView startAnimating];
        indicatorView.center = CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2);
        
        [self addSubview:indicatorView];
    }
    
    //local
    if ([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        [self asyncLoadLocalImageWithPath:localPath anim:YES thumbSize:0 completion:^{
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
        _serverUrl = url;
        SldHttpSession *session = [SldHttpSession defaultSession];
        if (_task) {
            [_task cancel];
            lwInfo("_task cancel");
        }
        _task = [session downloadFromUrl:url
                          toPath:localPath
                        withData:nil completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error, id data)
         {
             if (indicatorView) {
                 [indicatorView removeFromSuperview];
             }
             
             _task = nil;
             NSURL *nsurl = [NSURL URLWithString:_serverUrl];
             if (![response.URL isEqual:nsurl]) {
                 lwInfo("![response.URL isEqual:nsurl]");
                 return;
             }
             
             if (error) {
                 lwError("Download error: %@, url:%@", error.localizedDescription, location);
                 return;
             }
             
             [self asyncLoadLocalImageWithPath:localPath anim:YES thumbSize:0 completion:^{
                 if (completion) {
                     completion();
                 }
             }];
         }];
    }
}

- (void)releaseImage {
    if (_loading) {
        _loadCanceling = YES;
    } else {
        self.image = nil;
        self.animationImages = nil;
    }
}

@end
