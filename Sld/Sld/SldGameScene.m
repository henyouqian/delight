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
#import "SldSprite.h"
#import "SldStreamPlayer.h"
#import "SldHttpSession.h"
#import "SldGameData.h"
#import "SldDb.h"

@interface Slider : SKSpriteNode
@property (nonatomic) NSUInteger idx;
@property (nonatomic) UITouch *touch;
@end

@implementation Slider
@end

@interface SldGameScene()
@property (nonatomic) NSMutableArray *uiRotateNodes;
@property (nonatomic) SldButton *btnExit;
@property (nonatomic) SldButton *btnYes;
@property (nonatomic) SldButton *btnNo;
@property (nonatomic) SldButton *btnNext;

@property (nonatomic) uint32_t sliderNum;
@property (nonatomic) NSMutableArray *files;
@property (nonatomic) NSInteger imgIdx;
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
@property (nonatomic) BOOL isLoaded;
@property (nonatomic) NSMutableArray *dots;
@property (nonatomic) SKSpriteNode *highlightDot;
@property (nonatomic) SKSpriteNode *curtainTop;
@property (nonatomic) SKSpriteNode *curtainBottom;
@property (nonatomic) SKSpriteNode *curtainBelt;
@property (nonatomic) SKLabelNode *curtainLabel;
@property (nonatomic) BOOL inCurtain;
@property (nonatomic) SKLabelNode *timerLabel;
@property (nonatomic) BOOL packHasFinished;
@property (nonatomic) SKSpriteNode *lastImageBlurSprite;
@property (nonatomic) SKSpriteNode *lastImageCover;


@property (nonatomic) float targetW;
@property (nonatomic) float targetH;

@end

static float BUTTON_ALPHA = .7f;
static CGPoint BUTTON_POS1 = {40, 40};
static CGPoint BUTTON_POS2 = {95, 40};
static CGPoint BUTTON_POS3 = {320-40, 40};
static CGPoint BUTTON_POS_HIDE = {-10000, 40};
static float BUTTON_FONT_SIZE = 18;
static NSString* BUTTON_BG = @"ui/btnBgWhite45.png";

static const float DOT_ALPHA_NORMAL = .5f;
static const float DOT_ALPHA_HIGHLIGHT = 1.f;
static const float DOT_SCALE_NORMAL = .6f;
static const float DOT_SCALE_HIGHLIGHT = .75f;
static const float MOVE_DURATION = .1f;
static const uint32_t DEFUALT_SLIDER_NUM = 2;
static const float TRANS_DURATION = .3f;

UIColor *BUTTON_COLOR_RED = nil;
UIColor *BUTTON_COLOR_GREEN = nil;

static NSUInteger const LOCAL_SCORE_COUNT_LIMIT = 9;


@implementation SldGameScene

NSDate *_gameBeginTime;


+ (instancetype)sceneWithSize:(CGSize)size controller:(SldGameController*)controller {
    SldGameScene* inst = [[SldGameScene alloc] initWithSize:size controller:controller];
    return inst;
}

- (instancetype)initWithSize:(CGSize)size controller:(SldGameController*)controller {
    if (self = [super initWithSize:size]) {
        _gameController = controller;
        
        SldGameData *gameData = [SldGameData getInstance];
        
        NSMutableArray *files = [NSMutableArray arrayWithCapacity:[gameData.packInfo.images count]];
        for (NSString *img in gameData.packInfo.images) {
            [files addObject:makeImagePath(img)];
        }
        
        _imgIdx = -1;
        _sprites = [NSMutableArray arrayWithCapacity:3];
        _sliderNum = DEFUALT_SLIDER_NUM;
        _needRotate = NO;
        _sliderParent = [SKNode node];
        [self.scene addChild:self.sliderParent];
        _nextSliderParent = [SKNode node];
        [self.scene addChild:self.nextSliderParent];
        _isLoaded = false;
        
        
        __weak typeof(self) weakSelf = self;
        
        UIColor *fontColorDark = makeUIColor(30, 30, 30, 255);
        BUTTON_COLOR_RED = makeUIColor(255, 59, 48, 255);
        BUTTON_COLOR_GREEN = makeUIColor(76, 217, 100, 255);
        
        float buttonZ = 10.f;
        
        //exit button
        self.btnExit = [SldButton buttonWithImageNamed:BUTTON_BG];
        [self.btnExit setLabelWithText:@"Exit" color:fontColorDark fontSize:BUTTON_FONT_SIZE];
        [self.btnExit setPosition:BUTTON_POS1];
        [self.btnExit setAlpha:BUTTON_ALPHA];
        self.btnExit.zPosition = buttonZ;
        self.btnExit.onClick = ^{
            [weakSelf onExit];
        };
        [self addChild:self.btnExit];
        
        self.uiRotateNodes = [NSMutableArray arrayWithCapacity:10];
        [self.uiRotateNodes addObject:self.btnExit];
        
        //yes button
        self.btnYes = [SldButton buttonWithImageNamed:BUTTON_BG];
        [self.btnYes setLabelWithText:@"Yes" color:[UIColor whiteColor] fontSize:BUTTON_FONT_SIZE];
        [self.btnYes setPosition:BUTTON_POS_HIDE];
        [self.btnYes setBackgroundColor:BUTTON_COLOR_RED];
        [self.btnYes setAlpha:0.f];
        self.btnYes.zPosition = buttonZ;
        self.btnYes.onClick = ^{
            [weakSelf onBackYes];
        };
        self.btnYes.userInteractionEnabled = NO;
        [self addChild:self.btnYes];
        [self.uiRotateNodes addObject:self.btnYes];
        
        //no button
        self.btnNo = [SldButton buttonWithImageNamed:BUTTON_BG];
        [self.btnNo setLabelWithText:@"No" color:fontColorDark fontSize:BUTTON_FONT_SIZE];
        [self.btnNo setPosition:BUTTON_POS_HIDE];
        [self.btnNo setAlpha:0.f];
        self.btnNo.zPosition = buttonZ;
        self.btnNo.onClick = ^{
            [weakSelf onBackNo];
        };
        self.btnNo.userInteractionEnabled = NO;
        [self addChild:self.btnNo];
        [self.uiRotateNodes addObject:self.btnNo];
        
        //next button
        self.btnNext = [SldButton buttonWithImageNamed:BUTTON_BG];
        [self.btnNext setLabelWithText:@"Next" color:[UIColor whiteColor] fontSize:BUTTON_FONT_SIZE];
        [self.btnNext setPosition:BUTTON_POS_HIDE];
        [self.btnNext setBackgroundColor:BUTTON_COLOR_GREEN];
        [self.btnNext setAlpha:0.f];
        self.btnNext.zPosition = buttonZ;
        self.btnNext.onClick = ^{
            [weakSelf next];
        };
        [self addChild:self.btnNext];
        [self.uiRotateNodes addObject:self.btnNext];
        
        //
        [self.scene setUserInteractionEnabled:NO];
        
        //shuffle files
        NSUInteger fileCount = [files count];
        NSMutableArray* idxs = [self shuffle:fileCount more:NO];
        self.files = [NSMutableArray arrayWithCapacity:fileCount];
        for (int i = 0; i < fileCount; ++i) {
            [self.files addObject:files[[idxs[i] unsignedIntegerValue]]];
        }
        
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
        float dx = self.size.width / [self.files count];
        float dotY = self.size.height-15.f;
        for (int i = 0; i < [self.files count]; ++i) {
            SKSpriteNode *dot = [SKSpriteNode spriteNodeWithImageNamed:@"ui/dot24.png"];
            [dot setAlpha:DOT_ALPHA_NORMAL];
            [dot setScale:DOT_SCALE_NORMAL];
            [dot setPosition:CGPointMake((i+.5f)*dx, dotY)];
            [dot setZPosition:10.f];
            [self addChild:dot];
            [self.dots addObject:dot];
        }
        self.highlightDot = [SKSpriteNode spriteNodeWithImageNamed:@"ui/dot24.png"];
        [self.highlightDot setAlpha:DOT_ALPHA_HIGHLIGHT];
        [self.highlightDot setScale:DOT_SCALE_HIGHLIGHT];
        [self.highlightDot setPosition:CGPointMake((0+.5f)*dx, dotY)];
        [self.highlightDot setZPosition:10.f];
        [self addChild:self.highlightDot];
        [self.dots addObject:self.highlightDot];
        _packHasFinished = NO;
        
        //curtain
        self.inCurtain = YES;
        //UIColor *colorCtBg = makeUIColor(130, 124, 105, 255);
        UIColor *colorCtBg = makeUIColor(125, 120, 105, 255);
        UIColor *colorCtBelt = makeUIColor(147, 40, 17, 255);
        UIColor *colorCtText = makeUIColor(222, 222, 222, 255);
        
        self.curtainTop = [SKSpriteNode spriteNodeWithColor:colorCtBg size:self.size];
        [self.curtainTop setAnchorPoint:CGPointMake(0.f, 0.f)];
        [self.curtainTop setPosition:CGPointMake(0.f, self.size.height*.5f)];
        [self addChild:self.curtainTop];
        
        self.curtainBottom = [SKSpriteNode spriteNodeWithColor:colorCtBg size:self.size];
        [self.curtainBottom setAnchorPoint:CGPointMake(0.f, 1.f)];
        [self.curtainBottom setPosition:CGPointMake(0.f, self.size.height*.5f)];
        [self addChild:self.curtainBottom];
        
        self.curtainLabel = [SKLabelNode labelNodeWithFontNamed:@"HelveticaNeue"];
        [self.curtainLabel setFontColor:colorCtText];
        [self.curtainLabel setText:@"TAP TO START"];
        [self.curtainLabel setFontSize:22];
        [self.curtainLabel setVerticalAlignmentMode:SKLabelVerticalAlignmentModeCenter];
        //[self.curtainLabel setAlpha:0.f];
        self.curtainLabel.yScale = 0.f;
        
        self.curtainBelt = [SKSpriteNode spriteNodeWithColor:colorCtBelt size:CGSizeMake(self.size.width, 30.f)];
        [self.curtainBelt setAnchorPoint:CGPointMake(.5f, .5f)];
        [self.curtainBelt setPosition:CGPointMake(self.size.width*.5f, self.size.height*.5f)];
        [self addChild:self.curtainBelt];
        [self.curtainBelt addChild:self.curtainLabel];
        
        //load image
        [self nextImage];
        
        //timer
//        self.timerLabel = [SKLabelNode labelNodeWithFontNamed:@"HelveticaNeue"];
//        [self.timerLabel setFontColor:[UIColor whiteColor]];
//        [self.timerLabel setFontSize:30];
//        [self.timerLabel setVerticalAlignmentMode:SKLabelVerticalAlignmentModeTop];
//        [self.timerLabel setPosition:CGPointMake(self.size.width*.5f, self.size.height-30.f)];
//        [self.timerLabel setText:@"00:35.127"];
//        [self.timerLabel setZPosition:1.f];
//        [self addChild:self.timerLabel];
//        //timer shadow
//        SKLabelNode *timerShadow = [SKLabelNode labelNodeWithFontNamed:@"HelveticaNeue"];
//        [self.timerLabel setFontColor:[UIColor whiteColor]];
//        [self.timerLabel setFontSize:30];
//        [self.timerLabel setVerticalAlignmentMode:SKLabelVerticalAlignmentModeTop];
//        [self.timerLabel setPosition:CGPointMake(self.size.width*.5f, self.size.height-30.f)];
//        [self.timerLabel setText:@"00:35.127"];
//        [self.timerLabel setZPosition:1.f];
        
    }
    return self;
}

- (void)loadLastBlurSprite {
    //effect node
    SKEffectNode *effectNode = [SKEffectNode node];
    [effectNode setShouldEnableEffects:YES];
    CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur" keysAndValues:@"inputRadius", @10.0f, nil];
    [effectNode setFilter:blur];
    
    UIImage *image = [UIImage imageWithContentsOfFile:[_files lastObject]];
    SKTexture *texture = [SKTexture textureWithImage:image];
    SKSpriteNode *lastImageSpt = [SKSpriteNode spriteNodeWithTexture:texture];
    [effectNode addChild:lastImageSpt];
    
    texture = [self.view textureFromNode:effectNode];
    _lastImageBlurSprite = [SKSpriteNode spriteNodeWithTexture:texture];
    
    _lastImageBlurSprite.zPosition = 2.f;
    
    //
    float texW = [_lastImageBlurSprite.texture size].width;
    float texH = [_lastImageBlurSprite.texture size].height;
    _lastImageBlurSprite.anchorPoint = CGPointMake(.5f, .5f);
    _lastImageBlurSprite.position = CGPointMake(self.view.frame.size.width*.5f, self.view.frame.size.height*.5f);
//    float scale = self.view.frame.size.width/texW;
//    scale = MAX(self.view.frame.size.height/texH, scale);
    if (texW > texH) {
//        scale = self.view.frame.size.height/texW;
//        scale = MAX(self.view.frame.size.width/texH, scale);
        _lastImageBlurSprite.zRotation = -M_PI_2;
    }
//    [_lastImageBlurSprite setScale:scale*1.2f];
    
    //cover
    _lastImageCover = [SKSpriteNode spriteNodeWithColor:makeUIColor(100, 100, 100, 128) size:self.view.frame.size];
    _lastImageCover.anchorPoint = CGPointZero;
    _lastImageCover.zPosition = 2.f;
}

- (void)dealloc {
    
}

static float lerpf(float a, float b, float t) {
    return a + (b - a) * t;
}

- (void)onExit {
    if (_packHasFinished) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    
    float dur = .2f;
    
    //btnYes
    self.btnYes.userInteractionEnabled = NO;
    SKAction *action = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
        float t = QuarticEaseOut(elapsedTime/dur);
        [node setAlpha:lerpf(0.f, BUTTON_ALPHA, t)];
        [node setPosition:CGPointMake(lerpf(BUTTON_POS1.x, BUTTON_POS2.x, t), BUTTON_POS2.y)];
    }];
    [self.btnYes runAction:action completion:^{
        self.btnYes.userInteractionEnabled = YES;
    }];
    
    //btnNo
    self.btnNo.userInteractionEnabled = NO;
    self.btnNo.position = BUTTON_POS1;
    action = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
        float t = QuarticEaseOut(elapsedTime/dur);
        [node setAlpha:lerpf(0.f, BUTTON_ALPHA, t)];
    }];
    [self.btnNo runAction:action completion:^{
        self.btnNo.userInteractionEnabled = YES;
    }];
    
    //btnExit
    self.btnExit.userInteractionEnabled = NO;
    action = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
        float t = QuarticEaseOut(elapsedTime/dur);
        [node setAlpha:lerpf(BUTTON_ALPHA, 0.f, t)];
    }];
    [self.btnExit runAction:action completion:^{
        [self.btnExit setPosition:BUTTON_POS_HIDE];
    }];
}

- (void)onBackYes {
    if (_gameController.gameMode == MATCH) {
        RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:@"No" action:nil];
        
        RIButtonItem *yesItem = [RIButtonItem itemWithLabel:@"Yes, Exit!" action:^{
            [self.navigationController popViewControllerAnimated:YES];
        }];
        
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Exit this match?"
                                                            message:nil
                                                   cancelButtonItem:cancelItem
                                                   otherButtonItems:yesItem, nil];
        [alertView show];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)onBackNo {
    float dur = .2f;
    
    //btnYes
    self.btnYes.userInteractionEnabled = NO;
    SKAction *action = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
        float t = QuarticEaseOut(elapsedTime/dur);
        [node setAlpha:lerpf(BUTTON_ALPHA, 0.f, t)];
        [node setPosition:CGPointMake(lerpf(BUTTON_POS2.x, BUTTON_POS1.x, t), BUTTON_POS1.y)];
    }];
    [self.btnYes runAction:action completion:^{
        self.btnYes.position = BUTTON_POS_HIDE;
    }];
    
    //btnNo
    self.btnNo.userInteractionEnabled = NO;
    action = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
        float t = QuarticEaseOut(elapsedTime/dur);
        [node setAlpha:lerpf(BUTTON_ALPHA, 0.f, t)];
    }];
    [self.btnNo runAction:action completion:^{
        self.btnNo.position = BUTTON_POS_HIDE;
    }];
    
    //btnExit
    self.btnExit.userInteractionEnabled = NO;
    [self.btnExit setPosition:BUTTON_POS1];
    action = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
        float t = QuarticEaseOut(elapsedTime/dur);
        [node setAlpha:lerpf(0.f, BUTTON_ALPHA, t)];
    }];
    [self.btnExit runAction:action completion:^{
        self.btnExit.userInteractionEnabled = YES;
    }];
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
    if (self.imgIdx >= (NSInteger)[self.files count]-1) {
        lwError("idx >= [self.files count]-1: self.imgIdx=%d", (int)self.imgIdx);
        return;
    }
    
    //
    _isLoaded = NO;
    self.imgIdx++;
    
    //dots
    if (self.imgIdx > 0) {
        float dx = self.scene.size.width / [self.files count];
        SKAction *action = [SKAction moveToX:(self.imgIdx+.5f)*dx duration:.2f];
        action.timingMode = SKActionTimingEaseInEaseOut;
        [self.highlightDot runAction:action];
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

- (NSMutableArray*)shuffle:(NSUInteger)num more:(BOOL)more {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:num];
    for (NSUInteger i = 0; i < num; ++i) {
        array[i] = [NSNumber numberWithUnsignedInteger:i];
    }
    NSUInteger count = [array count];
    for (NSUInteger i = 0; i < count; ++i) {
        // Select a random element between i and end of array to swap with.
        NSInteger nElements = count - i;
        NSInteger n = arc4random_uniform((u_int32_t)nElements) + i;
        [array exchangeObjectAtIndex:i withObjectAtIndex:n];
    }
    if (more) {
        for (NSUInteger i = 1; i < count; ++i) {
            if ([array[i-1] integerValue] + 1 == [array[i] integerValue]) {
                [array exchangeObjectAtIndex:i withObjectAtIndex:i-1];
            }
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
    NSMutableArray* idxs = [self shuffle:self.sliderNum more:YES];
    
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
        _targetW = targetW;
        _targetH = targetH;
        
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
        _targetW = targetW;
        _targetH = targetH;
        
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
            _isLoaded = YES;
        }];
    } else { //first image loaded
        [self loadLastBlurSprite];
        //[parent setAlpha:0];
        float dur = .6f;
        SKAction *action = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
            CGFloat t = elapsedTime/dur;
            t = CubicEaseOut(t);
            //[node setAlpha:t];
        }];
        [parent runAction:action completion:^{
            usleep(100000);
            [self.scene setUserInteractionEnabled:YES];
            
            float dur = .4f;
            SKAction *action = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
                float t = QuarticEaseOut(elapsedTime/dur);
                [node setYScale:lerpf(0.f, 1.f, t)];
                [node setXScale:2.0-lerpf(0.f, 1.f, t)];
            }];
            [self.curtainLabel runAction:action];
            _isLoaded = YES;
        }];
    }
    [self onNextImageWithRotate:self.needRotate];
}

- (void)update:(CFTimeInterval)currentTime {
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

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!_isLoaded) {
        return;
    }
    
    UITouch *touch = [touches anyObject];
    
    if (self.hasFinished) {
        [self nextImage];
        return;
    }
    
    //hit test
    CGPoint pt = [touch locationInNode: self.scene];
    SKNode *node = [self.scene nodeAtPoint:pt];
    
    //curtain
    float dur = .3f;
    if (self.inCurtain /*&& (node == self.curtainTop || node == self.curtainBottom || node == self.curtainBelt || node == self.curtainLabel)*/) {
        self.inCurtain = NO;
        SKAction *left = [SKAction moveToX:-self.size.width*2.5f duration:.8f];
        left.timingMode = SKActionTimingEaseOut;
        [self.curtainBelt runAction:left completion:^{
            SKAction *up = [SKAction moveToY:self.size.height duration:dur];
            up.timingMode = SKActionTimingEaseIn;
            [self.curtainTop runAction:up];
            
            SKAction *down = [SKAction moveToY:0.f duration:dur];
            down.timingMode = SKActionTimingEaseIn;
            [self.curtainBottom runAction:down completion:^{
                //game begin
                _gameBeginTime = [NSDate dateWithTimeIntervalSinceNow:0];
            }];
        }];
        
//        SldStreamPlayer *player = [SldStreamPlayer defautPlayer];
//        [player play];
    }
    
    //slider
    else if (node && [node isKindOfClass:[Slider class]]) {
        Slider *slider = (Slider*)node;
        [slider removeAllActions];
        slider.touch = touch;
        slider.zPosition = 1.f;
    }
    
    //dismiss yes and no button
    if (self.btnYes.userInteractionEnabled) {
        [self onBackNo];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!_isLoaded) {
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

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!_isLoaded) {
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
                    [self onPackFinish];
                } else {
                    [self.sndSuccess play];
                    [self onImageFinish:nextRotate];
                }
                
            }
            break;
        }
        i++;
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}


#pragma mark -
- (void)onImageFinish:(BOOL)rotate {
    [self.btnNext setUserInteractionEnabled:YES];
    [self.btnNext setPosition:BUTTON_POS3];
    [self.btnNext setAlpha:0.f];
    float dur = .2f;
    
    SKAction *action = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
        float t = QuarticEaseOut(elapsedTime/dur);
        [node setAlpha:lerpf(0.f, BUTTON_ALPHA, t)];
        if (rotate) {
            [node setPosition:CGPointMake(BUTTON_POS3.x, lerpf(BUTTON_POS3.y-50, BUTTON_POS3.y, t))];
        } else {
            [node setPosition:CGPointMake(lerpf(BUTTON_POS3.x+50.f, BUTTON_POS3.x, t), BUTTON_POS3.y)];
        }
        
    }];
    [self.btnNext runAction:action];
}

- (void)onPackFinish {
    _packHasFinished = YES;
    [_btnExit setBackgroundColor:BUTTON_COLOR_RED];
    [_btnExit setFontColor:[UIColor whiteColor]];
    SldGameData *gd = [SldGameData getInstance];
    
    //
    NSDate *now = [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval dt = [now timeIntervalSinceDate:_gameBeginTime];
    int score = -(int)(dt*1000);
    //alert(@"Time", [NSString stringWithFormat:@"%f", dt]);
    if (_gameController.gameMode == MATCH) {
        [_btnExit setHidden:YES];
        
        SldHttpSession *session = [SldHttpSession defaultSession];
        NSDictionary *body = @{@"EventId":@(gd.eventInfo.id),
                               @"Secret":_gameController.matchSecret,
                               @"Score":@(score)};
        [session postToApi:@"event/playEnd" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                alertHTTPError(error, data);
            } else {
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                if (error) {
                    alert(@"Json error", [error localizedDescription]);
                    return;
                }
                alert(@"My result", [NSString stringWithFormat:@"%@", dict]);
                
                //update detail vc
                SldEventDetailViewController *detailVC = [SldEventDetailViewController getInstance];
                NSNumber *highScore = [NSNumber numberWithInt:score];
                NSNumber *rank = [dict objectForKey:@"Rank"];
                NSNumber *rankNum = [dict objectForKey:@"RankNum"];
                [detailVC setPlayRecordWithHighscore:highScore rank:rank rankNum:rankNum];
            }
        }];
        [_btnExit setHidden:NO];
    }
    
    //show blured image and cover
    [self addChild:_lastImageBlurSprite];
    _lastImageBlurSprite.hidden = NO;
    _lastImageBlurSprite.alpha = 0.f;
    [self addChild:_lastImageCover];
    _lastImageCover.hidden = NO;
    _lastImageCover.alpha = 0.f;
    
    //scale
    float texW = [_lastImageBlurSprite.texture size].width;
    float texH = [_lastImageBlurSprite.texture size].height;
    
    float scale = _targetW/texW;
    scale = MAX(_targetH/texH, scale);
    [_lastImageBlurSprite setScale:scale];
    
    _targetW = self.view.frame.size.width;
    _targetH = self.view.frame.size.height;
    float scale2 = _targetW/texW;
    scale2 = MAX(_targetH/texH, scale2);
    
    //blur action
    float dur = .5f;
    SKAction *action = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
        float t = QuarticEaseOut(elapsedTime/dur);
        [_lastImageBlurSprite setAlpha:lerpf(0.f, 1.f, t)];
        [_lastImageBlurSprite setScale:lerpf(scale, scale2, t)];
        [_lastImageCover setAlpha:lerpf(0.f, 1.f, t)];
    }];
    [_lastImageBlurSprite runAction:action];
    
    //complete label
    SKLabelNode *completeLabel = [SKLabelNode labelNodeWithFontNamed:@"HelveticaNeue"];
    [completeLabel setFontColor:makeUIColor(255, 197, 131, 255)];
    [completeLabel setText:@"COMPLETE"];
    [completeLabel setFontSize:32];
    [completeLabel setVerticalAlignmentMode:SKLabelVerticalAlignmentModeCenter];
    [completeLabel setHorizontalAlignmentMode:SKLabelHorizontalAlignmentModeCenter];
    [completeLabel setPosition:CGPointMake(self.view.frame.size.width*.5f, self.view.frame.size.height*.5f)];
    [_lastImageCover addChild:completeLabel];
    if (_needRotate) {
        completeLabel.zRotation = -M_PI_2;
    }
    
    //complete label action
    //dur = .4f;
    completeLabel.xScale = 0.f;
    completeLabel.yScale = 2.f;
    SKAction *appear = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
        float t = QuarticEaseOut(elapsedTime/dur);
        [node setYScale:lerpf(0.f, 1.f, t)];
        [node setXScale:2.0-lerpf(0.f, 1.f, t)];
    }];
    
    SKAction *wait = [SKAction waitForDuration:1.5f];
    dur = .3f;
    SKAction *flip1 = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
        float t = QuarticEaseIn(elapsedTime/dur);
        [node setYScale:lerpf(1.f, 0.f, t)];
    }];
    SKAction *setText = [SKAction runBlock:^{
        completeLabel.text = formatScore(score);
    }];
    SKAction *flip2 = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
        float t = QuarticEaseOut(elapsedTime/dur);
        [node setYScale:lerpf(0.f, 1.f, t)];
    }];
    SKAction *seq = [SKAction sequence:@[appear, wait, flip1, setText, flip2]];
    
    [completeLabel runAction:seq];
    
    //save to local
    FMDatabase *db = [SldDb defaultDb].fmdb;
    FMResultSet *rs = [db executeQuery:@"SELECT data FROM localScore WHERE key = ?", [NSNumber numberWithUnsignedLongLong:gd.eventInfo.id]];
    NSMutableArray *scores = nil;
    NSError *error;
    if ([rs next]) {
        NSData *js = [rs dataForColumnIndex:0];
        scores = [NSMutableArray arrayWithArray:[NSJSONSerialization JSONObjectWithData:js options:0 error:&error]];
        if (error) {
            lwError("%@", error);
            return;
        }
        [scores addObject:@(score)];
        [scores sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [obj1 integerValue] < [obj2 integerValue];
        }];
        while (scores.count > LOCAL_SCORE_COUNT_LIMIT) {
            [scores removeLastObject];
        }
    } else {
        scores = [NSMutableArray arrayWithArray:@[@(score)]];
    }
    
    NSData *js = [NSJSONSerialization dataWithJSONObject:scores options:0 error:&error];
    if (error) {
        lwError("%@", error);
        return;
    }
    BOOL ok = [db executeUpdate:@"REPLACE INTO localScore VALUES (?, ?)", @(gd.eventInfo.id), js];
    if (!ok) {
        lwError("%@", db.lastErrorMessage);
        return;
    }
}

- (void)onNextImageWithRotate:(BOOL)rotate {
    float dur = .2f;
    for (SKNode *node in self.uiRotateNodes) {
        float rot = rotate ? -M_PI_2 : 0.f;
        SKAction *rotate = [SKAction rotateToAngle:rot duration:dur];
        rotate.timingMode = SKActionTimingEaseInEaseOut;
        [node runAction:rotate];
    }
    
    [self.btnNext setUserInteractionEnabled:NO];
    
    if (_imgIdx > 0) {
        SKAction *action = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
            float t = QuarticEaseOut(elapsedTime/dur);
            [node setAlpha:lerpf(BUTTON_ALPHA, 0.f, t)];
            if (rotate) {
                [node setPosition:CGPointMake(BUTTON_POS3.x, lerpf(BUTTON_POS3.y, BUTTON_POS3.y+50.f, t))];
            } else {
                [node setPosition:CGPointMake(lerpf(BUTTON_POS3.x, BUTTON_POS3.x-50.f, t), BUTTON_POS3.y)];
            }
        }];
        [self.btnNext runAction:action];
    }
}

@end
