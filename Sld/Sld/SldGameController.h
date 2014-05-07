//
//  SldGameController.h
//  Sld
//

//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldEventDetailViewController.h"

enum GameMode{
    PRACTICE,
    //BATTLE,
    MATCH,
};

@interface SldGameController : UIViewController
@property (nonatomic) enum GameMode gameMode;
@property (nonatomic) NSString *matchSecret;
@end
