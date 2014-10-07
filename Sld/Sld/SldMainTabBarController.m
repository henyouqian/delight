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
#import "MSWeakTimer.h"

@interface SldMainTabBarController ()
@property (weak, nonatomic) IBOutlet UIBarButtonItem *discView;
@property (nonatomic) MSWeakTimer *minTimer;
@end

@implementation SldMainTabBarController

- (void)dealloc {
    [_minTimer invalidate];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(rotateDisc)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
    
    //login view
    [SldLoginViewController createAndPresentWithCurrentController:self animated:NO];
    
    [self.tabBar setSelectedImageTintColor:makeUIColor(244, 75, 116, 255)];
    
    //
    [(UIViewController *)[self.viewControllers objectAtIndex:4] tabBarItem].badgeValue = @"...";
    
    //timer
    _minTimer = [MSWeakTimer scheduledTimerWithTimeInterval:60.f target:self selector:@selector(onMinTimer) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
}

- (void)onMinTimer {
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self rotateDisc];
}

- (void)rotateDisc {
    UIView *view = [self.navigationController.navigationBar.subviews objectAtIndex:2];
    if ([SldStreamPlayer defautPlayer].playing && ![SldStreamPlayer defautPlayer].paused) {
        CABasicAnimation* rotationAnimation;
        rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        rotationAnimation.toValue = [NSNumber numberWithFloat: M_PI * 2.0];
        rotationAnimation.duration = 2.f;
        rotationAnimation.cumulative = YES;
        rotationAnimation.repeatCount = 10000000;
        
        [view.layer addAnimation:rotationAnimation forKey:@"rotationAnimation"];
    } else {
        [view.layer removeAllAnimations];
    }
}

@end
