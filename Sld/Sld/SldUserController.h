//
//  SldUserController.h
//  Sld
//
//  Created by Wei Li on 14-5-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SldUserController : UITableViewController
+ (instancetype)getInstance;
- (void)updateUI;
- (void)updateMoney;
@end
