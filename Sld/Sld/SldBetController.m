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
#import "util.h"
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

@implementation SldBetController

- (void)dealloc {
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
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
    
    [self updateTeamScore];
}

- (void)onViewShown {
    //[_tableView reloadData];
}

- (void)updateTeamScore {
    SldGameData *gd = [SldGameData getInstance];
    NSDictionary *body = @{@"EventId":@(gd.eventInfo.id)};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"event/getBettingPool" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [_tableViewController.refreshControl endRefreshing];
        if (error) {
            //alertHTTPError(error, data);
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
        for (id key in bettingPool) {
            BettingTeam *bt = [[BettingTeam alloc] init];
            bt.teamName = (NSString*)key;
            bt.betMoney = [(NSNumber*)bettingPool[key] longLongValue];
            bettingDict[key] = bt;
            betSum += bt.betMoney;
        }
        for (id key in bettingPool) {
            BettingTeam *bt = bettingDict[key];
            bt.winMul = (float)betSum / bt.betMoney;
            bettingDict[key] = bt;
        }
        
        for (id key in teamScores) {
            BettingTeam *bt = [bettingDict objectForKey:key];
            if (bt) {
                bt.score = [(NSNumber*)teamScores[key] intValue];
                bettingDict[key] = bt;
            }
        }
        
        _bettingTeams = [NSMutableArray array];
        for (id key in bettingDict) {
            [_bettingTeams addObject:bettingDict[key]];
        }
        
        [_bettingTeams sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            BettingTeam* bt1 = (BettingTeam*)obj1;
            BettingTeam* bt2 = (BettingTeam*)obj2;
            return [bt1.teamName localizedCompare:bt2.teamName];
        }];
        
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

@end
