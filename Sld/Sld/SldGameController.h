//
//  SldGameController.h
//  Sld
//

//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldEventDetailViewController.h"

enum GameMode{
    PRACTICE,
    BATTLE,
    MATCH,
};

@interface SldGameController : UIViewController
@property (nonatomic, weak) PackInfo* packInfo;
@property (nonatomic) enum GameMode gameMode;
@property (nonatomic) NSString *matchSecret;
@property (nonatomic) Event *event;
@end
