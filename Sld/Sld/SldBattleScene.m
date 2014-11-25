//
//  SldBattleScene.m
//  Sld
//
//  Created by Wei Li on 14-4-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldBattleScene.h"
#import "SldGameScene.h"
#import "SldUtil.h"
#import "SldButton.h"
#import "SldStreamPlayer.h"
#import "SldHttpSession.h"
#import "SldGameData.h"
#import "SldDb.h"
#import "SldConfig.h"
#import "nv-ios-digest/SHA1.h"

static SKView * _skView = nil;

@interface SldBattleSceneController()

@property (nonatomic) SldGameData *gd;
@end

@implementation SldBattleSceneController

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    
    // Configure the view.
    _skView = (SKView *)self.view;
    //    skView.showsFPS = YES;
    //    skView.showsNodeCount = YES;
    
    // Create and configure the scene.
    SldBattleScene* scene = [[SldBattleScene alloc] initWithSize:_skView.bounds.size controller:self firstSprite:_firstSprite];
    scene.scaleMode = SKSceneScaleModeAspectFill;
    scene.navigationController = self.navigationController;
    
    //
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    // Present the scene.
    [_skView presentScene:scene];
}

- (void)applicationWillResignActive
{
    [(SKView *)self.view setPaused:YES];
}

- (void)applicationDidBecomeActive
{
    [(SKView *)self.view setPaused:NO];
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskPortrait;
    } else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [super viewWillAppear:animated];
}

@end

//=========================================================
@interface SldBattleScene()
@property (nonatomic) NSMutableArray *uiRotateNodes;

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
@property (nonatomic) SKLabelNode *loadingLabel;
@property (nonatomic) SKLabelNode *loadingShadowLabel;
@property (nonatomic) BOOL inCurtain;
@property (nonatomic) SKLabelNode *timerLabel;
@property (nonatomic) SKSpriteNode *timerBg;
@property (nonatomic) BOOL packHasFinished;
@property (nonatomic) SKSpriteNode *lastImageBlurSprite;
@property (nonatomic) SKSpriteNode *lastImageCover;
@property (nonatomic) BOOL gameRunning;
@property (nonatomic) BOOL beltRotate;

@property (nonatomic) SldGameData *gd;
@property (nonatomic) NSDictionary *procDict;


@property (nonatomic) float targetW;
@property (nonatomic) float targetH;

@end

static NSString* BUTTON_BG = @"ui/btnBgWhite45.png";

static const float DOT_ALPHA_NORMAL = .5f;
static const float DOT_ALPHA_HIGHLIGHT = 1.f;
static const float DOT_SCALE_NORMAL = .6f;
static const float DOT_SCALE_HIGHLIGHT = .75f;
static const float MOVE_DURATION = .1f;
//static const UInt32 DEFUALT_SLIDER_NUM = 6;
static const float TRANS_DURATION = .3f;

static UIColor *BUTTON_COLOR_RED = nil;
static UIColor *BUTTON_COLOR_GREEN = nil;


@implementation SldBattleScene

NSDate *_gameBeginTime;

- (instancetype)initWithSize:(CGSize)size controller:(SldBattleSceneController*)controller firstSprite:(SldSprite*)firstSprite{
    if (self = [super initWithSize:size]) {
        _controller = controller;
        _gd = [SldGameData getInstance];
        
        _imgIdx = 0;
        _hasFinished = NO;
        _isLoaded = NO;
        _needRotate = NO;
        _gameRunning = NO;
        
        _sprites = [NSMutableArray arrayWithCapacity:3];
        if (_gd.match) {
            _sliderNum = _gd.match.sliderNum;
        } else {
            _sliderNum = _gd.sliderNum;
        }
        
        _sliderParent = [SKNode node];
        [self.scene addChild:self.sliderParent];
        _nextSliderParent = [SKNode node];
        [self.scene addChild:self.nextSliderParent];
        
        
        BUTTON_COLOR_RED = makeUIColor(255, 59, 48, 255);
        BUTTON_COLOR_GREEN = makeUIColor(76, 217, 100, 255);
        
        self.uiRotateNodes = [NSMutableArray arrayWithCapacity:10];
        
        
        //
        [self.scene setUserInteractionEnabled:NO];
        
        //
        NSMutableArray *files = [NSMutableArray arrayWithCapacity:[_gd.packInfo.images count]];
        int i = 0;
        for (NSString *img in _gd.packInfo.images) {
            if (i != _controller.firstIndex) {
                [files addObject:makeImagePath(img)];
            }
            i++;
        }
        //shuffle files
        NSUInteger fileCount = [files count];
        NSMutableArray* idxs = [self shuffle:fileCount more:NO];
        _files = [NSMutableArray arrayWithCapacity:fileCount];
        [_files addObject:makeImagePath(_gd.packInfo.images[_controller.firstIndex])];
        for (int i = 0; i < fileCount; ++i) {
            [self.files addObject:files[[idxs[i] unsignedIntegerValue]]];
        }
        
        [self loadLastBlurSprite];
        
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
        
        self.loadingLabel = [SKLabelNode labelNodeWithFontNamed:@"HelveticaNeue"];
        [self.loadingLabel setFontColor:colorCtText];
        [self.loadingLabel setText:@""];
        [self.loadingLabel setFontSize:100];
        [self.loadingLabel setVerticalAlignmentMode:SKLabelVerticalAlignmentModeCenter];

        self.loadingShadowLabel = [SKLabelNode labelNodeWithFontNamed:@"HelveticaNeue"];
        [self.loadingShadowLabel setFontColor:[UIColor blackColor]];
        [self.loadingShadowLabel setText:@""];
        [self.loadingShadowLabel setFontSize:100];
        [self.loadingShadowLabel setVerticalAlignmentMode:SKLabelVerticalAlignmentModeCenter];
        [self.loadingShadowLabel setPosition:CGPointMake(2, -2)];
        
        
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
        [self.curtainBelt addChild:self.loadingShadowLabel];
        [self.curtainBelt addChild:self.loadingLabel];
        
        //load image
        [_sprites addObject:firstSprite];
        [self setupSprite:firstSprite];
        [self loadImage];
        
        //timer
        float y = self.size.height-45.f;
        _timerBg = [SKSpriteNode spriteNodeWithColor:[SKColor colorWithRed:0 green:0 blue:0 alpha:.5f] size:CGSizeMake(115, 25)];
        [_timerBg setAnchorPoint:CGPointMake(1, 0.5)] ;
        [_timerBg setPosition: CGPointMake(self.size.width, y)];
        [_timerBg setZPosition:1.f];
        [_timerBg setUserInteractionEnabled:NO];
        [self addChild:_timerBg];
        
        self.timerLabel = [SKLabelNode labelNodeWithFontNamed:@"HelveticaNeue"];
        [self.timerLabel setFontColor:[UIColor whiteColor]];
        [self.timerLabel setFontSize:20];
        [self.timerLabel setHorizontalAlignmentMode:SKLabelHorizontalAlignmentModeLeft];
        [self.timerLabel setVerticalAlignmentMode:SKLabelVerticalAlignmentModeCenter];
        [self.timerLabel setPosition:CGPointMake(-100, 0)];
        [self.timerLabel setText:@"0:00.000"];
        [self.timerLabel setZPosition:1.f];
        [self.timerLabel setUserInteractionEnabled:NO];
        [_timerBg addChild:self.timerLabel];
        
        if (_beltRotate) {
            _timerBg.zRotation = -M_PI_2;
            _timerBg.anchorPoint = CGPointMake(0, 0.5);
            _timerBg.position = CGPointMake(self.size.width-17, self.size.height);
            _timerBg.size = CGSizeMake(135, 25);
            _timerLabel.position = CGPointMake(30, 0);
        }
        
        //web socket
        _gd.webSocket.delegate = self;
        
        _procDict = @{
            @"foeDisconnect":[NSValue valueWithPointer:@selector(onFoeDisconnect:)],
            @"foeFinish":[NSValue valueWithPointer:@selector(onFoeFinish:)],
            @"result":[NSValue valueWithPointer:@selector(onResult:)],
        };
        
    }
    return self;
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    lwInfo(@"socketRocket error: %@", [error localizedDescription]);
    [[[UIAlertView alloc] initWithTitle:@"连接不成功"
                                message:nil
                       cancelButtonItem:[RIButtonItem itemWithLabel:@"好的" action:^{
        [self.navigationController popToRootViewControllerAnimated:YES];
    }]
                       otherButtonItems:nil] show];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    [[[UIAlertView alloc] initWithTitle:@"连接已断开"
                                message:nil
                       cancelButtonItem:[RIButtonItem itemWithLabel:@"好的" action:^{
        [self.navigationController popToRootViewControllerAnimated:YES];
    }]
                       otherButtonItems:nil] show];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    NSError *jsonErr;
    NSData* data = message;
    if ([message isKindOfClass:[NSString class]]) {
        data = [message dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    NSDictionary *msg = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
    if (jsonErr) {
        alert(@"Json error", [jsonErr localizedDescription]);
        return;
    }
    
    NSString *type = [msg objectForKey:@"Type"];
    if ([type compare:@"err"] == 0) {
        alert(@"ws error", [msg objectForKey:@"String"]);
        return;
    }
    NSValue *selVal = [_procDict objectForKey:type];
    if (selVal) {
        SEL aSel = [selVal pointerValue];
        [self performSelector:aSel withObject:msg];
    }
}

- (void)onFoeDisconnect: (NSDictionary*)msg{
    lwInfo("onFoeDisconnect");
}

- (void)onFoeFinish: (NSDictionary*)msg{
    lwInfo("onFoeFinish");
}

- (void)onResult: (NSDictionary*)msg{
    lwInfo("onResult");
}

- (void)loadLastBlurSprite {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //effect node
        SKEffectNode *effectNode = [SKEffectNode node];
        [effectNode setShouldEnableEffects:YES];
        CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur" keysAndValues:@"inputRadius", @10.0f, nil];
        [effectNode setFilter:blur];
        
        UIImage *image = [UIImage imageWithContentsOfFile:[_files lastObject]];
        SKTexture *texture = [SKTexture textureWithImage:image];
        SKSpriteNode *lastImageSpt = [SKSpriteNode spriteNodeWithTexture:texture];
        [effectNode addChild:lastImageSpt];
        
        texture = [_skView textureFromNode:effectNode];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            _lastImageBlurSprite = [SKSpriteNode spriteNodeWithTexture:texture];
            _lastImageBlurSprite.zPosition = 2.f;
            
            //
            float texW = [_lastImageBlurSprite.texture size].width;
            float texH = [_lastImageBlurSprite.texture size].height;
            _lastImageBlurSprite.anchorPoint = CGPointMake(.5f, .5f);
            _lastImageBlurSprite.position = CGPointMake(_skView.frame.size.width*.5f, _skView.frame.size.height*.5f);
            if (texW > texH) {
                _lastImageBlurSprite.zRotation = -M_PI_2;
            }
        });
    });
    
    //cover
    _lastImageCover = [SKSpriteNode spriteNodeWithColor:makeUIColor(100, 100, 100, 128) size:_skView.frame.size];
    _lastImageCover.anchorPoint = CGPointZero;
    _lastImageCover.zPosition = 2.f;
}

- (void)dealloc {
     [[AdMoGoInterstitialManager shareInstance] interstitialCancel];
}

static float lerpf(float a, float b, float t) {
    return a + (b - a) * t;
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
        lwInfo(@"loadImgIdx:%d", loadImgIdx);
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
//                            if (idx == 0 || (i == 1 && self.imgIdx == idx)) {
//                                [self setupSprite:sprite];
//                            }
                        }
                    }
                }
            });
        });
    }
}

//- (void)next {
//    if (self.hasFinished) {
//        [self nextImage];
//    }
//}

-(void)nextImage {
    if (self.imgIdx >= (NSInteger)[self.files count]-1) {
        //lwError("idx >= [self.files count]-1: self.imgIdx=%d", (int)self.imgIdx);
        return;
    }
    
    //
    _hasFinished = NO;
    _isLoaded = NO;
    self.imgIdx++;
    
    //dots
    if (self.imgIdx > 0) {
        float dx = self.scene.size.width / [self.files count];
        SKAction *action = [SKAction moveToX:(self.imgIdx+.5f)*dx duration:.2f];
        action.timingMode = SKActionTimingEaseInEaseOut;
        [self.highlightDot runAction:action];
    }
    
    
    
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
        usleep(200000);
        [self.scene setUserInteractionEnabled:YES];
        
        SKAction *aWait = [SKAction waitForDuration:1.0];
        SKAction *aSec3 = [SKAction runBlock:^{
            _loadingLabel.text = @"3";
            _loadingShadowLabel.text = @"3";
        }];
        SKAction *aSec2 = [SKAction runBlock:^{
            _loadingLabel.text = @"2";
            _loadingShadowLabel.text = @"2";
        }];
        SKAction *aSec1 = [SKAction runBlock:^{
            _loadingLabel.text = @"1";
            _loadingShadowLabel.text = @"1";
        }];
        SKAction *aSec0 = [SKAction runBlock:^{
            _loadingLabel.text = @"";
            _loadingShadowLabel.text = @"";
        }];
        SKAction *aSeq = [SKAction sequence:@[aWait, aSec3, aWait, aSec2, aWait, aSec1, aWait, aSec0]];
        
        [self runAction:aSeq completion:^{
            float dur = .3f;
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
                    _isLoaded = YES;
                }];
            }];
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
    SKNode *node = [_sliderParent nodeAtPoint:pt];
    
    
    //slider
    if (!_inCurtain && node && [node isKindOfClass:[Slider class]]) {
        Slider *slider = (Slider*)node;
        [slider removeAllActions];
        slider.touch = touch;
        slider.zPosition = 1.f;
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
    [self nextImage];
    
    NSDictionary *msg = @{@"CompleteNum":@(_imgIdx)};
    [SldUtil sendWithSocket:_gd.webSocket type:@"progress" data:msg];
}

- (void)onPackFinish {
    //
    _packHasFinished = YES;
    _gameRunning = NO;
    
    //score
    NSDate *now = [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval dt = [now timeIntervalSinceDate:_gameBeginTime];
    int score = -(int)(dt*1000);
    
    //web socket
    NSDictionary *msg = @{@"Msec":@(-score)};
    [SldUtil sendWithSocket:_gd.webSocket type:@"finish" data:msg];
    
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
    
    SKAction *delay = [SKAction waitForDuration:1.0];
    SKAction *seq = [SKAction sequence:@[appear, delay]];
    
    [completeLabel runAction:seq completion:^{
        UIViewController* vc = [getStoryboard() instantiateViewControllerWithIdentifier:@"battleResultController"];
//        [self.controller presentViewController:vc animated:YES completion:nil];
        [self.navigationController pushViewController:vc animated:YES];
    }];
}

- (void)onNextImageWithRotate:(BOOL)rotate {
    float dur = .2f;
    for (SKNode *node in self.uiRotateNodes) {
        float rot = rotate ? -M_PI_2 : 0.f;
        SKAction *action = [SKAction rotateToAngle:rot duration:dur];
        action.timingMode = SKActionTimingEaseInEaseOut;
        [node runAction:action];
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
    
    [_controller presentViewController:storeProductViewContorller animated:YES completion:nil];
}

- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    if (_storeViewLoaded) {
        _storeViewLoaded = NO;
        alert(@"评价完成", nil);
    }
    [viewController dismissViewControllerAnimated:YES completion:nil];
}


@end
