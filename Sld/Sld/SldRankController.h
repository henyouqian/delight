//
//  SldRankController.h
//  Sld
//
//  Created by Wei Li on 14-5-4.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SldRankController : UIViewController<UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

+ (instancetype)getInstance;
- (void)onViewShown;
- (void)updateRanks;

@end
