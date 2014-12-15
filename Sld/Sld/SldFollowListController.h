//
//  SldFollowListController.h
//  pin
//
//  Created by 李炜 on 14/12/15.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PlayerInfo;

@interface SldFollowListController : UITableViewController
@property PlayerInfo *playerInfo;
@property bool follow; //true:follow false:fans
@end
