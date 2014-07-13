//
//  SldBetController.m
//  Sld
//
//  Created by 李炜 on 14-7-12.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldBetController.h"
#import "SldGameData.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldNevigationController.h"
#import "SldUtil.h"
#import "SldHttpSession.h"

static float MAX_BAR_WIDTH = 170;


//=================================
@interface TeamBetData : NSObject
@property (nonatomic) NSString *teamName;
@property (nonatomic) int score;
@property (nonatomic) float winMul;
@property (nonatomic) int myBet;
@property (nonatomic) SInt64 betMoney;
@end

@implementation TeamBetData

@end

//=================================
@interface SldBetContainerController ()
@property (weak, nonatomic) IBOutlet UIImageView *bgImageView;
@end

@implementation SldBetContainerController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadBackground];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    //[self loadBackground];
}

- (void)loadBackground{
    NSString *bgKey = [SldGameData getInstance].packInfo.coverBlur;
   
    [_bgImageView asyncLoadImageWithKey:bgKey showIndicator:NO completion:^{
        _bgImageView.alpha = 0.0;
        [UIView animateWithDuration:1.f delay:0 options:UIViewAnimationOptionCurveEaseInOut
            animations:^{
                _bgImageView.alpha = 1.0;
            } completion:nil
        ];
    }];
}

@end

//=============================
@interface SldBetCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *rankLabel;
@property (weak, nonatomic) IBOutlet UILabel *teamLabel;
@property (weak, nonatomic) IBOutlet UIView *scoreBarRaw;
@property (weak, nonatomic) IBOutlet UILabel *scoreLabel;
@property (weak, nonatomic) IBOutlet UIView *winMulBarRaw;
@property (weak, nonatomic) IBOutlet UILabel *winMulLabel;

@property (nonatomic) UIView *scoreBar;
@property (nonatomic) UIView *winMulBar;
@end

@implementation SldBetCell

@end

//=================================
@interface SldBetPopupController : UIViewController
@property (weak, nonatomic) IBOutlet UITextField *betInput;
@property (weak, nonatomic) IBOutlet UILabel *teamNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *betRemainLabel;
@property (weak, nonatomic) NSString *teamName;
@end

@implementation SldBetPopupController

- (void)viewDidLoad {
    [_betInput becomeFirstResponder];
}

- (void)dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onCancelButton:(id)sender {
    [self dismiss];
}

- (IBAction)onBetButton:(id)sender {
    SldGameData *gd = [SldGameData getInstance];
    
    int betMoney = [_betInput.text intValue];
    if (betMoney <= 0 || betMoney > gd.money) {
        alert([NSString stringWithFormat:@"投注额需在（1，%lld）之间", gd.money], nil);
        return;
    }
    
    //post
    NSDictionary *body = @{@"EventId":@(gd.eventInfo.id), @"TeamName":_teamName, @"Money": @(betMoney)};
    SldHttpSession *session = [SldHttpSession defaultSession];
    UIAlertView *alt = alertNoButton(@"提交中...");
    [session postToApi:@"event/bet" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [alt dismissWithClickedButtonIndex:0 animated:YES];
        if (error) {
            NSString *err = getServerErrorType(data);
            if ([err compare:@"err_bet_close"] == 0) {
                alert(@"投注已关闭\n请关注其他正在进行中的比赛", nil);
            } else {
                alertHTTPError(error, data);
            }
            return;
        }
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            alert(@"Json error", [error localizedDescription]);
            return;
        }
        
//        [[SldBetController getInstance] onHttpBetWithDict:dict];
        
        [self dismiss];
    }];
    
}

@end


//=============================
@interface SldBetController ()
@property (weak, nonatomic) IBOutlet UIView *headerView;
@property (weak, nonatomic) IBOutlet UILabel *myCoinLabel;
@property (weak, nonatomic) IBOutlet UILabel *myBetSumLabel;
@property (weak, nonatomic) IBOutlet UILabel *totalBetLabel;
@property (weak, nonatomic) IBOutlet UILabel *myBetTeamNumLabel;
@property (nonatomic) SldGameData *gd;
@property (nonatomic) NSMutableArray *teamBetDatas;
@property (nonatomic) SInt64 maxBetMoney;
@property (nonatomic) int maxScore;
@property (nonatomic) SInt64 totalBetMoney;
@end

@implementation SldBetController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    
    //set tableView inset
    int navBottomY = [SldNevigationController getBottomY];
    self.tableView.contentInset = UIEdgeInsetsMake(navBottomY, 0, 0, 0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(navBottomY, 0, 0, 0);
    
    self.tableView.tableHeaderView = _headerView;
    
    _myCoinLabel.text = [NSString stringWithFormat:@"我的金币：%lld", _gd.money];
    
    //refreshControl
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(updateDatas) forControlEvents:UIControlEventValueChanged];
    refreshControl.tintColor = [UIColor whiteColor];
    self.refreshControl = refreshControl;
    
    //
    _teamBetDatas = [NSMutableArray array];
    for (NSString *teamName in _gd.TEAM_NAMES) {
        TeamBetData *data = [[TeamBetData alloc] init];
        data.teamName = teamName;
        [_teamBetDatas addObject:data];
    }
    
    [self updateDatas];
}

- (void)updateDatas {
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"EventId":@(_gd.eventInfo.id)};
    [session postToApi:@"event/getBettingPool" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        [self.refreshControl endRefreshing];
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        //bettingPool
        NSDictionary *bettingPoolDict = [dict objectForKey:@"BettingPool"];
        
        //set bet money and calc totalBetMoney
        _totalBetMoney = 0;
        _maxBetMoney = 0;
        for (TeamBetData *data in _teamBetDatas) {
            NSNumber *betMoney = [bettingPoolDict objectForKey:data.teamName];
            if (betMoney) {
                data.betMoney = [betMoney longLongValue];
                _totalBetMoney += data.betMoney;
                if (data.betMoney > _maxBetMoney) {
                    _maxBetMoney = data.betMoney;
                }
            }
        }
        
        //calc winMul
        for (TeamBetData *data in _teamBetDatas) {
            NSNumber *betMoney = [bettingPoolDict objectForKey:data.teamName];
            if (betMoney) {
                data.winMul = (float)_totalBetMoney / [betMoney floatValue];
            }
        }
        
        //team scores
        _maxScore = 0;
        NSDictionary *teamScoreDict = [dict objectForKey:@"TeamScores"];
        
        for (TeamBetData *data in _teamBetDatas) {
            NSNumber *nScore = [teamScoreDict objectForKey:data.teamName];
            if (nScore) {
                data.score = [nScore intValue];
                if (data.score > _maxScore) {
                    _maxScore = data.score;
                }
            }
        }
        
        //resort
        [_teamBetDatas sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            TeamBetData *td1 = obj1;
            TeamBetData *td2 = obj2;
            if (td1.score < td2.score) {
                return NSOrderedDescending;
            } else if (td1.score > td2.score) {
                return NSOrderedAscending;
            } else {
                return NSOrderedSame;
            }
        }];
        
        //update ui
        _totalBetLabel.text = [NSString stringWithFormat:@"奖池总额：%lld", _totalBetMoney];
        
        _myBetSumLabel.text = [NSString stringWithFormat:@"投注金额：%lld", _gd.eventPlayRecord.BetMoneySum];
        
        _myBetTeamNumLabel.text = [NSString stringWithFormat:@"已买队伍：%d", _gd.eventPlayRecord.bet.count];
        
        //
        [self.tableView reloadData];
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _teamBetDatas.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SldBetCell *cell = [tableView dequeueReusableCellWithIdentifier:@"betCell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    TeamBetData *data = [_teamBetDatas objectAtIndex:indexPath.row];
    cell.teamLabel.text = data.teamName;
    cell.rankLabel.text = [NSString stringWithFormat:@"%d", indexPath.row+1];
    
    cell.winMulLabel.text = [NSString stringWithFormat:@"赔率：%.2f", data.winMul];
    cell.scoreLabel.text = [NSString stringWithFormat:@"积分：%d", data.score];
    
    if (cell.scoreBar == nil) {
        cell.scoreBar = [[UIView alloc] initWithFrame:cell.scoreBarRaw.frame];
        cell.scoreBarRaw.hidden = YES;
        cell.scoreBar.backgroundColor = cell.scoreBarRaw.backgroundColor;
        [cell.contentView addSubview:cell.scoreBar];
    }
    
    if (cell.winMulBar == nil) {
        cell.winMulBar = [[UIView alloc] initWithFrame:cell.winMulBarRaw.frame];
        cell.winMulBarRaw.hidden = YES;
        cell.winMulBar.backgroundColor = cell.winMulBarRaw.backgroundColor;
        [cell.contentView addSubview:cell.winMulBar];
    }
    
    if (_maxBetMoney > 0) {
        float width = (float)(data.betMoney)/(float)_maxBetMoney * MAX_BAR_WIDTH;
        CGRect frame = cell.winMulBar.frame;
        frame.size.width = width;
        cell.winMulBar.frame = frame;
    }
    CGRect frame = cell.winMulBar.frame;
    if (data.winMul == 0){
        frame.size.width = 2;
        cell.winMulBar.frame = frame;
    }
    
    if (_maxScore > 0) {
        float width = (float)(data.score)/(float)_maxScore * MAX_BAR_WIDTH;
        CGRect frame = cell.scoreBar.frame;
        frame.size.width = width;
        cell.scoreBar.frame = frame;
    }
    frame = cell.scoreBar.frame;
    if (data.score == 0) {
        frame.size.width = 2;
        cell.scoreBar.frame = frame;
    }
    
    return cell;
}

//- (UITableViewHeaderFooterView *)headerViewForSection:(NSInteger)section {
//    if (section == 0) {
//        return _headerView;
//    }
//    return nil;
//}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
