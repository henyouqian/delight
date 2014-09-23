//
//  SldMainMenuController.m
//  Sld
//
//  Created by 李炜 on 14-7-6.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMainMenuController.h"
#import "SldLoginViewController.h"
#import "SldStreamPlayer.h"
#import "SldUtil.h"
#import "SldGameData.h"
#import "SldHttpSession.h"
#import "SldConfig.h"
#import "SldGameData.h"
#import "SldDb.h"

@interface SldMainMenuController ()
@property (weak, nonatomic) IBOutlet UIImageView *discIcon;
@property (nonatomic) BOOL storeViewLoaded;
@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@property (weak, nonatomic) IBOutlet UIButton *hiddenButton;
@end

@implementation SldMainMenuController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //login view
    [SldLoginViewController createAndPresentWithCurrentController:self animated:NO];
    
    //
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(didBecomeActiveNotification)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
    
    //
    NSString *appVer = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    _versionLabel.text = [NSString stringWithFormat:@"v %@", appVer];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [self rotateDisc];
    
    SldGameData *gd = [SldGameData getInstance];
    if ([gd.userName compare:@"lw@pintu.com"] == 0) {
        _hiddenButton.hidden = NO;
    } else {
        _hiddenButton.hidden = YES;
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:NO];
}

- (void)didBecomeActiveNotification {
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
        
        [_discIcon.layer addAnimation:rotationAnimation forKey:@"rotationAnimation"];
    } else {
        [_discIcon.layer removeAllAnimations];
    }
}

- (IBAction)onRatingButton:(id)sender {
    int rateReward = [SldGameData getInstance].playerInfo.rateReward;
    if (rateReward > 0) {
        NSString *str = [NSString stringWithFormat:@"给《拼拼拼拼拼》评个分吧🙏"];
        [[[UIAlertView alloc] initWithTitle:str
                                    message:@""
                           cancelButtonItem:[RIButtonItem itemWithLabel:@"再说" action:^{
            // Handle "Cancel"
        }]
                           otherButtonItems:[RIButtonItem itemWithLabel:@"去评分" action:^{
            [self popupRatingView];
        }], nil] show];
    } else {
        [self popupRatingView];
    }
}

- (void)popupRatingView {
    SKStoreProductViewController *storeProductViewContorller =[[SKStoreProductViewController alloc] init];
    storeProductViewContorller.delegate = self;
    
    [storeProductViewContorller loadProductWithParameters:
     @{SKStoreProductParameterITunesItemIdentifier: [SldConfig getInstance].STORE_ID}completionBlock:^(BOOL result, NSError *error) {
         if(error){
             NSLog(@"error %@ with userInfo %@",error,[error userInfo]);
         } else {
             _storeViewLoaded = YES;
         }
     }
     ];
    
    [self presentViewController:storeProductViewContorller animated:YES completion:nil];
}

- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    [viewController dismissViewControllerAnimated:YES completion:nil];
    return;
    
    if (_storeViewLoaded) {
        _storeViewLoaded = NO;
        
        SldGameData *gd = [SldGameData getInstance];
        
        if (gd.playerInfo.rateReward > 0) {
            gd.playerInfo.rateReward = 0;
            UIAlertView *alt = alertNoButton(@"奖金领取中...");
            SldHttpSession *session = [SldHttpSession defaultSession];
            [session postToApi:@"player/rate" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
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
                
                int addMoney = [(NSNumber*)[dict objectForKey:@"AddMoney"] intValue];
                
                gd.playerInfo.money += (SInt64)addMoney;
                
                NSString *str = [NSString stringWithFormat:@"获得%d金币", addMoney];
                alert(str, nil);
            }];
        }
        
        
    }
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
