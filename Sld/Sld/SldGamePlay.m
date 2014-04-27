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
static const uint32_t DEFUALT_SLIDER_NUM = 6;
static const float TRANS_DURATION = .3f;

@interface Slider : SKSpriteNode
@property (nonatomic) NSUInteger idx;
@property (nonatomic) UITouch *touch;
@end

@implementation Slider
@end

@interface SldGamePlay()
@property (nonatomic, weak) SKScene *scene;
@property (nonatomic) NSArray *files;
@property (nonatomic) NSUInteger imgIdx;
@property (nonatomic) NSMutableArray *sprites;
@property (nonatomic) SKNode *sliderParent;
@property (nonatomic) SKNode *nextSliderParent;
@property (nonatomic) BOOL needRotate;
@property (nonatomic) float sliderX0;
@property (nonatomic) float sliderY0;
@property (nonatomic) float sliderH;
@property (nonatomic) FISound *sndTink;
@property (nonatomic) FISound *sndSuccess;
@property (nonatomic) FISound *sndFinish;
@property (nonatomic) BOOL hasFinished;
@property (nonatomic) BOOL touchEnable;
@property (nonatomic) NSMutableArray *dots;
@property (nonatomic) SKSpriteNode *highlightDot;
@end

static float DOT_ALPHA_NORMAL = .5f;
static float DOT_ALPHA_HIGHLIGHT = 1.f;
static float DOT_SCALE_NORMAL = .6f;
static float DOT_SCALE_HIGHLIGHT = .75f;

@implementation SldGamePlay

+(instancetype)gamePlayWithScene:(SKScene*)scene files:(NSArray *)files{
    return [[SldGamePlay alloc] initWithScene:scene files:files];
}

-(void)dealloc {
    
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
        
        [self.scene setUserInteractionEnabled:NO];
        
        self.files = files;
        self.scene = scene;
        self.imgIdx = -1;
        self.sprites = [NSMutableArray arrayWithCapacity:3];
        self.sliderNum = DEFUALT_SLIDER_NUM;
        self.needRotate = NO;
        self.sliderParent = [SKNode node];
        [self.scene addChild:self.sliderParent];
        self.nextSliderParent = [SKNode node];
        [self.scene addChild:self.nextSliderParent];
        self.touchEnable = false;
        [self nextImage];
        
        //audio
        NSError *error = nil;
        FISoundEngine *engine = [FISoundEngine sharedEngine];
        self.sndTink = [engine soundNamed:@"audio/tink.wav" maxPolyphony:4 error:&error];
        NSAssert(self.sndTink, @"self.sndTink: error:%@", [error localizedDescription]);
        self.sndSuccess = [engine soundNamed:@"audio/success.wav" maxPolyphony:1 error:&error];
        NSAssert(self.sndSuccess, @"self.sndSuccess: error:%@", [error localizedDescription]);
        self.sndFinish = [engine soundNamed:@"audio/finish.wav" maxPolyphony:1 error:&error];
        NSAssert(self.sndSuccess, @"self.sndFinish: error:%@", [error localizedDescription]);
        
        //dots
        self.dots = [NSMutableArray arrayWithCapacity:[self.files count]];
        float dx = scene.size.width / [self.files count];
        float dotY = scene.size.height-15.f;
        for (int i = 0; i < [self.files count]; ++i) {
            SKSpriteNode *dot = [SKSpriteNode spriteNodeWithImageNamed:@"ui/dot24.png"];
            [dot setAlpha:DOT_ALPHA_NORMAL];
            [dot setScale:DOT_SCALE_NORMAL];
            [dot setPosition:CGPointMake((i+.5f)*dx, dotY)];
            [dot setZPosition:10.f];
            [scene addChild:dot];
            [self.dots addObject:dot];
        }
        self.highlightDot = [SKSpriteNode spriteNodeWithImageNamed:@"ui/dot24.png"];
        [self.highlightDot setAlpha:DOT_ALPHA_HIGHLIGHT];
        [self.highlightDot setScale:DOT_SCALE_HIGHLIGHT];
        [self.highlightDot setPosition:CGPointMake((0+.5f)*dx, dotY)];
        [self.highlightDot setZPosition:10.f];
        [scene addChild:self.highlightDot];
        [self.dots addObject:self.highlightDot];
    }
    
    return self;
}

-(void)loadImage {
    while (1) {
        if ([self.sprites count] == 3) {
            break;
        }
        //NSUInteger loadImgIdx = self.imgIdx + [self.sprites count];
        NSUInteger loadImgIdx = 0;
        if ([self.sprites count]) {
            id last = [self.sprites lastObject];
            if ([last isKindOfClass:[NSNumber class]]) {
                loadImgIdx = [(NSNumber*)last unsignedIntegerValue]+1;
            } else {
                loadImgIdx = ((SldSprite*)last).index+1;
            }
        }
        if (loadImgIdx > (NSInteger)[self.files count]-1) {
            break;
        }
        NSString *file = self.files[loadImgIdx];
        [self.sprites addObject:[NSNumber numberWithUnsignedInteger:loadImgIdx]];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            SldSprite *sprite = [SldSprite spriteWithPath:file index:loadImgIdx];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSInteger idx = sprite.index;
                if (idx >= 0) {
                    for (int i = 0; i < [self.sprites count]; i++) {
                        NSObject *v = self.sprites[i];
                        if ([v isKindOfClass:[NSNumber class]] && [(NSNumber*)v unsignedIntegerValue] == idx) {
                            self.sprites[i] = sprite;
                            if (idx == 0 || (i == 1 && self.imgIdx == idx)) {
                                [self setupSprite:sprite];
                            }
                        }
                    }
                }
            });
        });
    }
}

- (void)next {
    if (self.hasFinished) {
        [self nextImage];
    }
}

-(void)nextImage {
    self.touchEnable = NO;
    self.imgIdx++;
    
    //dots
    if (self.imgIdx > 0) {
        float dx = self.scene.size.width / [self.files count];
        SKAction *action = [SKAction moveToX:(self.imgIdx+.5f)*dx duration:.2f];
        action.timingMode = SKActionTimingEaseInEaseOut;
        [self.highlightDot runAction:action];
    }
    
    //
    if (self.imgIdx >= (NSInteger)[self.files count]) {
        lwError("idx >= [self.files count]: self.imgIdx=%d", self.imgIdx);
        return;
    }
    
    self.hasFinished = NO;
    
//    if ([self.sprites count] >= 1) {
//        self.imgIdx++;
//    }
    
    
    if ([self.sprites count] >= 2 && [self.sprites[1] isKindOfClass:[SldSprite class]]) {
        [self setupSprite:self.sprites[1]];
    }
    
    [self loadImage];
}

- (NSMutableArray*)shuffle:(NSUInteger)num {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:num];
    for (NSUInteger i = 0; i < num; ++i) {
        array[i] = [NSNumber numberWithUnsignedInteger:i];
    }
    NSUInteger count = [array count];
    for (NSUInteger i = 0; i < count; ++i) {
        // Select a random element between i and end of array to swap with.
        NSInteger nElements = count - i;
        NSInteger n = arc4random_uniform(nElements) + i;
        [array exchangeObjectAtIndex:i withObjectAtIndex:n];
    }
    for (NSUInteger i = 1; i < count; ++i) {
        if ([array[i-1] integerValue] + 1 == [array[i] integerValue]) {
            [array exchangeObjectAtIndex:i withObjectAtIndex:i-1];
        }
    }
    return array;
}

-(void)setupSprite:(SldSprite*)sprite {
    float screenW = self.scene.frame.size.width;
    float screenH = self.scene.frame.size.height;
    float texW = sprite.frame.size.width;
    float texH = sprite.frame.size.height;
    
    if (texW > texH) {
        self.needRotate = YES;
    } else {
        self.needRotate = NO;
    }
    
    __weak SKNode *parent = self.nextSliderParent;
    if (self.imgIdx == 0) {
        parent = self.sliderParent;
    }
    //[parent removeAllChildren];
    
    float refRatios[] = {
        9.f/16.f,
        2.f/3.f,
        3.f/4.f,
    };
    
    //shuffle sliders
    NSMutableArray* idxs = [self shuffle:self.sliderNum];
    
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
            NSUInteger idx = [idxs[i] unsignedIntegerValue];
            float uvY = uvY0+uvh*(self.sliderNum-idx-1);
            
            //SKTexture *texture = [SKTexture textureWithRect:CGRectMake(uvX0/texW, uvY/texH, uvW/texW, uvh/texH) inTexture:sprite.texture];
            SKTexture *texture = [SKTexture textureWithRect:CGRectMake(uvY/texH, uvX0/texW, uvh/texH, uvW/texW) inTexture:sprite.texture];
            Slider *slider = [Slider spriteNodeWithTexture:texture size:CGSizeMake(sliderH, sliderW)];
            slider.idx = idx;
            slider.touch = nil;
            float y = self.sliderY0+i*sliderH;
            [slider setPosition:CGPointMake(self.sliderX0, y)];
            [slider setZRotation:-M_PI_2];
            [parent addChild:slider];
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
            NSUInteger idx = [idxs[i] unsignedIntegerValue];
            float uvY = uvY0+uvh*idx;
            
            SKTexture *texture = [SKTexture textureWithRect:CGRectMake(uvX0/texW, uvY/texH, uvW/texW, uvh/texH) inTexture:sprite.texture];
            Slider *slider = [Slider spriteNodeWithTexture:texture size:CGSizeMake(sliderW, sliderH)];
            slider.idx = idx;
            slider.touch = nil;
            float y = self.sliderY0+i*sliderH;
            [slider setPosition:CGPointMake(self.sliderX0, y)];
            [parent addChild:slider];
        }
    }
    
    //transition
    if (parent == self.nextSliderParent) {
        if (self.needRotate) {
            [parent setPosition:CGPointMake(-screenH, 0)];
        } else {
            [parent setPosition:CGPointMake(0, screenW)];
        }
        
        [parent setAlpha:0];
        
        SKAction *action = [SKAction customActionWithDuration:TRANS_DURATION actionBlock:^(SKNode *node, CGFloat elapsedTime) {
            float t = QuarticEaseOut(elapsedTime/TRANS_DURATION);
            if (self.needRotate) {
                [node setPosition:CGPointMake(0, -(screenH + t*(-screenH)))];
            } else {
                [node setPosition:CGPointMake(screenW + t*(-screenW), 0)];
            }
            [node setAlpha:t];
        }];
        
        [parent runAction:action completion:^{
            SKNode *tmp = self.sliderParent;
            self.sliderParent = self.nextSliderParent;
            self.nextSliderParent = tmp;
            
            [self.sliderParent setZPosition:0.f];
            [self.nextSliderParent setZPosition:1.f];
            
            [self.nextSliderParent removeAllChildren];
            [self.sprites removeObjectAtIndex:0];
            [self loadImage];
            self.touchEnable = YES;
        }];
    } else {
        self.touchEnable = YES;
        [parent setAlpha:0];
        float dur = 1.f;
        SKAction *action = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
            CGFloat t = elapsedTime/dur;
            t = CubicEaseOut(t);
            [node setAlpha:t];
        }];
        [parent runAction:action completion:^{
            usleep(100000);
            [self.scene setUserInteractionEnabled:YES];
        }];
    }
    [self.delegate onNextImageWithRotate:self.needRotate];
}

-(void)update {
//    if ([self.sprites count] > 0 && self.sprites[0] != [NSNull null]) {
//        [self.sprites[0] update];
//    }
    if ([self.sprites count]) {
        SldSprite *sldSpt = self.sprites[0];
        if ([sldSpt isKindOfClass:[SldSprite class]] && [sldSpt update]) {
            for (SKSpriteNode *sprite in self.sliderParent.children) {
                sprite.texture = [SKTexture textureWithRect:sprite.texture.textureRect inTexture:sldSpt.texture];
            }
            //sprite.texture = [SKTexture textureWithRect:CGRectMake(0, 0, .5, .5) inTexture:sprite.texture];
        }
        
    }
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!self.touchEnable) {
        return;
    }
    
    UITouch *touch = [touches anyObject];
    
    if (self.hasFinished) {
        [self nextImage];
        return;
    }
    
    //fixme
    CGPoint ptView = [touch locationInView:self.scene.view];
    if (ptView.x < 30 && ptView.y < 30) {
        [self nextImage];
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
    if (!self.touchEnable) {
        return;
    }
    
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
        [self.sndTink play];
    }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!self.touchEnable) {
        return;
    }
    
    UITouch *touch = [touches anyObject];
    int i = 0;
    for (Slider *slider in self.sliderParent.children) {
        if (slider.touch == touch) {
            slider.touch = nil;
            
            float y = self.sliderY0 + i * self.sliderH;
            SKAction *moveTo = [SKAction moveTo:CGPointMake(self.sliderX0, y) duration:MOVE_DURATION];
            moveTo.timingMode = SKActionTimingEaseOut;
            //[slider removeAllActions];
            [slider runAction:moveTo completion:^{
                slider.zPosition = 0.f;
            }];
            
            //check finished
            NSUInteger idx = 0;
            NSArray *sliders = self.sliderParent.children;
            for (Slider *slider in sliders) {
                if (slider.idx != idx) {
                    break;
                }
                idx++;
            }
            if (idx == [self.sliderParent.children count]) {
                self.hasFinished = YES;
                
                //get next image rotation
                BOOL nextRotate = NO;
                if ([self.sprites count] >= 2 && [self.sprites[1] isKindOfClass:[SldSprite class]]) {
                    SldSprite *spt = self.sprites[1];
                    CGSize size = spt.texture.size;
                    if (size.width > size.height) {
                        nextRotate = YES;
                    }
                }
                
                if (self.imgIdx == [self.files count]-1) {
                    [self.sndFinish play];
                    [self.delegate onPackFinish:nextRotate];
                } else {
                    [self.sndSuccess play];
                    [self.delegate onImageFinish:nextRotate];
                }
                
            }
            break;
        }
        i++;
    }
}



@end
