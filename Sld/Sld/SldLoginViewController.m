//
//  SldLoginViewController.m
//  Sld
//
//  Created by Wei Li on 14-4-20.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldLoginViewController.h"
#import "SldEventListViewController.h"
#import "SldHttpSession.h"
#import "SldUtil.h"
#import "SldGameData.h"
#import "MMPickerView.h"
#import "SldUserInfoController.h"
#import "config.h"
#import "SldIapController.h"

@interface SldLoginViewController ()
@property (weak, nonatomic) IBOutlet UITextField *emailInput;
@property (weak, nonatomic) IBOutlet UITextField *passwordInput;
@property (weak, nonatomic) IBOutlet UIButton *okButton;
@property (weak, nonatomic) IBOutlet UIButton *offlineButton;
@property (weak, nonatomic) IBOutlet UISegmentedControl *seg;
//@property (nonatomic) SldAds *ads;
@end

@implementation SldLoginViewController

+ (void)createAndPresentWithCurrentController:(UIViewController*)currController animated:(BOOL)animated{
    UIStoryboard *storyboard = getStoryboard();
    SldLoginViewController* controller = (SldLoginViewController*)[storyboard instantiateViewControllerWithIdentifier:@"login"];
    UIViewController *vc = currController.navigationController;
    if (vc) {
        [vc presentViewController:controller animated:animated completion:nil];
    } else {
        [currController presentViewController:controller animated:animated completion:nil];
    }
    controller.shouldDismiss = NO;
}

- (IBAction)onTouchView:(id)sender {
    [self.view endEditing:YES];
}
- (IBAction)onChangeMode:(id)sender {
    if ([_seg selectedSegmentIndex] == 0) {
        [_okButton setTitle:@"登  录" forState:UIControlStateNormal];
    } else {
        [_okButton setTitle:@"注  册" forState:UIControlStateNormal];
    }
}

- (IBAction)onOkButton:(id)sender {
    if ([_seg selectedSegmentIndex] == 0) {
        [self login];
    } else {
        [self signUp];
    }
}

- (IBAction)onOfflineButton:(id)sender {
    //[self dismissViewControllerAnimated:YES completion:nil];
    SldGameData *gd = [SldGameData getInstance];
    gd.online = NO;
    gd.gameMode = OFFLINE;
}

//for back segue
- (IBAction)backToLogin:(UIStoryboardSegue *)segue {
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    Config *conf = [Config sharedConf];
    NSArray *accounts = [SSKeychain accountsForService:conf.KEYCHAIN_SERVICE];
    if ([accounts count]) {
        NSString *username = [accounts lastObject][@"acct"];
        NSString *password = [SSKeychain passwordForService:conf.KEYCHAIN_SERVICE account:username];
        self.emailInput.text = username;
        self.passwordInput.text = password;
    }
    
    //button round corner
    CALayer *btnLayer = [_okButton layer];
    [btnLayer setMasksToBounds:YES];
    [btnLayer setCornerRadius:5.0f];
    
    btnLayer = [_offlineButton layer];
    [btnLayer setMasksToBounds:YES];
    [btnLayer setCornerRadius:5.0f];
    
    //
    [_emailInput setDelegate:self];
    [self onChangeMode:_seg];
    
    //
    if (self.emailInput.text.length && self.passwordInput.text.length) {
        [self login];
    }
}

- (void)login {
    NSString *email = self.emailInput.text;
    NSString *password = self.passwordInput.text;
    if ([email length] == 0 || [password length] == 0) {
        alert(@"请填写所有空格", nil);
        return;
    }
    
    if (![SldUtil validateEmail:email]) {
        alert(@"邮箱格式错误", nil);
        return;
    }
    
    UIAlertView *loginAlert = [[UIAlertView alloc] initWithTitle:@"登录中..."
                                                  message:nil
                                                 delegate:nil
                                        cancelButtonTitle:nil
                                        otherButtonTitles:nil];
    [loginAlert show];
    
    NSDictionary *body = @{@"Username":email, @"Password":password};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"auth/login" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [loginAlert dismissWithClickedButtonIndex:0 animated:YES];
        
        if (error) {
            NSString *errType = getServerErrorType(data);
            if ([errType compare:@"err_not_match"] == 0) {
                alert(@"邮箱或密码错误.", nil);
            } else {
                alertHTTPError(error, data);
            }
            return;
        }
        
        SldGameData *gameData = [SldGameData getInstance];
        
        //save to keychain
        [SSKeychain setPassword:password forService:[Config sharedConf].KEYCHAIN_SERVICE account:email];
        
        //update game data
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        gameData.userName = email;
        NSNumber *nUserId = [dict objectForKey:@"UserId"];
        if (nUserId) {
            gameData.userId = [nUserId unsignedLongLongValue];
        }
        NSNumber *nNow = [dict objectForKey:@"Now"];
        if (nNow) {
            setServerNow([nNow longLongValue]);
        }
        
        //get player info
        UIAlertView *getUserInfoAlert = [[UIAlertView alloc] initWithTitle:@"获取用户信息..."
                                                                   message:nil
                                                                  delegate:nil
                                                         cancelButtonTitle:nil
                                                         otherButtonTitles:nil];
        [getUserInfoAlert show];
        [session postToApi:@"player/getInfo" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [getUserInfoAlert dismissWithClickedButtonIndex:0 animated:YES];
            if (error) {
                if (isServerError(error)) {
                    //show player setting page
                    [SldUserInfoController createAndPresentFromController:self cancelable:NO];
                } else {
                    alertHTTPError(error, data);
                }
                
            } else {
                gameData.online = YES;
                
                //update game data
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                gameData.nickName = [dict objectForKey:@"NickName"];
                gameData.gender = [(NSNumber*)[dict objectForKey:@"Gender"] unsignedIntValue];
                gameData.teamName = [dict objectForKey:@"TeamName"];
                gameData.gravatarKey = [dict objectForKey:@"GravatarKey"];
                gameData.customAvatarKey = [dict objectForKey:@"CustomAvatarKey"];
                gameData.money = [(NSNumber*)[dict objectForKey:@"Money"] intValue];
                gameData.rewardCache = [(NSNumber*)[dict objectForKey:@"RewardCache"] longLongValue];
                //gameData.totalReward = [(NSNumber*)[dict objectForKey:@"TotalReward"] longLongValue];
                [gameData setTotalRewardRaw:[(NSNumber*)[dict objectForKey:@"TotalReward"] longLongValue]];
                gameData.betCloseBeforeEndSec = [(NSNumber*)[dict objectForKey:@"BetCloseBeforeEndSec"] intValue];
                gameData.adsPercent = [(NSNumber*)[dict objectForKey:@"AdsPercent"] floatValue];
                gameData.challengeEventId = [(NSNumber*)[dict objectForKey:@"ChallengeEventId"] intValue];
                gameData.rateReward = [(NSNumber*)[dict objectForKey:@"RateReward"] intValue];
                
                [SldIapManager getInstance];
                
                if (gameData.nickName.length == 0) {
                    [SldUserInfoController createAndPresentFromController:self cancelable:NO];
                } else {
                    [self dismissViewControllerAnimated:YES completion:nil];
                }
            }
        }];
    }];
}

- (void)signUp {
    NSString *email = self.emailInput.text;
    NSString *password = self.passwordInput.text;
    if ([email length] == 0 || [password length] == 0) {
        alert(@"Error", @"Fill the blank.");
        return;
    }
    if (![SldUtil validateEmail:email]) {
        alert(@"Email格式错误", nil);
        return;
    }
    
    NSDictionary *body = @{@"Username":email, @"Password":password};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"auth/register" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSString *errType = getServerErrorType(data);
            if ([errType compare:@"err_exist"] == 0) {
                alert(@"账号已存在", nil);
            }else {
                alertHTTPError(error, data);
            }
            return;
        }
        
        [self login];
    }];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (void)viewDidAppear:(BOOL)animated {
    if (self.shouldDismiss) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [_emailInput becomeFirstResponder];
    }
}

-(BOOL)textFieldShouldReturn:(UITextField*)textField;
{
    if (textField == _emailInput) {
        [_passwordInput becomeFirstResponder];
    }
    return NO;
}

@end

//===================
@interface SldForgotPasswordControl : UIViewController
@property (weak, nonatomic) IBOutlet UITextField *emailInput;

@end

@implementation SldForgotPasswordControl

- (void)viewDidLoad {
    [_emailInput becomeFirstResponder];
}

- (IBAction)onSendEmail:(id)sender {
    SldHttpSession *session = [SldHttpSession defaultSession];
    
    if (_emailInput.text.length == 0) {
        alert(@"请填写Email", nil);
        return;
    }
    
    if (![SldUtil validateEmail:_emailInput.text]) {
        alert(@"Email格式错误", nil);
        return;
    }
    
    NSDictionary *body = @{@"Email":_emailInput.text};
    UIAlertView *alt = alertNoButton(@"邮件发送中...");
    [session postToApi:@"auth/forgotPassword" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [alt dismissWithClickedButtonIndex:0 animated:YES];
        if (error) {
            NSString *err = getServerErrorType(data);
            if ([err compare:@"err_not_exist"] == 0) {
                alert(@"账号不存在", nil);
            } else {
                alertHTTPError(error, data);
            }
            return;
        }
        
        [[[UIAlertView alloc] initWithTitle:@"重设密码邮件已发送。如未收到，要么等等，要么垃圾箱找找，要么再发一遍试试"
                                    message:@""
                           cancelButtonItem:[RIButtonItem itemWithLabel:@"知道了" action:^{
            [self dismissViewControllerAnimated:YES completion:nil];
        }]
                           otherButtonItems:nil] show];
    }];
    
}

@end
