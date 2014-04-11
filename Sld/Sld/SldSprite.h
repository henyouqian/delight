//
//  SldSprite.h
//  Sld
//
//  Created by Wei Li on 14-4-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

@interface SldSprite : SKSpriteNode

+(instancetype)spriteWithPath:(NSString*)path;
-(instancetype)initWithPath:(NSString*)path;

-(void)update;

@end
