//
//  SldGameScene.m
//  Sld
//
//  Created by Wei Li on 14-4-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldGameScene.h"
#import "SldUtil.h"
#import "SldButton.h"
#import "SldSprite.h"
#import "SldStreamPlayer.h"
#import "SldHttpSession.h"
#import "SldGameData.h"
#import "SldDb.h"
#import "SldConfig.h"
#import "nv-ios-digest/SHA1.h"

//=========================================================
@interface Slider : SKSpriteNode
@property (nonatomic) NSUInteger idx;
@property (nonatomic) UITouch *touch;
@end

@implementation Slider
@end

//=========================================================
@interface TimeBar : SKNode
-(instancetype)initWithChallengeSecs:(NSArray*)secs size:(CGSize)size;
-(void)update:(NSTimeInterval)timeFromStart;
@property (nonatomic) SKSpriteNode *bar;
@property (nonatomic) UIColor *greenColor;
@property (nonatomic) UIColor *yellowColor;
@property (nonatomic) UIColor *redColor;
@property (nonatomic) float greenWidth;
@property (nonatomic) float yellowWidth;
@property (nonatomic) float redTime;
@property (nonatomic) CGSize size;
@property (nonatomic) int starNum;

@end

@implementation TimeBar
-(instancetype)initWithChallengeSecs:(NSArray*)secs size:(CGSize)size {
    if (self = [super init]) {
        if (secs.count != 3) {
            return self;
        }
        _size = size;
        
        int redSec = [(NSNumber*)[secs lastObject] intValue];
        float redTime = (float)redSec;
        int yellowSec = [(NSNumber*)[secs objectAtIndex:1] intValue];
        float yellowTime = (float)yellowSec;
        int greenSec = [(NSNumber*)[secs firstObject] intValue];
        float greenTime = (float)greenSec;
        
        _redTime = redTime;
        
        int alpha = 80;
        _redColor = makeUIColor(240, 78, 82, alpha);
        _yellowColor = makeUIColor(255, 214, 91, alpha);
        _greenColor = makeUIColor(52, 214, 125, alpha);
        
        SKSpriteNode* bar = [SKSpriteNode spriteNodeWithColor:_redColor size:size];
        bar.anchorPoint = CGPointMake(0.f, 1.f);
        [self addChild:bar];
        
        _yellowWidth = size.width*yellowTime/redTime;
        bar = [SKSpriteNode spriteNodeWithColor:_yellowColor size:CGSizeMake(_yellowWidth, size.height)];
        bar.anchorPoint = CGPointMake(0.f, 1.f);
        [self addChild:bar];
        
        _greenWidth = size.width*greenTime/redTime;
        bar = [SKSpriteNode spriteNodeWithColor:_greenColor size:CGSizeMake(_greenWidth, size.height)];
        bar.anchorPoint = CGPointMake(0.f, 1.f);
        [self addChild:bar];
        
        //
        _bar = [SKSpriteNode spriteNodeWithColor:[_greenColor colorWithAlphaComponent:1.0] size:CGSizeMake(1.0, size.height)];
        _bar.anchorPoint = CGPointMake(0.f, 1.f);
        [_bar setXScale:0.0];
        [self addChild:_bar];
        
        _starNum = 3;
    }
    return self;
}

-(void)update:(NSTimeInterval)timeFromStart {
    float f = (float)timeFromStart / _redTime;
    if (f > 1.0) {
        f = 1.0;
    }
    
    float width = f * _size.width;
    int starNum = 3;
    
    UIColor *color = [_greenColor colorWithAlphaComponent:1.0];
    if (f == 1.0) {
        color = makeUIColor(130, 0, 5, 255);
        starNum = 0;
    } else if (width > _yellowWidth) {
        color = [_redColor colorWithAlphaComponent:1.0];
        starNum = 1;
    } else if(width > _greenWidth) {
        color = [_yellowColor colorWithAlphaComponent:1.0];
        starNum = 2;
    }

    __block BOOL inAction = NO;
    if (_starNum != starNum && !inAction) {
        inAction = YES;
        SKAction *action = [SKAction colorizeWithColor:color colorBlendFactor:1.0 duration:0.3];
        [_bar runAction:action completion:^{
            inAction = NO;
        }];
    }
    //_bar.color = color;
    
    [_bar setXScale:width];
    _starNum = starNum;
}

@end

//=========================================================
@interface SldGameScene()
@property (nonatomic) TimeBar *timeBar;
@property (nonatomic) NSMutableArray *uiRotateNodes;
@property (nonatomic) SldButton *btnExit;
@property (nonatomic) SldButton *btnYes;
@property (nonatomic) SldButton *btnNo;
@property (nonatomic) SldButton *btnNext;

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
@property (nonatomic) SKSpriteNode *timerBg;
@property (nonatomic) BOOL packHasFinished;
@property (nonatomic) SKSpriteNode *lastImageBlurSprite;
@property (nonatomic) SKSpriteNode *lastImageCover;
@property (nonatomic) BOOL gameRunning;
@property (nonatomic) BOOL beltRotate;

@property (nonatomic) SldGameData *gd;


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
//static const UInt32 DEFUALT_SLIDER_NUM = 6;
static const float TRANS_DURATION = .3f;

UIColor *BUTTON_COLOR_RED = nil;
UIColor *BUTTON_COLOR_GREEN = nil;


@implementation SldGameScene

NSDate *_gameBeginTime;


+ (instancetype)sceneWithSize:(CGSize)size controller:(SldGameController*)controller {
    SldGameScene* inst = [[SldGameScene alloc] initWithSize:size controller:controller];
    return inst;
}

- (instancetype)initWithSize:(CGSize)size controller:(SldGameController*)controller {
    if (self = [super initWithSize:size]) {
        _gameController = controller;
        
        _gd = [SldGameData getInstance];
        if (_gd.gameMode == M_MATCH) {
            _gd.needRefreshPlayedList = YES;
        }
        
        BUTTON_POS3.x = size.width - BUTTON_POS1.x;
        
        NSMutableArray *files = [NSMutableArray arrayWithCapacity:[_gd.packInfo.images count]];
        if (M_TEST == _gd.gameMode) {
            for (NSString *img in _gd.packInfo.images) {
                [files addObject:img];
            }
        } else {
            for (NSString *img in _gd.packInfo.images) {
                [files addObject:makeImagePath(img)];
            }
        }
        
        _imgIdx = -1;
        _sprites = [NSMutableArray arrayWithCapacity:3];
        _sliderNum = _gd.match.sliderNum;
            
        _needRotate = NO;
        _sliderParent = [SKNode node];
        [self.scene addChild:self.sliderParent];
        _nextSliderParent = [SKNode node];
        [self.scene addChild:self.nextSliderParent];
        _isLoaded = NO;
        _gameRunning = NO;
        
        
        __weak typeof(self) weakSelf = self;
        
        UIColor *fontColorDark = makeUIColor(30, 30, 30, 255);
        BUTTON_COLOR_RED = makeUIColor(255, 59, 48, 255);
        BUTTON_COLOR_GREEN = makeUIColor(76, 217, 100, 255);
        
        float buttonZ = 10.f;
        
        //time bar
        _timeBar = [[TimeBar alloc] initWithChallengeSecs:@[@10, @20, @30] size:CGSizeMake(size.width, 3)];
        [_timeBar setPosition:CGPointMake(0, size.height)];
        _timeBar.zPosition = buttonZ;
        //[self addChild:_timeBar];
        
        //exit button
        self.btnExit = [SldButton buttonWithImageNamed:BUTTON_BG];
        [self.btnExit setLabelWithText:@"返" color:fontColorDark fontSize:BUTTON_FONT_SIZE];
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
        [self.btnYes setLabelWithText:@"是" color:[UIColor whiteColor] fontSize:BUTTON_FONT_SIZE];
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
        [self.btnNo setLabelWithText:@"否" color:fontColorDark fontSize:BUTTON_FONT_SIZE];
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
        [self.btnNext setLabelWithText:@"次" color:[UIColor whiteColor] fontSize:BUTTON_FONT_SIZE];
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
        [self.curtainTop setZPosition:9];
        [self addChild:self.curtainTop];
        
        self.curtainBottom = [SKSpriteNode spriteNodeWithColor:colorCtBg size:self.size];
        [self.curtainBottom setAnchorPoint:CGPointMake(0.f, 1.f)];
        [self.curtainBottom setPosition:CGPointMake(0.f, self.size.height*.5f)];
        [self.curtainBottom setZPosition:9];
        [self addChild:self.curtainBottom];
        
        self.curtainLabel = [SKLabelNode labelNodeWithFontNamed:@"HelveticaNeue"];
        [self.curtainLabel setFontColor:colorCtText];
        [self.curtainLabel setText:@"点击开始游戏"];
        [self.curtainLabel setFontSize:22];
        [self.curtainLabel setVerticalAlignmentMode:SKLabelVerticalAlignmentModeCenter];
        //[self.curtainLabel setAlpha:0.f];
        self.curtainLabel.yScale = 0.f;
        
        
        //belt and rotate
        UIImage *image = [UIImage imageWithContentsOfFile:[_files firstObject]];
        _beltRotate = image.size.width > image.size.height;
        if (_beltRotate) {
            self.curtainBelt = [SKSpriteNode spriteNodeWithColor:colorCtBelt size:CGSizeMake(self.size.height, 30.f)];
            [self.curtainBelt setZRotation:-M_PI_2];
        } else {
            self.curtainBelt = [SKSpriteNode spriteNodeWithColor:colorCtBelt size:CGSizeMake(self.size.width, 30.f)];
        }
        
        [self.curtainBelt setAnchorPoint:CGPointMake(.5f, .5f)];
        [self.curtainBelt setPosition:CGPointMake(self.size.width*.5f, self.size.height*.5f)];
        [self addChild:self.curtainBelt];
        [self.curtainBelt setZPosition:9];
        [self.curtainBelt addChild:self.curtainLabel];
        
        
        //load image
        [self nextImage];
        
        //timer
        float y = self.size.height-45.f;
        _timerBg = [SKSpriteNode spriteNodeWithColor:[SKColor colorWithRed:0 green:0 blue:0 alpha:.5f] size:CGSizeMake(115, 25)];
        [_timerBg setAnchorPoint:CGPointMake(1, 0.5)] ;
        [_timerBg setPosition: CGPointMake(self.size.width, y)];
        [_timerBg setZPosition:1.f];
        [self addChild:_timerBg];
        
        self.timerLabel = [SKLabelNode labelNodeWithFontNamed:@"HelveticaNeue"];
        [self.timerLabel setFontColor:[UIColor whiteColor]];
        [self.timerLabel setFontSize:20];
        [self.timerLabel setHorizontalAlignmentMode:SKLabelHorizontalAlignmentModeLeft];
        [self.timerLabel setVerticalAlignmentMode:SKLabelVerticalAlignmentModeCenter];
        [self.timerLabel setPosition:CGPointMake(-100, 0)];
        [self.timerLabel setText:@"0:00.000"];
        [self.timerLabel setZPosition:1.f];
        [_timerBg addChild:self.timerLabel];
        
        if (_beltRotate) {
            _timerBg.zRotation = -M_PI_2;
            _timerBg.anchorPoint = CGPointMake(0, 0.5);
            _timerBg.position = CGPointMake(self.size.width-17, self.size.height);
            _timerBg.size = CGSizeMake(135, 25);
            _timerLabel.position = CGPointMake(30, 0);
        }
        
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
    if (_gd.gameMode == M_MATCH) {
        RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:@"否" action:nil];
        
        RIButtonItem *yesItem = [RIButtonItem itemWithLabel:@"退出!" action:^{
            [self.navigationController popViewControllerAnimated:YES];
        }];
        
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"确定退出游戏?"
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
        //lwError("idx >= [self.files count]-1: self.imgIdx=%d", (int)self.imgIdx);
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
    
    if (_gameRunning) {
        NSDate *now = [NSDate dateWithTimeIntervalSinceNow:0];
        NSTimeInterval dt = [now timeIntervalSinceDate:_gameBeginTime];
        [_timeBar update:dt];
        
        int t = (int)(dt*1000);
        _timerLabel.text = formatScore(-t);
    }
    
//    _timerBg.zRotation = _timerBg.zRotation + 0.01;
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
        if (_beltRotate) {
            left = [SKAction moveToY:self.size.height*2.5f duration:.8f];
        }
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
                _gameRunning = YES;
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
    if (_gd.autoPaging) {
        [self nextImage];
    } else {
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
}

- (void)onPackFinish {
    //ads
    if (M_TEST != _gd.gameMode) {
        float rd = (float)(arc4random() % 100);
        AdsConf *adsConf = _gd.playerInfo.adsConf;
        if (rd/100.f < adsConf.showPercent) {
            if (adsConf.delayPercent > 0 && adsConf.delaySec > 0) {
                rd = (float)(arc4random() % 100)/100.f;
                if (rd/100.f < adsConf.delayPercent) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, adsConf.delaySec * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                        if (_gd.match.promoImage && _gd.match.promoImage.length) {
                            [_gameController showUserAds];
                        } else {
                            [[AdMoGoInterstitialManager shareInstance] interstitialShow:YES];
                        }
                    });
                }
            } else {
                if (_gd.match.promoImage && _gd.match.promoImage.length) {
                    [_gameController showUserAds];
                } else {
                    [[AdMoGoInterstitialManager shareInstance] interstitialShow:YES];
                }
            }
        }
    }
    
    //
    _packHasFinished = YES;
    _gameRunning = NO;
    [_btnExit setBackgroundColor:BUTTON_COLOR_RED];
    [_btnExit setFontColor:[UIColor whiteColor]];
    
    //score
    NSDate *now = [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval dt = [now timeIntervalSinceDate:_gameBeginTime];
    int score = -(int)(dt*1000);
    _gd.recentScore = score;
    
    //M_MATCH
    if (_gd.gameMode == M_MATCH) {
        [_btnExit setHidden:YES];
        
        //rank label
        SKLabelNode *rankLabel = [SKLabelNode labelNodeWithFontNamed:@"HelveticaNeue"];
        [rankLabel setFontColor:makeUIColor(255, 197, 131, 255)];
        [rankLabel setFontSize:32];
        [rankLabel setVerticalAlignmentMode:SKLabelVerticalAlignmentModeCenter];
        [rankLabel setHorizontalAlignmentMode:SKLabelHorizontalAlignmentModeCenter];
        [_lastImageCover addChild:rankLabel];
        
        CGPoint pos = CGPointMake(self.view.frame.size.width*.5f, self.view.frame.size.height*.5f);
        
        if (_needRotate) {
            rankLabel.zRotation = -M_PI_2;
            pos.x -= 25;
        } else {
            pos.y -= 25;
        }
        rankLabel.position = pos;
        rankLabel.text = @"提交成绩...";
        
        //rankLabel action
        float dur = .4f;
        rankLabel.xScale = 0.f;
        rankLabel.yScale = 2.f;
        SKAction *appear = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
            float t = QuarticEaseOut(elapsedTime/dur);
            [node setYScale:lerpf(0.f, 1.f, t)];
            [node setXScale:2.0-lerpf(0.f, 1.f, t)];
        }];
        [rankLabel runAction:appear];
        
        //checksum
        NSString *checksum = [NSString stringWithFormat:@"%@+%d9d7a", _gd.matchSecret, score+8703];
        checksum = [SldUtil sha1WithString:checksum];
        
        //post
        SldHttpSession *session = [SldHttpSession defaultSession];
        NSDictionary *body = @{@"MatchId":@(_gd.match.id),
                               @"Secret":_gd.matchSecret,
                               @"Score":@(score),
                               @"Checksum":checksum};
        
        [session postToApi:@"match/playEnd" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                alertHTTPError(error, data);
            } else {
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                if (error) {
                    alert(@"Json error", [error localizedDescription]);
                    return;
                }
                
                //
                if (score > _gd.matchPlay.highScore || _gd.matchPlay.highScore == 0) {
                    _gd.matchPlay.highScore = score;
                }
                _gd.matchPlay.myRank = [(NSNumber*)[dict objectForKey:@"MyRank"] intValue];
                _gd.matchPlay.rankNum = [(NSNumber*)[dict objectForKey:@"RankNum"] intValue];
                
                //rank label
                double delayInSeconds = .4f;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    //SKAction *wait = [SKAction waitForDuration:1.f];
                    SKAction *flip1 = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
                        float t = QuarticEaseIn(elapsedTime/dur);
                        [node setYScale:lerpf(1.f, 0.f, t)];
                    }];
                    SKAction *setText = [SKAction runBlock:^{
                        rankLabel.text = [NSString stringWithFormat:@"当前排名: %d", _gd.matchPlay.myRank];
                    }];
                    SKAction *flip2 = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
                        float t = QuarticEaseOut(elapsedTime/dur);
                        [node setYScale:lerpf(0.f, 1.f, t)];
                    }];
                    SKAction *seq = [SKAction sequence:@[/*wait, */flip1, setText, flip2]];
                    [rankLabel runAction:seq];
                });
            }
        }];
        [_btnExit setHidden:NO];
    }
    
    // M_TEST
    else if (_gd.gameMode == M_TEST) {
        if (_gd.userPackTestHistory == nil) {
            _gd.userPackTestHistory = [NSMutableArray array];
        }
        NSString *str = [NSString stringWithFormat:@"滑块数量：%d，用时：%@", _sliderNum, formatScore(score)];
        [_gd.userPackTestHistory insertObject:str atIndex:0];
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
    scale2 = MAX(_targetH/texH, scale2)*1.1;
    
    //blur action
    float dur = .9f;
    SKAction *action = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
        float t = ExponentialEaseOut(elapsedTime/dur);
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
    [_lastImageCover addChild:completeLabel];
    CGPoint pos = CGPointMake(self.view.frame.size.width*.5f, self.view.frame.size.height*.5f);
    if (_needRotate) {
        completeLabel.zRotation = -M_PI_2;
        pos.x += 25;
    } else {
        pos.y += 25;
    }
    [completeLabel setPosition:pos];
    
    //complete label action
    //dur = .4f;
    completeLabel.xScale = 0.f;
    completeLabel.yScale = 2.f;
    
    completeLabel.text = formatScore(score);
    SKAction *appear = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
        float t = QuarticEaseOut(elapsedTime/dur);
        [node setYScale:lerpf(0.f, 1.f, t)];
        [node setXScale:2.0-lerpf(0.f, 1.f, t)];
    }];
    
    [completeLabel runAction:appear];
    
    
//    SKAction *appear = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
//        float t = QuarticEaseOut(elapsedTime/dur);
//        [node setYScale:lerpf(0.f, 1.f, t)];
//        [node setXScale:2.0-lerpf(0.f, 1.f, t)];
//    }];
//    
//    SKAction *wait = [SKAction waitForDuration:1.f];
//    dur = .3f;
//    SKAction *flip1 = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
//        float t = QuarticEaseIn(elapsedTime/dur);
//        [node setYScale:lerpf(1.f, 0.f, t)];
//    }];
//    SKAction *setText = [SKAction runBlock:^{
//        completeLabel.text = formatScore(score);
//    }];
//    SKAction *flip2 = [SKAction customActionWithDuration:dur actionBlock:^(SKNode *node, CGFloat elapsedTime) {
//        float t = QuarticEaseOut(elapsedTime/dur);
//        [node setYScale:lerpf(0.f, 1.f, t)];
//    }];
//    SKAction *seq = [SKAction sequence:@[appear, wait, flip1, setText, flip2]];
    
//    [completeLabel runAction:seq];
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

static BOOL _storeViewLoaded = NO;

- (void)popupRatingView {
    SKStoreProductViewController *storeProductViewContorller =[[SKStoreProductViewController alloc] init];
    storeProductViewContorller.delegate = self;
    
    [storeProductViewContorller loadProductWithParameters:
        @{SKStoreProductParameterITunesItemIdentifier: @"873521060"}completionBlock:^(BOOL result, NSError *error) {
            if(error){
                NSLog(@"error %@ with userInfo %@",error,[error userInfo]);
            } else {
                _storeViewLoaded = YES;
            }
        }
    ];
    
    [_gameController presentViewController:storeProductViewContorller animated:YES completion:nil];
}

- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    if (_storeViewLoaded) {
        _storeViewLoaded = NO;
        alert(@"评价完成", nil);
    }
    [viewController dismissViewControllerAnimated:YES completion:nil];
}


@end
