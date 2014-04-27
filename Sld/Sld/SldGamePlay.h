//
//  SldGamePlay.h
//  Sld
//
//  Created by Wei Li on 14-4-6.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SldGamePlayDelegate <NSObject>
@required
- (void)onImageFinish:(BOOL)rotate;
- (void)onPackFinish:(BOOL)rotate;
- (void)onNextImageWithRotate:(BOOL)rotate;
@end

@interface SldGamePlay : NSObject

@property (nonatomic) uint32_t sliderNum;
@property (nonatomic, weak) id<SldGamePlayDelegate> delegate;

+ (instancetype)gamePlayWithScene:(SKScene*)scene files:(NSArray *)files;
- (instancetype)initWithScene:(SKScene*)scene files:(NSArray *)files;
- (void)next;

- (void)update;
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;

@end
