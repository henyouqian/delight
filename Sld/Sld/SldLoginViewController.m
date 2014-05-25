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
#import "util.h"
#import "SldGameData.h"
#import "MMPickerView.h"
#import "SldUserInfoController.h"
#import "config.h"


@interface SldLoginViewController ()
@property (weak, nonatomic) IBOutlet UITextField *usernameInput;
@property (weak, nonatomic) IBOutlet UITextField *passwordInput;
@property (weak, nonatomic) IBOutlet UIButton *okButton;
@property (weak, nonatomic) IBOutlet UIButton *offlineButton;
@property (weak, nonatomic) IBOutlet UISegmentedControl *seg;
@end

@implementation SldLoginViewController

+ (void)createAndPresentWithCurrentController:(UIViewController*)currController animated:(BOOL)animated{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
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
        [_okButton setTitle:@"Login" forState:UIControlStateNormal];
    } else {
        [_okButton setTitle:@"Sign up" forState:UIControlStateNormal];
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
    [SldGameData getInstance].online = NO;
}

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
        self.usernameInput.text = username;
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
    [_usernameInput setDelegate:self];
    
    [self onChangeMode:_seg];
}

- (void)login {
    NSString *username = self.usernameInput.text;
    NSString *password = self.passwordInput.text;
    if ([username length] == 0 || [password length] == 0) {
        alert(@"Fill the blank.", nil);
        return;
    }
    
    UIAlertView *loginAlert = [[UIAlertView alloc] initWithTitle:@"Login ..."
                                                  message:nil
                                                 delegate:nil
                                        cancelButtonTitle:nil
                                        otherButtonTitles:nil];
    [loginAlert show];
    
    NSDictionary *body = @{@"Username":username, @"Password":password};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"auth/login" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [loginAlert dismissWithClickedButtonIndex:0 animated:YES];
        
        if (error) {
            NSString *errType = getServerErrorType(data);
            if ([errType compare:@"err_not_match"] == 0) {
                alert(@"Username and password dismatch.", nil);
            } else {
                alertHTTPError(error, data);
            }
            return;
        }
        
        SldGameData *gameData = [SldGameData getInstance];
        
        //save to keychain
        [SSKeychain setPassword:password forService:[Config sharedConf].KEYCHAIN_SERVICE account:username];
        
        //update game data
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        gameData.userName = username;
        NSNumber *nUserId = [dict objectForKey:@"UserId"];
        if (nUserId) {
            gameData.userId = [nUserId unsignedLongLongValue];
        }
        NSNumber *nNow = [dict objectForKey:@"Now"];
        if (nNow) {
            setServerNow([nNow longLongValue]);
        }
        
        //get player info
        UIAlertView *getUserInfoAlert = [[UIAlertView alloc] initWithTitle:@"Fetching user infos ..."
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
                gameData.money = [(NSNumber*)[dict objectForKey:@"Money"] longLongValue];
                [self dismissViewControllerAnimated:YES completion:nil];
            }
        }];
    }];
}

- (void)signUp {
    NSString *username = self.usernameInput.text;
    NSString *password = self.passwordInput.text;
    if ([username length] == 0 || [password length] == 0) {
        alert(@"Error", @"Fill the blank.");
        return;
    }
    NSDictionary *body = @{@"Username":username, @"Password":password};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"auth/register" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        alert(@"Message", @"Sign up succeed. Please login.");
    }];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (void)viewDidAppear:(BOOL)animated {
    if (self.shouldDismiss) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [_usernameInput becomeFirstResponder];
    }
}

-(BOOL)textFieldShouldReturn:(UITextField*)textField;
{
    if (textField == _usernameInput) {
        [_passwordInput becomeFirstResponder];
    }
    return NO;
}


@end
