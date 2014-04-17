//
//  SldSprite.h
//  Sld
//
//  Created by Wei Li on 14-4-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

@interface SldSprite : SKSpriteNode

@property NSUInteger index;

+(instancetype)spriteWithPath:(NSString*)path index:(NSUInteger)index;
-(instancetype)initWithPath:(NSString*)path index:(NSUInteger)index;

-(BOOL)update;

@end
