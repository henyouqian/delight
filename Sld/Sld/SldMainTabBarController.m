//
//  SldMainTabBarController.m
//  pin
//
//  Created by 李炜 on 14-9-25.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMainTabBarController.h"
#import "SldStreamPlayer.h"
#import "SldUtil.h"
#import "SldHttpSession.h"
#import "SldGameData.h"
#import "MSWeakTimer.h"
#import "SldDb.h"

@interface SldMainTabBarController ()
@property (nonatomic) MSWeakTimer *minTimer;
@property (nonatomic) SldGameData *gd;
@end

@implementation SldMainTabBarController

- (void)dealloc {
    [_minTimer invalidate];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    
//    [self.tabBar setSelectedImageTintColor:makeUIColor(244, 75, 116, 255)];
    self.tabBar.tintColor = makeUIColor(244, 75, 116, 255);
    
    //timer
    _minTimer = [MSWeakTimer scheduledTimerWithTimeInterval:60.f target:self selector:@selector(onMinTimer) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
    
    //
    SldDb *db = [SldDb defaultDb];
    NSString *rules = [db getString:@"appleRules"];
    if (rules == nil) {
        //alert(nil, @"声明：游戏中的比赛、比赛获得的奖励、投注以及投注获得的奖励均与苹果公司无关。");
        alertWithButton(@"声明", @"•  游戏中的比赛以及比赛所获得的实物奖励均与苹果公司无关。\n•  请勿上传色情，暴力等不和谐内容。  \n•  若使用非第三方账号登陆，请在用户设置界面填写邮箱地址，便于找回密码。", @"知道了");
        
        [db setKey:@"appleRules" string:@"1"];
    }
    
    //login notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLogin) name:@"login" object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
}

- (void)onLogin {
    [self onMinTimer];
}

- (void)onMinTimer {
    if (!_gd.online) {
        return;
    }
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"player/getPrizeCache" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        int old = _gd.playerInfo.prizeCache;
        _gd.playerInfo.prizeCache = [(NSNumber*)dict[@"PrizeCache"] floatValue];
        if (old != _gd.playerInfo.prizeCache) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"prizeCacheChange" object:nil];
        }
        
        NSString *str = nil;
        if (_gd.playerInfo.prizeCache > 0) {
            str = @"奖";
        }
        [(UIViewController *)[self.viewControllers objectAtIndex:3] tabBarItem].badgeValue = str;
    }];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

@end
