//
//  SldGamePlay.m
//  Sld
//
//  Created by Wei Li on 14-4-6.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldGamePlay.h"
#import "SldSprite.h"

static const float MOVE_DURATION = .1f;
static const uint32_t DEFUALT_SLIDER_NUM = 7;

@interface Slider : SKSpriteNode
@property (nonatomic) NSUInteger idx;
@property (nonatomic) UITouch *touch;
@end

@implementation Slider
@end

@interface SldGamePlay()
@property (nonatomic) SKScene *scene;
@property (nonatomic) NSArray *files;
@property (nonatomic) NSUInteger imgIdx;
@property (nonatomic) NSMutableArray *sprites;
@property (nonatomic) SKNode *sliderParent;
@property (nonatomic) BOOL needRotate;
@property (nonatomic) float sliderX0;
@property (nonatomic) float sliderY0;
@property (nonatomic) float sliderH;
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
        self.sliderNum = DEFUALT_SLIDER_NUM;
        self.needRotate = NO;
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
        [self setupSprite:self.sprites[0]];
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
                        [self setupSprite:self.sprites[0]];
                    }
                }
                
            });
        });
    }
}

-(void)setupSprite:(SldSprite*)sprite {
    float screenW = self.scene.frame.size.width;
    float screenH = self.scene.frame.size.height;
    float texW = sprite.frame.size.width;
    float texH = sprite.frame.size.height;
    
    if (texW > texH) {
        self.needRotate = YES;
    }
    
    [self.sliderParent removeAllChildren];
    
    float refRatios[] = {
        9.f/16.f,
        2.f/3.f,
        3.f/4.f,
    };
    
    if (self.needRotate) {
        float tmp = texW;
        texW = texH;
        texH = tmp;
        
        float texRatio = texW/texH;
        float visRatio = screenW/screenH;
        texRatio += 0.001;
        float targetRatio = visRatio;
        for (int i = 0; i < sizeof(refRatios)/sizeof(refRatios[0]); ++i) {
            if (refRatios[i] > visRatio) {
                if (texRatio >= refRatios[i]) {
                    targetRatio = refRatios[i];
                }
            }
        }
        float targetW = screenW;
        float targetH = screenW/targetRatio;
        
        //sliders
        float sliderW = screenW;
        float sliderH = targetH / self.sliderNum;
        self.sliderH = sliderH;
        self.sliderX0 = screenW*.5;
        self.sliderY0 = screenH*.5 - targetH*.5 + sliderH*.5;
        float y = self.sliderY0;
        
        //uv
        float uvW = 0;
        float uvH = 0;
        float uvX0 = 0;
        float uvY0 = 0;
        if (texW/texH <= targetW/targetH) { //slim
            uvW = texW;
            uvH = uvW * (targetH/targetW);
            uvY0 = (texH - uvH) * .5f;
        } else {    //fat
            uvH = texH;
            uvW = uvH * (targetW/targetH);
            uvX0 = (texW - uvW) * .5f;
        }
        float uvh = uvH / self.sliderNum;
        
        //
        for (NSUInteger i = 0; i < self.sliderNum; i++) {
            float uvY = uvY0+uvh*(self.sliderNum-i-1);
            
            //SKTexture *texture = [SKTexture textureWithRect:CGRectMake(uvX0/texW, uvY/texH, uvW/texW, uvh/texH) inTexture:sprite.texture];
            SKTexture *texture = [SKTexture textureWithRect:CGRectMake(uvY/texH, uvX0/texW, uvh/texH, uvW/texW) inTexture:sprite.texture];
            Slider *slider = [Slider spriteNodeWithTexture:texture size:CGSizeMake(sliderH, sliderW)];
            slider.idx = 0;
            slider.touch = nil;
            [slider setPosition:CGPointMake(self.sliderX0, y)];
            [slider setZRotation:-M_PI_2];
            [self.sliderParent addChild:slider];
            y += sliderH;
        }
    } else {
        float texRatio = texW/texH;
        float visRatio = screenW/screenH;
        texRatio += 0.001;
        float targetRatio = visRatio;
        for (int i = 0; i < sizeof(refRatios)/sizeof(refRatios[0]); ++i) {
            if (refRatios[i] > visRatio) {
                if (texRatio >= refRatios[i]) {
                    targetRatio = refRatios[i];
                }
            }
        }
        float targetW = screenW;
        float targetH = screenW/targetRatio;
        
        //sliders
        float sliderW = screenW;
        float sliderH = targetH / self.sliderNum;
        self.sliderH = sliderH;
        self.sliderX0 = screenW*.5;
        self.sliderY0 = screenH*.5 - targetH*.5 + sliderH*.5;
        float y = self.sliderY0;
        
        //uv
        float uvW = 0;
        float uvH = 0;
        float uvX0 = 0;
        float uvY0 = 0;
        if (texW/texH <= targetW/targetH) { //slim
            uvW = texW;
            uvH = uvW * (targetH/targetW);
            uvY0 = (texH - uvH) * .5f;
        } else {    //fat
            uvH = texH;
            uvW = uvH * (targetW/targetH);
            uvX0 = (texW - uvW) * .5f;
        }
        float uvh = uvH / self.sliderNum;
        
        //
        for (NSUInteger i = 0; i < self.sliderNum; i++) {
            float uvY = uvY0+uvh*(self.sliderNum-i-1);
            
            SKTexture *texture = [SKTexture textureWithRect:CGRectMake(uvX0/texW, uvY/texH, uvW/texW, uvh/texH) inTexture:sprite.texture];
            Slider *slider = [Slider spriteNodeWithTexture:texture size:CGSizeMake(sliderW, sliderH)];
            slider.idx = 0;
            slider.touch = nil;
            [slider setPosition:CGPointMake(self.sliderX0, y)];
            [self.sliderParent addChild:slider];
            y += sliderH;
        }
    }
    
    
    //[self.sliderParent addChild:sprite];
}

-(void)update {
//    if ([self.sprites count] > 0 && self.sprites[0] != [NSNull null]) {
//        [self.sprites[0] update];
//    }
    if ([self.sprites count]) {
        SldSprite *sldSpt = self.sprites[0];
        if (self.sprites[0] != [NSNull null] && [sldSpt update]) {
            for (SKSpriteNode *sprite in self.sliderParent.children) {
                sprite.texture = [SKTexture textureWithRect:sprite.texture.textureRect inTexture:sldSpt.texture];
            }
            //sprite.texture = [SKTexture textureWithRect:CGRectMake(0, 0, .5, .5) inTexture:sprite.texture];
        }
        
    }
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    //[self loadNextImage];
    UITouch *touch = [touches anyObject];
    
    CGPoint ptView = [touch locationInView:self.scene.view];
    if (ptView.x < 30 && ptView.y < 30) {
        [self loadNextImage];
        return;
    }
    
    CGPoint pt = [touch locationInNode: self.scene];
    SKNode *node = [self.scene nodeAtPoint:pt];
    if (node && [node isKindOfClass:[Slider class]]) {
        Slider *slider = (Slider*)node;
        [slider removeAllActions];
        slider.touch = touch;
        slider.zPosition = 1.f;
    }
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    
    int i = 0;
    BOOL resort = NO;
    for (Slider *slider in self.sliderParent.children) {
        if (slider.touch == touch) {
            CGPoint pt = [touch locationInNode:self.scene];
            CGPoint ptPrev = [touch previousLocationInNode:self.scene];
            CGPoint pos = slider.position;
            float y = pos.y+pt.y-ptPrev.y;
            [slider setPosition:CGPointMake(pos.x, y)];
            
            //resort?
            int toI = (int)(roundf((y-self.sliderY0)/self.sliderH));
            toI = MAX(0, MIN((int)(self.sliderNum-1), toI));
            if (toI != i) {
                resort = true;
                [slider removeFromParent];
                [self.sliderParent insertChild:slider atIndex:toI];
            }
            
            break;
        }
        ++i;
    }
    
    if (resort) {
        int i = 0;
        for (Slider *slider in self.sliderParent.children) {
            float y = self.sliderY0 + i * self.sliderH;
            if (!slider.touch && slider.position.y != y) {
                SKAction *moveTo = [SKAction moveTo:CGPointMake(self.sliderX0, y) duration:MOVE_DURATION];
                moveTo.timingMode = SKActionTimingEaseOut;
                [slider removeAllActions];
                [slider runAction:moveTo];
            }
            i++;
        }
    }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    int i = 0;
    for (Slider *slider in self.sliderParent.children) {
        if (slider.touch == touch) {
            slider.touch = nil;
            
            float y = self.sliderY0 + i * self.sliderH;
            SKAction *moveTo = [SKAction moveTo:CGPointMake(self.sliderX0, y) duration:MOVE_DURATION];
            moveTo.timingMode = SKActionTimingEaseOut;
            [slider removeAllActions];
            [slider runAction:moveTo completion:^{
                slider.zPosition = 0.f;
            }];
            break;
        }
        i++;
    }
}

@end
