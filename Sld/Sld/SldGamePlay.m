//
//  SldGamePlay.m
//  Sld
//
//  Created by Wei Li on 14-4-6.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldGamePlay.h"
#import "SldSprite.h"

@interface SldGamePlay()
@property (nonatomic) SKScene *scene;
@property (nonatomic) NSArray *files;
@property (nonatomic) NSInteger imgIdx;
@property (nonatomic) NSMutableArray *sprites;
@property (nonatomic) SKNode *sliderParent;
@end

@implementation SldGamePlay

+(instancetype)gamePlayWithScene:(SKScene*)scene files:(NSArray *)files{
    return [[SldGamePlay alloc] initWithScene:scene files:files];
}

-(instancetype)initWithScene:(SKScene*)scene files:(NSArray *)files{
    if (self = [super init]) {
        for (NSString *filepath in files) {
            BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filepath];
            if (!fileExists) {
                lwError("file not exists: path = %@", filepath);
                break;
            }
        }
        
        self.files = files;
        self.scene = scene;
        self.imgIdx = 0;
        self.sprites = [NSMutableArray arrayWithCapacity:3];
        self.sliderParent = [SKNode node];
        [self.scene addChild:self.sliderParent];
        [self loadNextImage];
    }
    
    return self;
}

-(void)loadNextImage {
    if (self.imgIdx >= (NSInteger)[self.files count]-1) {
        lwError("idx >= [self.files count]: self.imgIdx=%d", self.imgIdx);
        return;
    }
    
    if ([self.sprites count] >= 1) {
        self.imgIdx++;
        [self.sprites removeObjectAtIndex:0];
    }
    
    if ([self.sprites count] >= 1 && self.sprites[0] != [NSNull null]) {
        [self.sliderParent removeAllChildren];
        [self.sliderParent addChild:self.sprites[0]];
    }
    while (1) {
        if ([self.sprites count] == 3) {
            break;
        }
        NSUInteger loadImgIdx = self.imgIdx + [self.sprites count];
        if (loadImgIdx > (NSInteger)[self.files count]-1) {
            break;
        }
        NSString *file = self.files[loadImgIdx];
        [self.sprites addObject:[NSNull null]];
        NSUInteger addIdx = [self.sprites count]-1;
        NSUInteger imgIdx = self.imgIdx;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            SldSprite *sprite = [SldSprite spriteWithPath:file];
            dispatch_async(dispatch_get_main_queue(), ^{
                sprite.position = CGPointMake(self.scene.size.width*.5f, self.scene.size.height*.5f);
                NSInteger idx = addIdx - (self.imgIdx-imgIdx);
                if (idx >= 0) {
                    self.sprites[idx] = sprite;
                    if (idx == 0) {
                        [self.sliderParent removeAllChildren];
                        [self.sliderParent addChild:self.sprites[0]];
                    }
                }
                
            });
        });
    }
}

-(void)update {
//    if ([self.sprites count] > 0 && self.sprites[0] != [NSNull null]) {
//        [self.sprites[0] update];
//    }
    NSArray *children = self.sliderParent.children;
    if ([children count]) {
        [children[0] update];
    }
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self loadNextImage];
}

@end
