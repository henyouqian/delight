//
//  SldButton.h
//  Sld
//
//  Created by Wei Li on 14-4-25.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

typedef void(^OnButtonClickBlock)(void);


@interface SldButton : SKNode

@property (nonatomic, strong) OnButtonClickBlock onClick;
@property (nonatomic) BOOL enabled;

+ (instancetype)buttonWithImageNamed:(NSString*)imageName;
- (void)setBackgroundAlpha:(float)alpha;
- (void)setBackgroundColor:(UIColor*)color;
- (void)setLabelWithText:(NSString*)text color:(UIColor*)color fontSize:(float)fontSize;
- (void)setFontColor:(UIColor*)color;

@end
