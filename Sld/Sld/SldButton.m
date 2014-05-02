//
//  SldButton.m
//  Sld
//
//  Created by Wei Li on 14-4-25.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldButton.h"

@interface SldButton()
@property (nonatomic, weak) SKSpriteNode* sprite;
@property (nonatomic) SKNode* scaleNode;
@property (nonatomic) SKLabelNode* label;
@property (nonatomic) BOOL highlight;
@end

@implementation SldButton


+ (instancetype)buttonWithImageNamed:(NSString*)imageName {
    SldButton *inst = [[SldButton alloc] initWithImageNamed:imageName];
    return inst;
}

- (instancetype)initWithImageNamed:(NSString*)imageName {
    if (self = [super init]) {
        self.scaleNode = [SKNode node];
        [self addChild:self.scaleNode];
        
        //self.sprite = [SKSpriteNode spriteNodeWithImageNamed:imageName];
        self.sprite = [SKSpriteNode spriteNodeWithImageNamed:imageName];
        [self.scaleNode addChild:self.sprite];
        self.userInteractionEnabled = YES;
        self.zPosition = 10;
        self.label = nil;
        self.highlight = NO;
    }
    return self;
}

- (void)setBackgroundAlpha:(float)alpha {
    [self.sprite setAlpha:alpha];
}

- (void)setBackgroundColor:(UIColor*)color {
    [self.sprite setColorBlendFactor:1.f];
    [self.sprite setColor:color];
}

- (void)setLabelWithText:(NSString*)text color:(UIColor*)color fontSize:(float)fontSize {
    if (self.label == nil) {
        self.label = [SKLabelNode labelNodeWithFontNamed:@"HelveticaNeue"];
        self.label.fontSize = fontSize;
        self.label.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
        [self.scaleNode addChild:self.label];
    }
    [self.label setText:text];
    [self.label setFontColor:color];
}

- (void)setFontColor:(UIColor*)color {
    self.label.fontColor = color;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    SKAction* scale = [SKAction scaleTo:1.3f duration:.05f];
    scale.timingMode = SKActionTimingEaseOut;
    [self.scaleNode runAction:scale];
    self.highlight = YES;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    BOOL isIn = [self.sprite containsPoint:[touch locationInNode:self.sprite]];
    if (!self.highlight && isIn) {
        SKAction* scale = [SKAction scaleTo:1.3f duration:.05f];
        scale.timingMode = SKActionTimingEaseOut;
        [self.scaleNode runAction:scale];
        self.highlight = YES;
    } else if (self.highlight && !isIn) {
        SKAction* scale = [SKAction scaleTo:1.f duration:.1f];
        scale.timingMode = SKActionTimingEaseOut;
        [self.scaleNode runAction:scale];
        self.highlight = NO;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.highlight) {
        SKAction* scale = [SKAction scaleTo:1.f duration:.1f];
        scale.timingMode = SKActionTimingEaseOut;
        [self.scaleNode runAction:scale];
        self.highlight = NO;
        
        if (self.onClick) {
            self.onClick();
        }
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

@end
