//
//  SldBetController.m
//  Sld
//
//  Created by Wei Li on 14-5-4.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldBetController.h"
//#import "SldEventDetailViewController.h"
#import "SldGameData.h"
#import "SldHttpSession.h"
#import "SldNevigationController.h"
#import "config.h"
#import "SldUtil.h"
#import "UIImageView+sldAsyncLoad.h"

@interface BettingTeam : NSObject
@property (nonatomic) NSString *teamName;
@property (nonatomic) int score;
@property (nonatomic) SInt64 betMoney;
@property (nonatomic) float winMul;
@end

@implementation BettingTeam
@end

//========================
@interface TeamScoreCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *teamLabel;
@property (weak, nonatomic) IBOutlet UILabel *scoreLabel;
@property (weak, nonatomic) IBOutlet UILabel *winMulLabel;

@end

@implementation TeamScoreCell

@end


//========================
@interface SldBetController ()
@property (nonatomic) UITableViewController *tableViewController;
@property (nonatomic) IBOutlet UIView *headerView;
@property (nonatomic) NSMutableArray *bettingTeams;
@end

static SldBetController *_inst = nil;

@implementation SldBetController

+ (instancetype)getInstance {
    return _inst;
}

- (void)dealloc {
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _inst = self;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    
    //set tableView inset
    int navBottomY = [SldNevigationController getBottomY];
    _tableView.contentInset = UIEdgeInsetsMake(navBottomY, 0, 100, 0);
    _tableView.scrollIndicatorInsets = UIEdgeInsetsMake(navBottomY, 0, 100, 0);
    _tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    //refreshControl
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(updateTeamScore) forControlEvents:UIControlEventValueChanged];
    refreshControl.tintColor = [UIColor whiteColor];
    
    _tableViewController = [[UITableViewController alloc] init];
    _tableViewController.tableView = _tableView;
    _tableViewController.refreshControl = refreshControl;
    _tableViewController.clearsSelectionOnViewWillAppear = YES;
    [self addChildViewController:_tableViewController];
    
    [self updateTeamScore];
}

- (void)onViewShown {
    //[_tableView reloadData];
}

- (void)onHttpBetWithDict:(NSDictionary*)dict {
    SldGameData *gd = [SldGameData getInstance];
    
    NSString *teamName = [dict objectForKey:@"TeamName"];
    SInt64 betMoney = [(NSNumber*)[dict objectForKey:@"BetMoney"]longLongValue];
    SInt64 betMoneySum = [(NSNumber*)[dict objectForKey:@"BetMoneySum"] longLongValue];
    SInt64 userMoney = [(NSNumber*)[dict objectForKey:@"UserMoney"] longLongValue];
    
    for (int i = 0; i < _bettingTeams.count; ++i) {
        BettingTeam *bt = (BettingTeam*)_bettingTeams[i];
        if ([teamName compare:bt.teamName] == 0) {
            bt.betMoney = betMoney;
            gd.eventPlayRecord.BetMoneySum = betMoneySum;
            gd.money = userMoney;
            
            NSIndexPath *path = [NSIndexPath indexPathForRow:i inSection:0];
            NSArray* rowsToReload = [NSArray arrayWithObjects:path, nil];
            [_tableView reloadRowsAtIndexPaths:rowsToReload withRowAnimation:UITableViewRowAnimationAutomatic];
            
            return;
        }
    }
}

- (void)updateTeamScore {
    SldGameData *gd = [SldGameData getInstance];
    NSDictionary *body = @{@"EventId":@(gd.eventInfo.id)};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"event/getBettingPool" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        [_tableViewController.refreshControl endRefreshing];
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            alert(@"Json error", [error localizedDescription]);
            return;
        }
        
        NSDictionary *bettingPool = [dict objectForKey:@"BettingPool"];
        NSDictionary *teamScores = [dict objectForKey:@"TeamScores"];
        
        NSMutableDictionary *bettingDict = [NSMutableDictionary dictionary];
        int betSum = 0;
        
        for (NSString* teamName in gd.TEAM_NAMES) {
            BettingTeam *bt = [[BettingTeam alloc] init];
            bt.teamName = teamName;
            bettingDict[teamName] = bt;
        }
        
//        for (id key in bettingPool) {
//            BettingTeam *bt = [[BettingTeam alloc] init];
//            bt.teamName = (NSString*)key;
//            bt.betMoney = [(NSNumber*)bettingPool[key] longLongValue];
//            bettingDict[key] = bt;
//            betSum += bt.betMoney;
//        }
//        for (id key in bettingPool) {
//            BettingTeam *bt = bettingDict[key];
//            bt.winMul = (float)betSum / bt.betMoney;
//            bettingDict[key] = bt;
//        }
        
        for (NSString *teamName in teamScores) {
            BettingTeam *bt = [bettingDict objectForKey:teamName];
            if (bt) {
                bt.score = [(NSNumber*)teamScores[teamName] intValue];
                bettingDict[teamName] = bt;
            }
        }
        
        _bettingTeams = [NSMutableArray array];
        for (NSString *teamName in gd.TEAM_NAMES) {
            [_bettingTeams addObject:bettingDict[teamName]];
        }
                
        [_tableView reloadData];
    }];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _bettingTeams.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TeamScoreCell *cell = [tableView dequeueReusableCellWithIdentifier:@"teamScoreCell" forIndexPath:indexPath];
    if (indexPath.row < _bettingTeams.count) {
        BettingTeam *bt = _bettingTeams[indexPath.row];
        cell.teamLabel.text = bt.teamName;
        cell.scoreLabel.text = [NSString stringWithFormat:@"%d", bt.score];
        cell.winMulLabel.text = [NSString stringWithFormat:@"%.2f", bt.winMul];
    }
    cell.backgroundColor = [UIColor clearColor];
    return cell;
}

//- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
//{
//    NSString *sectionName;
//    switch (section)
//    {
//        case 0:
//            sectionName = NSLocalizedString(@"Team rank", @"team rank");
//            break;
//        default:
//            sectionName = @"";
//            break;
//    }
//    return sectionName;
//}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
//    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 30)];
//    /* Create custom view to display section header... */
//    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, tableView.frame.size.width, 18)];
//    [label setFont:[UIFont boldSystemFontOfSize:12]];
//    NSString *string =@"xxxxxxx";
//    /* Section header is in 0th index... */
//    [label setText:string];
//    [view addSubview:label];
//    [view setBackgroundColor:[UIColor colorWithRed:166/255.0 green:177/255.0 blue:186/255.0 alpha:1.0]]; //your background color...
//    return view;
    return _headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return _headerView.frame.size.height;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SldGameData *gd = [SldGameData getInstance];
    
    enum EventState state = [gd.eventInfo updateState];
    
    //bet time check
    NSTimeInterval endIntv = [gd.eventInfo.endTime timeIntervalSinceNow];
    if (state != RUNNING || (int)endIntv <= gd.betCloseBeforeEndSec) {
        NSString *str = [NSString stringWithFormat:@"投注已结束，请在距离比赛结束%@前投注", formatInterval(gd.betCloseBeforeEndSec)];
        alert(str, nil);
        [_tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    //
    SldBetPopupController* vc = (SldBetPopupController*)[getStoryboard() instantiateViewControllerWithIdentifier:@"betPopup"];

    [self.navigationController presentViewController:vc animated:YES completion:nil];
    
    BettingTeam *bt = _bettingTeams[indexPath.row];
    
    NSDictionary *betMap = gd.eventPlayRecord.bet;
    int alreadyBet = [(NSNumber*)[betMap objectForKey:bt.teamName] intValue];

    vc.teamNameLabel.text = [NSString stringWithFormat:@"%@  已投注%d金币", bt.teamName, alreadyBet];
    vc.betRemainLabel.text = [NSString stringWithFormat:@"(1-%lld)", gd.money];
    vc.teamName = bt.teamName;
}

@end

//====================
@interface SldBetPopupController()

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
        
        [[SldBetController getInstance] onHttpBetWithDict:dict];
        
        [self dismiss];
    }];

}

@end
