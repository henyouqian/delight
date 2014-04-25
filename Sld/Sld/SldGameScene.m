//
//  SldGameScene.m
//  Sld
//
//  Created by Wei Li on 14-4-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldGameScene.h"
#import "util.h"
#import "SldButton.h"

@interface SldGameScene()
@end

@implementation SldGameScene

+ (instancetype)sceneWithSize:(CGSize)size packInfo:(PackInfo*)packInfo {
    SldGameScene* inst = [[SldGameScene alloc] initWithSize:size packInfo:packInfo];
    return inst;
}

- (instancetype)initWithSize:(CGSize)size packInfo:(PackInfo*)packInfo {
    if (self = [super initWithSize:size]) {
        self.packInfo = packInfo;
        NSMutableArray *files = [NSMutableArray arrayWithCapacity:[self.packInfo.images count]];
        
        for (NSString *img in packInfo.images) {
            [files addObject:makeImagePath(img)];
        }
        
        self.gamePlay = [SldGamePlay gamePlayWithScene:self files:files];
        
        //back button
        SldButton *button = [SldButton buttonWithImageNamed:@"btnBgWhite.png"];
        [button setLabelWithText:@"Back" color:[UIColor colorWithWhite:0.f alpha:1.f]];
        [button setPosition:CGPointMake(50, 50)];
        [button setAlpha:.5f];
        [button setScale:.5f];
        button.onClick = ^{
            [self.navigationController popViewControllerAnimated:YES];
        };
        [self addChild:button];
        
    }
    return self;
}

-(void)dealloc {
    
}

-(void)update:(CFTimeInterval)currentTime {
    [self.gamePlay update];
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.gamePlay touchesBegan:touches withEvent:event];
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.gamePlay touchesMoved:touches withEvent:event];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.gamePlay touchesEnded:touches withEvent:event];
}

@end
