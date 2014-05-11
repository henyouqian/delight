//
//  SldNevigationController.m
//  Sld
//
//  Created by Wei Li on 14-5-3.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldNevigationController.h"
#import "GameKitHelper.h"

@interface SldNevigationController ()

@end

@implementation SldNevigationController

+ (float) getBottomY {
    return 64.f;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
//    [[NSNotificationCenter defaultCenter]
//        addObserver:self
//           selector:@selector(showAuthenticationViewController)
//               name:PresentAuthenticationViewController
//             object:nil];
//    
//    [[GameKitHelper sharedGameKitHelper] authenticateLocalPlayer];
    //[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"gamecenter:"]];
    
}

//- (void)showAuthenticationViewController
//{
//    GameKitHelper *gameKitHelper = [GameKitHelper sharedGameKitHelper];
//    [self.topViewController presentViewController:gameKitHelper.authenticationViewController
//                                         animated:YES
//                                       completion:nil];
//}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (void)dealloc
{
//    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
