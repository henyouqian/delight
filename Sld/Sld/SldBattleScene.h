//
//  SldBattleScene.h
//  Sld
//
//  Created by Wei Li on 14-4-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

//#import "SldEventDetailViewController.h"
#import "SldGameController.h"
#import "SldSprite.h"

//==============================
@interface SldBattleSceneController : UIViewController
@property (nonatomic) SldSprite* firstSprite;
@property (nonatomic) int firstIndex;
@end

//==============================
@interface SldBattleScene : SKScene<SKStoreProductViewControllerDelegate, SRWebSocketDelegate>
@property (weak, nonatomic) UINavigationController *navigationController;
@property (weak, nonatomic) SldBattleSceneController *controller;
@property (nonatomic) uint32_t sliderNum;

- (instancetype)initWithSize:(CGSize)size controller:(SldBattleSceneController*)controller firstSprite:(SldSprite*)spt;

@end



