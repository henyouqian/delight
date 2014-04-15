//
//  SldGameScene.m
//  Sld
//
//  Created by Wei Li on 14-4-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldGameScene.h"
#import "SldGamePlay.h"
#import "util.h"

@interface SldGameScene()
@property (strong, nonatomic) SldGamePlay *gamePlay;
@end

@implementation SldGameScene

-(id)initWithSize:(CGSize)size {
    if (self = [super initWithSize:size]) {
        NSMutableArray *files = [NSMutableArray arrayWithCapacity:6];
        
        [files addObject:getResFullPath(@"img/a.gif")];
        [files addObject:getResFullPath(@"img/b.gif")];
        [files addObject:getResFullPath(@"img/c.gif")];
        [files addObject:getResFullPath(@"img/x.gif")];
        [files addObject:getResFullPath(@"img/y.gif")];
        [files addObject:getResFullPath(@"img/z.gif")];
        [files addObject:getResFullPath(@"img/1.jpg")];
        [files addObject:getResFullPath(@"img/2.jpg")];
        [files addObject:getResFullPath(@"img/3.jpg")];
        
        self.gamePlay = [SldGamePlay gamePlayWithScene:self files:files];
    }
    return self;
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
