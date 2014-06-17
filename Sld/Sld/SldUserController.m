//
//  SldUserController.m
//  Sld
//
//  Created by Wei Li on 14-5-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldUserController.h"
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
@property (weak, nonatomic) IBOutlet UILabel *assertsLabel;
@property (weak, nonatomic) IBOutlet UILabel *rewardLabel;

@end

@implementation SldUserController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.clearsSelectionOnViewWillAppear = YES;
    SldGameData *gd = [SldGameData getInstance];
    
    //
    if (!gd.online) {
        [SldLoginViewController createAndPresentWithCurrentController:self animated:YES];
        return;
    }
    
    //
    _rewardLabel.text = [NSString stringWithFormat:@"可领取奖金%lld", gd.rewardCache];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    SldGameData *gamedata = [SldGameData getInstance];

    //avatar
    _avatarView.image = nil;
    NSString *url = [SldUtil makeGravatarUrlWithKey:gamedata.gravatarKey width:_avatarView.frame.size.width];
    [_avatarView asyncLoadImageWithUrl:url showIndicator:NO completion:nil];
    
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
    
    //money
    _moneyLabel.text = [NSString stringWithFormat:@"%lld", gamedata.money];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
//    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
//    if (cell == _logoutCell) {
//        [SldLoginViewController createAndPresentWithCurrentController:self animated:YES];
//    }
}

- (IBAction)onLogoutButton:(id)sender {
    RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:@"No" action:nil];
    
	RIButtonItem *logoutItem = [RIButtonItem itemWithLabel:@"Yes" action:^{
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
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Log out?"
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
    if ([segue.destinationViewController isKindOfClass:[SldMatchResultController class]]) {
        ((SldMatchResultController*)segue.destinationViewController).userController = self;
    }
}

- (void)updateMoney {
    SldGameData *gd = [SldGameData getInstance];
    _moneyLabel.text = [NSString stringWithFormat:@"%lld", gd.money];
    _rewardLabel.text = [NSString stringWithFormat:@"可领取奖金%d", 0];
}

@end

//=================
@interface SldGetRewardCacheCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIButton *getRewardButton;
@end

@implementation SldGetRewardCacheCell
@end

//=================
@interface SldMatchResultCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *rankLabel;
@property (weak, nonatomic) IBOutlet UILabel *matchRewardLabel;
@property (weak, nonatomic) IBOutlet UILabel *betMoneyLabel;
@property (weak, nonatomic) IBOutlet UILabel *betRewardLabel;

@end

@implementation SldMatchResultCell
@end

//=================
@interface SldMatchResult : NSObject
@property (nonatomic) NSString* thumbKey;
@property (nonatomic) int rank;
@property (nonatomic) int matchReward;
@property (nonatomic) int betMoneySum;
@property (nonatomic) int betReward;
@end

@implementation SldMatchResult

@end

//=================
@interface SldMatchResultController()
@property (nonatomic) NSMutableArray *matchResults; //SldMatchResult
@end

@implementation SldMatchResultController

- (void)viewDidLoad {
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.tableFooterView.backgroundColor = [UIColor clearColor];
    
    //get play result
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"StartEventId":@0, @"Limit":@20};
    [session postToApi:@"event/listPlayResult" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        _matchResults = [NSMutableArray array];
        NSArray *records = [dict objectForKey:@"Records"];
        for (NSDictionary *record in records) {
            SldMatchResult *mr = [[SldMatchResult alloc] init];
            mr.thumbKey = @""; //fixme
            mr.rank = [(NSNumber*)[record objectForKey:@"FinalRank"] intValue];
            mr.matchReward = [(NSNumber*)[record objectForKey:@"MatchReward"] intValue];
            mr.betMoneySum = [(NSNumber*)[record objectForKey:@"BetMoneySum"] intValue];
            mr.betReward = [(NSNumber*)[record objectForKey:@"BetReward"] intValue];
            [_matchResults addObject:mr];
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
        return _matchResults.count;
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
        SldMatchResultCell *cell = [tableView dequeueReusableCellWithIdentifier:@"matchResultCell" forIndexPath:indexPath];
        
        SldMatchResult *mr = [_matchResults objectAtIndex:indexPath.row];
        cell.rankLabel.text = [NSString stringWithFormat:@"名次：%d", mr.rank];
        cell.matchRewardLabel.text = [NSString stringWithFormat:@"奖金：%d", mr.matchReward];
        cell.betMoneyLabel.text = [NSString stringWithFormat:@"投注：%d", mr.betMoneySum];
        cell.betRewardLabel.text = [NSString stringWithFormat:@"奖金：%d", mr.betReward];
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

@end
