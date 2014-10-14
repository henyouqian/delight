//
//  SldMainTabBarController.m
//  pin
//
//  Created by 李炜 on 14-9-25.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMainTabBarController.h"
#import "SldStreamPlayer.h"
#import "SldLoginViewController.h"
#import "SldUtil.h"
#import "SldHttpSession.h"
#import "SldGameData.h"
#import "MSWeakTimer.h"
#import "SldDb.h"

@interface SldMainTabBarController ()
@property (nonatomic) MSWeakTimer *minTimer;
@property (nonatomic) SldGameData *gd;
@property (nonatomic) UIView *discView;
@end

@implementation SldMainTabBarController

- (void)dealloc {
    [_minTimer invalidate];
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    
    _discView = [self.navigationController.navigationBar.subviews objectAtIndex:1];
    
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(rotateDisc)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
    
    //login view
    [SldLoginViewController createAndPresentWithCurrentController:self animated:NO];
    
    [self.tabBar setSelectedImageTintColor:makeUIColor(244, 75, 116, 255)];
    
    //timer
    _minTimer = [MSWeakTimer scheduledTimerWithTimeInterval:60.f target:self selector:@selector(onMinTimer) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
    
    //
    SldDb *db = [SldDb defaultDb];
    NSString *rules = [db getString:@"appleRules"];
    if (rules == nil) {
        //alert(nil, @"声明：游戏中的比赛、比赛获得的奖励、投注以及投注获得的奖励均与苹果公司无关。");
        alertWithButton(@"声明", @"•  游戏中的比赛、比赛获得的奖励、投注以及投注获得的奖励均与苹果公司无关。\n•  请勿上传色情，暴力等不和谐内容。", @"知道了");
        
        [db setKey:@"appleRules" string:@"1"];
    }
    
    //login notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLogin) name:@"login" object:nil];
}

- (void)onLogin {
    [self onMinTimer];
}

- (void)onMinTimer {
    if (!_gd.online) {
        return;
    }
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"player/getCouponCache" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        float old = _gd.playerInfo.couponCache;
        _gd.playerInfo.couponCache = [(NSNumber*)dict[@"CouponCache"] floatValue];
        if (old != _gd.playerInfo.couponCache) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"couponCacheChange" object:nil];
        }
        
        NSString *str = nil;
        if (_gd.playerInfo.couponCache >= 0.01) {
            str = @"奖";
        }
        [(UIViewController *)[self.viewControllers objectAtIndex:4] tabBarItem].badgeValue = str;
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self rotateDisc];
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
