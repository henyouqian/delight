//
//  SldGameScene.h
//  Sld
//
//  Created by Wei Li on 14-4-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

//#import "SldEventDetailViewController.h"
#import "SldGameController.h"

//============================
@interface Slider : SKSpriteNode
@property (nonatomic) NSUInteger idx;
@property (nonatomic) UITouch *touch;
@end


//============================
@interface SldGameScene : SKScene<SKStoreProductViewControllerDelegate>
@property (weak, nonatomic) UINavigationController *navigationController;
@property (weak, nonatomic) SldGameController *gameController;
@property (nonatomic) uint32_t sliderNum;

+ (instancetype)sceneWithSize:(CGSize)size controller:(SldGameController*)controller;
- (instancetype)initWithSize:(CGSize)size controller:(SldGameController*)controller;

@end

