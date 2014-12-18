//
//  SldMatchPageController.h
//  pin
//
//  Created by 李炜 on 14/12/9.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Match;
@class PackInfo;
@class MatchPlay;

@interface SldMatchPageController : UITableViewController
@property Match *match;
@property PackInfo *packInfo;
@property MatchPlay *matchPlay;
- (void)openPhotoBrowser:(int)imageIndex;
- (void)enterGame;
@end
