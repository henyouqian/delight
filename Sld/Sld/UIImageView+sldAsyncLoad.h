//
//  UIImageView+sldAsyncLoad.h
//  Sld
//
//  Created by Wei Li on 14-5-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImageView (sldAsyncLoad)

- (void)asyncLoadImageWithKey:(NSString*)imageKey showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion;
- (void)asyncLoadImageWithUrl:(NSString*)url showIndicator:(BOOL)showIndicator completion:(void (^)(void))completion;

@end
