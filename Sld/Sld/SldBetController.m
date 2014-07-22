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
#import "MSWeakTimer.h"

static float MAX_BAR_WIDTH = 170;
static SldBetController* _betController = nil;

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

static TeamBetData *_selectedTeamBetData = nil;

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
@property (weak, nonatomic) IBOutlet UILabel *myBetLabel;
@property (weak, nonatomic) IBOutlet UIButton *betButton;

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
@end

@implementation SldBetPopupController

- (void)viewDidLoad {
    [_betInput becomeFirstResponder];
    
    _teamNameLabel.text = [NSString stringWithFormat:@"已投%@%d金币", _selectedTeamBetData.teamName, _selectedTeamBetData.myBet];
    
    SldGameData *gd = [SldGameData getInstance];
    _betRemainLabel.text = [NSString stringWithFormat:@"(1-%lld)", gd.playerInfo.money];
    
}

- (void)dismiss {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)onCancelButton:(id)sender {
    [self dismiss];
}

- (IBAction)onBetButton:(id)sender {
    SldGameData *gd = [SldGameData getInstance];
    
    int betMoney = [_betInput.text intValue];
    if (betMoney <= 0 || betMoney > gd.playerInfo.money) {
        alert([NSString stringWithFormat:@"投注额需在（1，%lld）之间", gd.playerInfo.money], nil);
        return;
    }
    
    //post
    NSDictionary *body = @{@"EventId":@(gd.eventInfo.id), @"TeamName":_selectedTeamBetData.teamName, @"Money": @(betMoney)};
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
        
        SldGameData *gd = [SldGameData getInstance];
        NSString *teamName = [dict objectForKey:@"TeamName"];
        SInt64 betMoney = [(NSNumber*)[dict objectForKey:@"BetMoney"] longLongValue];
        SInt64 betMoneySum = [(NSNumber*)[dict objectForKey:@"BetMoneySum"] longLongValue];
        SInt64 userMoney = [(NSNumber*)[dict objectForKey:@"UserMoney"] longLongValue];
        
        gd.eventPlayRecord.BetMoneySum = betMoneySum;
        gd.playerInfo.money = userMoney;
        [gd.eventPlayRecord.bet setObject:@(betMoney) forKey:teamName];

        [_betController updateDatas];
        
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
@property (weak, nonatomic) IBOutlet UILabel *timeRemainLabel;
@property (weak, nonatomic) IBOutlet UILabel *rewardLabel;
@property (nonatomic) SldGameData *gd;
@property (nonatomic) NSMutableArray *teamBetDatas;
@property (nonatomic) float maxWinMul;
@property (nonatomic) int maxScore;
@property (nonatomic) SInt64 totalBetMoney;
@property (nonatomic) MSWeakTimer *timer;
@property (nonatomic) BOOL betClosed;
@end

@implementation SldBetController

-(void)dealloc {
    [_timer invalidate];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _betController = self;
    
    _gd = [SldGameData getInstance];
    
    //set tableView inset
    int navBottomY = [SldNevigationController getBottomY];
    self.tableView.contentInset = UIEdgeInsetsMake(navBottomY, 0, 0, 0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(navBottomY, 0, 0, 0);
    
    self.tableView.tableHeaderView = _headerView;
    
    _myCoinLabel.text = [NSString stringWithFormat:@"我的金币：%lld", _gd.playerInfo.money];
    
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
    
    //timer
    _timer = [MSWeakTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(onTimer) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
    
    [self onTimer];
    
    [self updateDatas];
}

- (void)onTimer {
    NSTimeInterval endIntv = [_gd.eventInfo.betEndTime timeIntervalSinceNow];
    if (_gd.eventInfo.hasResult || endIntv <= 0) {
        if (!_betClosed) {
            _betClosed = YES;
            _timeRemainLabel.text = @"投注已结束";
            [self.tableView reloadData];
        }
    } else {
        NSString *str = formatInterval((int)endIntv);
        _timeRemainLabel.text = [NSString stringWithFormat:@"剩余时间：%@", str];
    }
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
        for (TeamBetData *data in _teamBetDatas) {
            NSNumber *betMoney = [bettingPoolDict objectForKey:data.teamName];
            if (betMoney) {
                data.betMoney = [betMoney longLongValue];
                _totalBetMoney += data.betMoney;
            }
        }
        
        //calc winMul
        _maxWinMul = 0.0;
        for (TeamBetData *data in _teamBetDatas) {
            NSNumber *betMoney = [bettingPoolDict objectForKey:data.teamName];
            if (betMoney) {
                data.winMul = (float)_totalBetMoney / [betMoney floatValue];
                if (data.winMul > _maxWinMul) {
                    _maxWinMul = data.winMul;
                }
            }
        }
        
        //team scores and my bet
        _maxScore = 0;
        NSDictionary *teamScoreDict = [dict objectForKey:@"TeamScores"];
        NSDictionary *myBetDict = _gd.eventPlayRecord.bet;
        for (TeamBetData *data in _teamBetDatas) {
            //score
            NSNumber *nScore = [teamScoreDict objectForKey:data.teamName];
            if (nScore) {
                data.score = [nScore intValue];
                if (data.score > _maxScore) {
                    _maxScore = data.score;
                }
            }
            
            //my bet money
            NSNumber *myBet = [myBetDict objectForKey:data.teamName];
            if (myBet) {
                data.myBet = [myBet intValue];
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
        [self updateUI];
    }];
}

- (void)updateUI {
    _totalBetLabel.text = [NSString stringWithFormat:@"奖池总额：%lld", _totalBetMoney];
    _myBetSumLabel.text = [NSString stringWithFormat:@"已投金额：%lld", _gd.eventPlayRecord.BetMoneySum];
    _myBetTeamNumLabel.text = [NSString stringWithFormat:@"已投队伍：%d", _gd.eventPlayRecord.bet.count];
    
    SInt64 reward = _gd.eventPlayRecord.betReward;
    if (reward > 0) {
        _rewardLabel.text = [NSString stringWithFormat:@"获得奖金：%lld", reward];
        _rewardLabel.hidden = NO;
    } else {
        _rewardLabel.hidden = YES;
    }
    
    
    [self.tableView reloadData];
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
    
    if (_maxWinMul > 0.0) {
        float width = (float)(data.winMul)/(float)_maxWinMul * MAX_BAR_WIDTH;
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
    
    //
    if (data.myBet > 0) {
        cell.myBetLabel.hidden = NO;
        cell.myBetLabel.text = [NSString stringWithFormat:@"已投%d", data.myBet];
        [cell.betButton setTitle:@"加注" forState:UIControlStateNormal];
    } else {
        cell.myBetLabel.hidden = YES;
        [cell.betButton setTitle:@"投注" forState:UIControlStateNormal];
    }
    
    //button
    if (_betClosed) {
        [cell.betButton setTitle:@"已结束" forState:UIControlStateNormal|UIControlStateDisabled];
        cell.betButton.enabled = NO;
    } else if (data.winMul > 0) {
        cell.betButton.enabled = YES;
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


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier compare:@"toBetPopupSeg"] == 0) {
        CGPoint buttonPosition = [sender convertPoint:CGPointZero toView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:buttonPosition];
        
        _selectedTeamBetData = [_teamBetDatas objectAtIndex:indexPath.row];
    }
}

@end

@interface SldBetHelpController : UIViewController
@property (weak, nonatomic) IBOutlet UITextView *textView;

@end

static NSString *_betHelpString = nil;

@implementation SldBetHelpController
-(void)viewDidLoad {
    if (_betHelpString == nil) {
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session postToApi:@"etc/betHelp" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                return;
            }
            _betHelpString = [dict objectForKey:@"Text"];
            _textView.text = _betHelpString;
        }];
    } else {
        _textView.text = _betHelpString;
    }
}

@end


