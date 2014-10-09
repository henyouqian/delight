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
#import "SldConfig.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldGameData.h"
#import "SldUtil.h"

@interface SldUserController ()
@property (weak, nonatomic) IBOutlet UIImageView *avatarView;
@property (weak, nonatomic) IBOutlet UILabel *nickNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *teamLabel;
@property (weak, nonatomic) IBOutlet UILabel *genderLabel;
@property (weak, nonatomic) IBOutlet UILabel *goldCoinLabel;
@property (weak, nonatomic) IBOutlet UILabel *totalCouponLabel;
@property (weak, nonatomic) IBOutlet UILabel *couponLabel;
@property (weak, nonatomic) IBOutlet UITableViewCell *userInfoCell;
@property (weak, nonatomic) IBOutlet UIButton *logoutButton;
@property (nonatomic) int logoutNum;

@end

static __weak SldUserController *g_inst = nil;
static const int DAILLY_LOGOUT_NUM = 5;

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
    
    [self updateUI];
    
    SldGameData *gd = [SldGameData getInstance];
    
    //update playerInfo
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"player/getInfo" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            if (isServerError(error)) {
                [SldUserInfoController createAndPresentFromController:self cancelable:NO];
            } else {
                alertHTTPError(error, data);
            }
            
        } else {
            //update game data
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            gd.playerInfo = [PlayerInfo playerWithDictionary:dict];
            
            [self updateUI];
        }
    }];
    
    //daily logout nums
    _logoutNum = [self getTodayLogoutNum];
    
    NSString *title = [NSString stringWithFormat:@"注销（今日剩%d次）", DAILLY_LOGOUT_NUM-_logoutNum];
    [_logoutButton setTitle:title forState:UIControlStateNormal];
}

- (NSString*)getTodayString {
    NSDate* now = getServerNow();
    NSCalendar *gregorian = [[NSCalendar alloc]
                             initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *comp =
    [gregorian components:(NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear) fromDate:now];
    
    NSString *todayStr = [NSString stringWithFormat:@"%d.%d.%d", comp.year, comp.month, comp.day];
    
    return todayStr;
}

- (int)getTodayLogoutNum {
    NSString *todayStr = [self getTodayString];
    
    int logoutNum = 0;
    NSString *js = [SldUtil getKeyChainValueWithKey:@"logoutNum"];
    if (js) {
        NSData *data = [js dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError(@"error: %@", error);
            return logoutNum;
        }
        NSString *date = [dict objectForKey:@"date"];
        if ([date compare:todayStr] == 0) {
            logoutNum = [(NSNumber*)[dict objectForKey:@"logoutNum"] intValue];
        }
    }
    return logoutNum;
}

- (void)updateUI {
    SldGameData *gamedata = [SldGameData getInstance];
    PlayerInfo *playerInfo = gamedata.playerInfo;
    
    //avatar
    [SldUtil loadAvatar:_avatarView gravatarKey:playerInfo.gravatarKey customAvatarKey:playerInfo.customAvatarKey];
    
    //nickname
    _nickNameLabel.text = playerInfo.nickName;
    
    //team
    _teamLabel.text = playerInfo.teamName;
    
    //gender
    if (playerInfo.gender == 1) {
        _genderLabel.text = @"🚹";
        _genderLabel.textColor = makeUIColor(0, 122, 255, 255);
    } else if (playerInfo.gender == 0) {
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
    if (_logoutNum == DAILLY_LOGOUT_NUM) {
        alert(@"今日注销次数已用完", nil);
        return;
    }
    
    RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:@"否" action:nil];
    
	RIButtonItem *logoutItem = [RIButtonItem itemWithLabel:@"是" action:^{
		[[SldHttpSession defaultSession] logoutWithComplete:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                SldConfig *conf = [SldConfig getInstance];
                NSArray *accounts = [SSKeychain accountsForService:conf.KEYCHAIN_SERVICE];
                NSString *username = [accounts lastObject][@"acct"];
                [SSKeychain setPassword:@"" forService:conf.KEYCHAIN_SERVICE account:username];
                [SldLoginViewController createAndPresentWithCurrentController:self animated:YES];
                
                SldGameData *gd = [SldGameData getInstance];
                [gd reset];
                
#ifndef DEBUG
                _logoutNum++;
#endif
                NSString *todayStr = [self getTodayString];
                NSDictionary *dict = @{@"date":todayStr, @"logoutNum":@(_logoutNum)};
                NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
                NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                [SldUtil setKeyChainWithKey:@"logoutNum" value:str];
            });
        }];
	}];
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"注销当前账号吗?"
	                                                    message:nil
											   cancelButtonItem:cancelItem
											   otherButtonItems:logoutItem, nil];
	[alertView show];
}

- (void)updateMoney {
    SldGameData *gd = [SldGameData getInstance];
    PlayerInfo *playerInfo = gd.playerInfo;
    _goldCoinLabel.text = [NSString stringWithFormat:@"%d", playerInfo.goldCoin];
    _couponLabel.text = [NSString stringWithFormat:@"%.2f", playerInfo.coupon];
    _totalCouponLabel.text = [NSString stringWithFormat:@"%.2f", playerInfo.totalCoupon];
}

- (IBAction)onClearCache:(id)sender {
    UIAlertView *alt = alertNoButton(@"清理中");
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *imgCacheDir = makeDocPath([SldConfig getInstance].IMG_CACHE_DIR);
    NSError *error = nil;
    BOOL success = [fm removeItemAtPath:imgCacheDir error:&error];
    
    [fm createDirectoryAtPath:imgCacheDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    [alt dismissWithClickedButtonIndex:0 animated:NO];
    
    if (!success || error) {
        alert(@"清理失败", nil);
        return;
    }
    alert(@"清理完毕", nil);
}

@end



////=================
//@interface SldEventResultController()
//@property (nonatomic) NSMutableArray *eventResults; //SldEventResult
//@property (weak, nonatomic) IBOutlet SldEventResultFooterView *footerView;
//@property (nonatomic) BOOL reachBottom;
//@property (nonatomic) BOOL loadingData;
//@end
//
//const int RESULT_LIMIT = 20;
//
//@implementation SldEventResultController
//
//- (void)viewDidLoad {
//    _reachBottom = NO;
//    
//    //footer
//    self.tableView.tableFooterView = _footerView;
//    _footerView.spinner.hidden = YES;
//    
//    //refresh control
//    self.refreshControl = [[UIRefreshControl alloc] init];
//    [self.tableView addSubview:self.refreshControl];
//    [self.refreshControl addTarget:self action:@selector(refershList) forControlEvents:UIControlEventValueChanged];
//    
//    [self refershList];
//}
//
//- (void)refershList {
//    if (_loadingData) {
//        [self.refreshControl endRefreshing];
//        return;
//    }
//    //get play result
//    _loadingData = YES;
//    SldHttpSession *session = [SldHttpSession defaultSession];
//    NSDictionary *body = @{@"StartEventId":@0, @"Limit":@(RESULT_LIMIT)};
//    [session postToApi:@"event/listPlayResult" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//        _loadingData = NO;
//        [self.refreshControl endRefreshing];
//        if (error) {
//            alertHTTPError(error, data);
//            return;
//        }
//        
//        NSArray *records = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
//        if (error) {
//            lwError("Json error:%@", [error localizedDescription]);
//            return;
//        }
//        
//        _eventResults = [NSMutableArray array];
//        for (NSDictionary *record in records) {
//            SldEventResult *result = [[SldEventResult alloc] initWithDict:record];
//            [_eventResults addObject:result];
//        }
//        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
//    }];
//}
//
//- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
//{
//    return 2;
//}
//
//- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
//{
//    if (section == 0) {
//        return 1;
//    } else if (section == 1) {
//        return _eventResults.count;
//    }
//    return 0;
//}
//
//- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    SldGameData *gd = [SldGameData getInstance];
//    
//    if (indexPath.section == 0) {
//        SldGetRewardCacheCell *cell = (SldGetRewardCacheCell*)[tableView dequeueReusableCellWithIdentifier:@"rewardCacheCell" forIndexPath:indexPath];
//        
//        NSString *title = [NSString stringWithFormat:@"点击领取奖金：%d", gd.playerInfo.couponCache];
//        [cell.getRewardButton setTitle:title forState:(UIControlStateNormal&UIControlStateHighlighted&UIControlStateDisabled)];
//        if (gd.playerInfo.couponCache == 0) {
//            cell.getRewardButton.enabled = NO;
//            cell.getRewardButton.backgroundColor = [UIColor lightGrayColor];
//        } else {
//            cell.getRewardButton.enabled = YES;
//            cell.getRewardButton.backgroundColor = makeUIColor(244, 75, 116, 255);
//        }
//        return cell;
//    } else if (indexPath.section == 1) {
//        SldEventResultCell *cell = [tableView dequeueReusableCellWithIdentifier:@"matchResultCell" forIndexPath:indexPath];
//        
//        SldEventResult *er = [_eventResults objectAtIndex:indexPath.row];
//        cell.rankLabel.text = [NSString stringWithFormat:@"名次：%d", er.rank];
//        cell.matchRewardLabel.text = [NSString stringWithFormat:@"奖金：%d", er.matchReward];
//        cell.betMoneyLabel.text = [NSString stringWithFormat:@"投注：%d", er.betMoneySum];
//        cell.betRewardLabel.text = [NSString stringWithFormat:@"奖金：%d", er.betReward];
//        [cell.packThumbView asyncLoadImageWithKey:er.thumbKey showIndicator:NO completion:nil];
//        return cell;
//    }
//    
//    return nil;
//}
//
//- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
//    if (indexPath.section == 0) {
//        return 44;
//    } else if (indexPath.section == 1) {
//        return 60;
//    }
//    return 44;
//}
//
//- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
//    return 20;
//}
//
//- (IBAction)onGetReward:(id)sender {
//    UIAlertView *alt = alertNoButton(@"领取中...");
//    
//    SldHttpSession *session = [SldHttpSession defaultSession];
//    [session postToApi:@"player/addCouponFromCache" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//        [alt dismissWithClickedButtonIndex:0 animated:YES];
//        if (error) {
//            alertHTTPError(error, data);
//            return;
//        }
//        
//        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
//        if (error) {
//            lwError("Json error:%@", [error localizedDescription]);
//            return;
//        }
//        
//        SldGameData *gd = [SldGameData getInstance];
//        PlayerInfo *playerInfo = gd.playerInfo;
//        int prevCoupon = playerInfo.coupon;
//        playerInfo.coupon = [(NSNumber*)[dict objectForKey:@"Coupon"] intValue];
//        playerInfo.totalCoupon = [(NSNumber*)[dict objectForKey:@"TotalCoupon"] intValue];
//        playerInfo.couponCache = 0;
//        
//        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
//        
//        [_userController updateMoney];
//        
//        alert(@"金币领取成功", [NSString stringWithFormat:@"%d + %d = %d", prevCoupon, playerInfo.coupon-prevCoupon, playerInfo.coupon]);
//    }];
//}
//
//- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
//    if (_eventResults.count == 0 || _reachBottom || _loadingData) {
//        return;
//    }
//    
//    if ((scrollView.contentOffset.y + scrollView.frame.size.height + _footerView.frame.size.height) >= scrollView.contentSize.height) {
//        SldEventResult *lastResult = [_eventResults lastObject];
//        
//        //post
//        _loadingData = YES;
//        _footerView.spinner.hidden = NO;
//        [_footerView.spinner startAnimating];
//        SldHttpSession *session = [SldHttpSession defaultSession];
//        NSDictionary *body = @{@"StartEventId":@(lastResult.eventId), @"Limit":@(RESULT_LIMIT)};
//        [session postToApi:@"event/listPlayResult" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//            _loadingData = NO;
//            _footerView.spinner.hidden = YES;
//            [_footerView.spinner stopAnimating];
//            if (error) {
//                alertHTTPError(error, data);
//                return;
//            }
//            
//            NSArray *records = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
//            if (error) {
//                lwError("Json error:%@", [error localizedDescription]);
//                return;
//            }
//            if (records.count < RESULT_LIMIT) {
//                _reachBottom = YES;
//            }
//            if (records.count == 0) {
//                return;
//            }
//            
//            NSMutableArray *insertedIndexPathes = [NSMutableArray arrayWithCapacity:records.count];
//            for (NSDictionary *record in records) {
//                SldEventResult *mr = [[SldEventResult alloc] initWithDict:record];
//                [_eventResults addObject:mr];
//                [insertedIndexPathes addObject:[NSIndexPath indexPathForRow:_eventResults.count inSection:0]];
//            }
//            [self.tableView insertRowsAtIndexPaths:insertedIndexPathes withRowAnimation:UITableViewRowAnimationAutomatic];
//        }];
//    }
//}
//
//@end

