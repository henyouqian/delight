//
//  SldBattleScene.h
//  Sld
//
//  Created by Wei Li on 14-4-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

//#import "SldEventDetailViewController.h"
#import "SldGameController.h"

//==============================
@interface SldBattleSceneController : UIViewController
@end

//==============================
@interface SldBattleScene : SKScene<SKStoreProductViewControllerDelegate>
@property (weak, nonatomic) UINavigationController *navigationController;
@property (weak, nonatomic) SldBattleSceneController *controller;
@property (nonatomic) uint32_t sliderNum;

+ (instancetype)sceneWithSize:(CGSize)size controller:(SldBattleSceneController*)controller;
- (instancetype)initWithSize:(CGSize)size controller:(SldBattleSceneController*)controller;

@end



