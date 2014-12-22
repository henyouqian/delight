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
#import "SldStreamPlayer.h"

@interface SldUserController ()
@property (weak, nonatomic) IBOutlet SldAsyncImageView *avatarView;
@property (weak, nonatomic) IBOutlet UILabel *nickNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *teamLabel;
@property (weak, nonatomic) IBOutlet UILabel *genderLabel;
@property (weak, nonatomic) IBOutlet UILabel *goldCoinLabel;
@property (weak, nonatomic) IBOutlet UILabel *totalPrizeLabel;
@property (weak, nonatomic) IBOutlet UILabel *prizeLabel;
@property (weak, nonatomic) IBOutlet UITableViewCell *userInfoCell;
@property (weak, nonatomic) IBOutlet UIButton *logoutButton;
@property (weak, nonatomic) IBOutlet UILabel *idLabel;
@property (nonatomic) int logoutNum;
@property (nonatomic) UIView *discView;

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
    
    _discView = [self.navigationController.navigationBar.subviews objectAtIndex:2];
    
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(rotateDisc)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
    
    [_avatarView.layer setMasksToBounds:YES];
    _avatarView.layer.cornerRadius = 5;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]removeObserver:self];
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
    
    [self rotateDisc];
}

- (NSString*)getTodayString {
    NSDate* now = getServerNow();
    NSCalendar *gregorian = [[NSCalendar alloc]
                             initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
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
    
    //id
    _idLabel.text = [NSString stringWithFormat:@"ID：%lld", playerInfo.userId];
    
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
#ifndef DEBUG
    if (_logoutNum >= DAILLY_LOGOUT_NUM) {
        alert(@"今日注销次数已用完", nil);
        return;
    }
#endif

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
                
                _logoutNum++;
                
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
    _prizeLabel.text = [NSString stringWithFormat:@"%d", playerInfo.prize];
    _totalPrizeLabel.text = [NSString stringWithFormat:@"%d", playerInfo.totalPrize];
}

- (IBAction)onClearCache:(id)sender {
    [[[UIAlertView alloc] initWithTitle:@"确定清理缓存?"
	                            message:nil
		               cancelButtonItem:[RIButtonItem itemWithLabel:@"不了" action:^{
        // Handle "Cancel"
    }]
				       otherButtonItems:[RIButtonItem itemWithLabel:@"现在清理" action:^{
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
        alert(@"清理完毕", nil);    }], nil] show];
}

- (void)rotateDisc {
    if ([SldStreamPlayer defautPlayer].playing && ![SldStreamPlayer defautPlayer].paused) {
        CABasicAnimation* rotationAnimation;
        rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        rotationAnimation.toValue = [NSNumber numberWithFloat: M_PI * 2.0];
        rotationAnimation.duration = 2.f;
        rotationAnimation.cumulative = YES;
        rotationAnimation.repeatCount = 10000000;
        
        [_discView.layer addAnimation:rotationAnimation forKey:@"rotationAnimation"];
    } else {
        [_discView.layer removeAllAnimations];
    }
}

@end

