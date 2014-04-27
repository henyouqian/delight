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
@property (nonatomic) NSMutableArray *uiRotateNodes;
@property (nonatomic) SldButton *btnExit;
@property (nonatomic) SldButton *btnYes;
@property (nonatomic) SldButton *btnNo;
@property (nonatomic) SldButton *btnNext;
@end

static float BUTTON_ALPHA = .7f;
static CGPoint BUTTON_POS1 = {40, 40};
static CGPoint BUTTON_POS2 = {100, 40};
static CGPoint BUTTON_POS3 = {320-40, 40};
static CGPoint BUTTON_POS_HIDE = {-10000, 40};
static float BUTTON_FONT_SIZE = 18;
static NSString* BUTTON_BG = @"ui/btnBgWhite45.png";

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
        self.gamePlay.delegate = self;
        
        __weak typeof(self) weakSelf = self;
        
        UIColor *fontColorDark = makeUIColor(30, 30, 30, 255);
        
        //exit button
        self.btnExit = [SldButton buttonWithImageNamed:BUTTON_BG];
        [self.btnExit setLabelWithText:@"Exit" color:fontColorDark fontSize:BUTTON_FONT_SIZE];
        [self.btnExit setPosition:BUTTON_POS1];
        [self.btnExit setAlpha:BUTTON_ALPHA];
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
        [self.btnYes setBackgroundColor:makeUIColor(255, 59, 48, 255)];
        [self.btnYes setAlpha:0.f];
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
        [self.btnNext setBackgroundColor:makeUIColor(76, 217, 100, 255)];
        [self.btnNext setAlpha:0.f];
        self.btnNext.onClick = ^{
            [weakSelf.gamePlay next];
        };
        [self addChild:self.btnNext];
        [self.uiRotateNodes addObject:self.btnNext];
    }
    return self;
}

- (void)dealloc {
    
}

static float lerpf(float a, float b, float t) {
    return a + (b - a) * t;
}

- (void)onExit {
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
    [self.navigationController popViewControllerAnimated:YES];
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

- (void)update:(CFTimeInterval)currentTime {
    [self.gamePlay update];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.gamePlay touchesBegan:touches withEvent:event];
    if (self.btnYes.userInteractionEnabled) {
        [self onBackNo];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.gamePlay touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.gamePlay touchesEnded:touches withEvent:event];
}

#pragma mark - SldGamePlayDelegate
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

- (void)onPackFinish:(BOOL)rotate {
    
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

@end
