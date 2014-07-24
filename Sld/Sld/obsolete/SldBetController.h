//
//  SldBetController.h
//  Sld
//
//  Created by Wei Li on 14-5-4.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SldBetController : UIViewController<UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

+ (instancetype)getInstance;
- (void)updateTeamScore;
- (void)onViewShown;
- (void)onHttpBetWithDict:(NSDictionary*)dict;

@end

//=======================
@interface SldBetPopupController : UIViewController
@property (weak, nonatomic) IBOutlet UITextField *betInput;
@property (weak, nonatomic) IBOutlet UILabel *teamNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *betRemainLabel;
@property (weak, nonatomic) NSString *teamName;
@end
