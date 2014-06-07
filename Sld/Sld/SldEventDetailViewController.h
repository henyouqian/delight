//
//  SldEventDetailViewController.h
//  Sld
//
//  Created by Wei Li on 14-4-24.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SldEventListViewController.h"

@interface SldEventDetailViewController : UIViewController<UIAlertViewDelegate>
@property (nonatomic) int highScore;
@property (nonatomic) int rank;
@property (nonatomic) NSString *highScoreStr;
@property (nonatomic) NSString *rankStr;

+ (instancetype)getInstance;
- (void)updatePlayRecordWithHighscore;
@end


@interface SldGameCoinBuyController : UIViewController<UIPickerViewDelegate, UIPickerViewDataSource>
@property (nonatomic) NSArray *strings;
@end