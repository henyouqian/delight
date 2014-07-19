//
//  SldUserController.m
//  Sld
//
//  Created by Wei Li on 14-5-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldUserController.h"
#import "SldUserInfoController.h"
#import "SldLoginViewController.h"
#import "SldHttpSession.h"
#import "config.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldGameData.h"
#import "SldUtil.h"

@interface SldUserController ()
@property (weak, nonatomic) IBOutlet UITableViewCell *logoutCell;
@property (weak, nonatomic) IBOutlet UIImageView *avatarView;
@property (weak, nonatomic) IBOutlet UILabel *nickNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *teamLabel;
@property (weak, nonatomic) IBOutlet UILabel *genderLabel;
@property (weak, nonatomic) IBOutlet UILabel *moneyLabel;
@property (weak, nonatomic) IBOutlet UILabel *totalRewardLabel;
@property (weak, nonatomic) IBOutlet UILabel *levelLabel;
@property (weak, nonatomic) IBOutlet UILabel *rewardLabel;
@property (weak, nonatomic) IBOutlet UITableViewCell *userInfoCell;

@end

static __weak SldUserController *g_inst = nil;

@implementation SldUserController

+ (instancetype)getInstance {
    return g_inst;
}

- (void)viewDidLoad
{
    g_inst = self;
    [super viewDidLoad];
    
    self.clearsSelectionOnViewWillAppear = YES;
    SldGameData *gd = [SldGameData getInstance];
    
    //
    if (!gd.online) {
        [SldLoginViewController createAndPresentWithCurrentController:self animated:YES];
        return;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    SldGameData *gamedata = [SldGameData getInstance];

    //avatar
    [SldUtil loadAvatar:_avatarView gravatarKey:gamedata.gravatarKey customAvatarKey:gamedata.customAvatarKey];
    
    //nickname
    _nickNameLabel.text = gamedata.nickName;
    
    //team
    _teamLabel.text = gamedata.teamName;
    
    //gender
    if (gamedata.gender == 1) {
        _genderLabel.text = @"🚹";
        _genderLabel.textColor = makeUIColor(0, 122, 255, 255);
    } else if (gamedata.gender == 0) {
        _genderLabel.text = @"🚺";
        _genderLabel.textColor = makeUIColor(244, 75, 116, 255);
    } else {
        _genderLabel.text = @"㊙";
        _genderLabel.textColor = makeUIColor(128, 128, 128, 255);
    }
    
    [self updateMoney];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if (cell == _userInfoCell) {
        [SldUserInfoController createAndPresentFromController:self cancelable:YES];
    }
}

- (IBAction)onLogoutButton:(id)sender {
    RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:@"否" action:nil];
    
	RIButtonItem *logoutItem = [RIButtonItem itemWithLabel:@"是" action:^{
		[[SldHttpSession defaultSession] logoutWithComplete:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                Config *conf = [Config sharedConf];
                NSArray *accounts = [SSKeychain accountsForService:conf.KEYCHAIN_SERVICE];
                NSString *username = [accounts lastObject][@"acct"];
                [SSKeychain setPassword:@"" forService:conf.KEYCHAIN_SERVICE account:username];
                [SldLoginViewController createAndPresentWithCurrentController:self animated:YES];
                
                SldGameData *gd = [SldGameData getInstance];
                [gd reset];
            });
        }];
	}];
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"注销当前账号吗?"
	                                                    message:nil
											   cancelButtonItem:cancelItem
											   otherButtonItems:logoutItem, nil];
	[alertView show];
}


#pragma mark - Table view data source

//- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
//{
//    return 0;
//}
//
//- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
//{
//    return 0;
//}

/*
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:<#@"reuseIdentifier"#> forIndexPath:indexPath];
    
    // Configure the cell...
    
    return cell;
}
*/

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



- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.destinationViewController isKindOfClass:[SldEventResultController class]]) {
        ((SldEventResultController*)segue.destinationViewController).userController = self;
    }
}

- (void)updateMoney {
    SldGameData *gd = [SldGameData getInstance];
    _moneyLabel.text = [NSString stringWithFormat:@"%lld", gd.money];
    _rewardLabel.text = [NSString stringWithFormat:@"可领取奖金%lld", gd.rewardCache];
    _totalRewardLabel.text = [NSString stringWithFormat:@"%lld", gd.totalReward];
    _levelLabel.text = [NSString stringWithFormat:@"%d", gd.level];
}

@end

//=================
@interface SldGetRewardCacheCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIButton *getRewardButton;
@end

@implementation SldGetRewardCacheCell
@end

//=================
@interface SldEventResultCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *rankLabel;
@property (weak, nonatomic) IBOutlet UILabel *matchRewardLabel;
@property (weak, nonatomic) IBOutlet UILabel *betMoneyLabel;
@property (weak, nonatomic) IBOutlet UILabel *betRewardLabel;
@property (weak, nonatomic) IBOutlet UIImageView *packThumbView;

@end

@implementation SldEventResultCell
@end

//=================
@interface SldEventResultFooterView: UIView
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@end

@implementation SldEventResultFooterView
@end


//=================
@interface SldEventResult : NSObject
@property (nonatomic) int eventId;
@property (nonatomic) NSString* thumbKey;
@property (nonatomic) int rank;
@property (nonatomic) int matchReward;
@property (nonatomic) int betMoneySum;
@property (nonatomic) int betReward;

- (instancetype)initWithDict:(NSDictionary*)dict;
@end

@implementation SldEventResult
- (instancetype)initWithDict:(NSDictionary*)dict {
    if (self = [super init]) {
        _eventId = [(NSNumber*)[dict objectForKey:@"EventId"] intValue];
        _thumbKey = [dict objectForKey:@"PackThumbKey"];
        _rank = [(NSNumber*)[dict objectForKey:@"FinalRank"] intValue];
        _matchReward = [(NSNumber*)[dict objectForKey:@"MatchReward"] intValue];
        _betMoneySum = [(NSNumber*)[dict objectForKey:@"BetMoneySum"] intValue];
        _betReward = [(NSNumber*)[dict objectForKey:@"BetReward"] intValue];
    }
    return self;
}
@end

//=================
@interface SldEventResultController()
@property (nonatomic) NSMutableArray *eventResults; //SldEventResult
@property (weak, nonatomic) IBOutlet SldEventResultFooterView *footerView;
@property (nonatomic) BOOL reachBottom;
@property (nonatomic) BOOL loadingData;
@end

const int RESULT_LIMIT = 20;

@implementation SldEventResultController

- (void)viewDidLoad {
    _reachBottom = NO;
    
    //footer
    self.tableView.tableFooterView = _footerView;
    _footerView.spinner.hidden = YES;
    
    //refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.tableView addSubview:self.refreshControl];
    [self.refreshControl addTarget:self action:@selector(refershList) forControlEvents:UIControlEventValueChanged];
    
    [self refershList];
}

- (void)refershList {
    if (_loadingData) {
        [self.refreshControl endRefreshing];
        return;
    }
    //get play result
    _loadingData = YES;
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"StartEventId":@0, @"Limit":@(RESULT_LIMIT)};
    [session postToApi:@"event/listPlayResult" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        _loadingData = NO;
        [self.refreshControl endRefreshing];
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSArray *records = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        _eventResults = [NSMutableArray array];
        for (NSDictionary *record in records) {
            SldEventResult *result = [[SldEventResult alloc] initWithDict:record];
            [_eventResults addObject:result];
        }
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return 1;
    } else if (section == 1) {
        return _eventResults.count;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SldGameData *gd = [SldGameData getInstance];
    
    if (indexPath.section == 0) {
        SldGetRewardCacheCell *cell = (SldGetRewardCacheCell*)[tableView dequeueReusableCellWithIdentifier:@"rewardCacheCell" forIndexPath:indexPath];
        
        NSString *title = [NSString stringWithFormat:@"领取奖金：%lld", gd.rewardCache];
        [cell.getRewardButton setTitle:title forState:(UIControlStateNormal&UIControlStateHighlighted&UIControlStateDisabled)];
        if (gd.rewardCache == 0) {
            cell.getRewardButton.enabled = NO;
            cell.getRewardButton.backgroundColor = [UIColor lightGrayColor];
        } else {
            cell.getRewardButton.enabled = YES;
            cell.getRewardButton.backgroundColor = makeUIColor(244, 75, 116, 255);
        }
        return cell;
    } else if (indexPath.section == 1) {
        SldEventResultCell *cell = [tableView dequeueReusableCellWithIdentifier:@"matchResultCell" forIndexPath:indexPath];
        
        SldEventResult *er = [_eventResults objectAtIndex:indexPath.row];
        cell.rankLabel.text = [NSString stringWithFormat:@"名次：%d", er.rank];
        cell.matchRewardLabel.text = [NSString stringWithFormat:@"奖金：%d", er.matchReward];
        cell.betMoneyLabel.text = [NSString stringWithFormat:@"投注：%d", er.betMoneySum];
        cell.betRewardLabel.text = [NSString stringWithFormat:@"奖金：%d", er.betReward];
        [cell.packThumbView asyncLoadImageWithKey:er.thumbKey showIndicator:NO completion:nil];
        return cell;
    }
    
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 44;
    } else if (indexPath.section == 1) {
        return 60;
    }
    return 44;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 20;
}

- (IBAction)onGetReward:(id)sender {
    UIAlertView *alt = alertNoButton(@"领取中...");
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"player/addRewardFromCache" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [alt dismissWithClickedButtonIndex:0 animated:YES];
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        SldGameData *gd = [SldGameData getInstance];
        SInt64 prevMoney = gd.money;
        gd.money = [(NSNumber*)[dict objectForKey:@"Money"] longLongValue];
        gd.rewardCache = 0;
        
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
        
        [_userController updateMoney];
        
        alert(@"金币领取成功", [NSString stringWithFormat:@"%lld + %lld = %lld", prevMoney, gd.money-prevMoney, gd.money]);
    }];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (_eventResults.count == 0 || _reachBottom || _loadingData) {
        return;
    }
    
    if ((scrollView.contentOffset.y + scrollView.frame.size.height + _footerView.frame.size.height) >= scrollView.contentSize.height) {
        SldEventResult *lastResult = [_eventResults lastObject];
        
        //post
        _loadingData = YES;
        _footerView.spinner.hidden = NO;
        [_footerView.spinner startAnimating];
        SldHttpSession *session = [SldHttpSession defaultSession];
        NSDictionary *body = @{@"StartEventId":@(lastResult.eventId), @"Limit":@(RESULT_LIMIT)};
        [session postToApi:@"event/listPlayResult" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            _loadingData = NO;
            _footerView.spinner.hidden = YES;
            [_footerView.spinner stopAnimating];
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            
            NSArray *records = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                return;
            }
            if (records.count < RESULT_LIMIT) {
                _reachBottom = YES;
            }
            if (records.count == 0) {
                return;
            }
            
            NSMutableArray *insertedIndexPathes = [NSMutableArray arrayWithCapacity:records.count];
            for (NSDictionary *record in records) {
                SldEventResult *mr = [[SldEventResult alloc] initWithDict:record];
                [_eventResults addObject:mr];
                [insertedIndexPathes addObject:[NSIndexPath indexPathForRow:_eventResults.count inSection:0]];
            }
            [self.tableView insertRowsAtIndexPaths:insertedIndexPathes withRowAnimation:UITableViewRowAnimationAutomatic];
        }];
    }
}

@end

//=====================
@interface SldLevelTableController : UITableViewController

@end

@implementation SldLevelTableController

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    SldGameData *gd = [SldGameData getInstance];
    return gd.levelArray.count-1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = (UITableViewCell*)[tableView dequeueReusableCellWithIdentifier:@"levelTableCell" forIndexPath:indexPath];
    
    SldGameData *gd = [SldGameData getInstance];
    
    int level = indexPath.row + 1;
    int reward = [(NSNumber*)[gd.levelArray objectAtIndex:level] intValue];
    
    cell.textLabel.text = [NSString stringWithFormat:@"奖金总额：%d，等级：%d", reward, level];
    if (level == gd.level) {
        cell.textLabel.textColor = makeUIColor(244, 75, 116, 255);
    } else {
        cell.textLabel.textColor = [UIColor darkGrayColor];
    }
    
    return cell;
}

@end
