//
//  SldGameScene.h
//  Sld
//
//  Created by Wei Li on 14-4-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldEventDetailViewController.h"
#import "SldGamePlay.h"

@interface SldGameScene : SKScene
@property (nonatomic, weak) PackInfo* packInfo;
@property (strong, nonatomic) SldGamePlay *gamePlay;
@property (weak, nonatomic) UINavigationController *navigationController;

+ (instancetype)sceneWithSize:(CGSize)size packInfo:(PackInfo*)packInfo;
- (instancetype)initWithSize:(CGSize)size packInfo:(PackInfo*)packInfo;
@end
