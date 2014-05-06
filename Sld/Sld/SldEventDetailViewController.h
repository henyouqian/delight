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
@property (nonatomic) NSNumber *highScore;
@property (nonatomic) NSNumber *rank;
@property (nonatomic) NSString *highScoreStr;
@property (nonatomic) NSString *rankStr;

+ (instancetype)getInstance;
- (void)setPlayRecordWithHighscore:(NSNumber*)highscore rank:(NSNumber*)rank rankNum:(NSNumber*)rankNum;
@end


