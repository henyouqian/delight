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
#import "SSKeychain/SSkeychain.h"
#import "SldGameData.h"
#import "MMPickerView.h"

static NSString *KEYCHAIN_SERVICE = @"com.liwei.Sld.HTTP_ACCOUNT";

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
    UIViewController* controller = [storyboard instantiateViewControllerWithIdentifier:@"login"];
    [currController presentViewController:controller animated:animated completion:nil];
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
    [self dismissViewControllerAnimated:YES completion:nil];
    [SldGameData getInstance].offline = YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    NSArray *accounts = [SSKeychain accountsForService:KEYCHAIN_SERVICE];
    if ([accounts count]) {
        NSString *username = [accounts lastObject][@"acct"];
        NSString *password = [SSKeychain passwordForService:KEYCHAIN_SERVICE account:username];
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
        alert(@"Error", @"Fill the blank.");
        return;
    }
    NSDictionary *body = @{@"Username":username, @"Password":password};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"auth/login" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSString *errType = getServerErrorType(data);
            if ([errType compare:@"err_not_match"] == 0) {
                alert(@"Error", @"Username and password dismatch.");
            } else {
                alertServerError(error, data);
            }
            return;
        }
        
        SldGameData *gameData = [SldGameData getInstance];
        
        [self dismissViewControllerAnimated:YES completion:nil];
        gameData.offline = NO;
        
        //save to keychain
        [SSKeychain setPassword:password forService:KEYCHAIN_SERVICE account:username];
        
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
            alertServerError(error, data);
            return;
        }
        
        alert(@"Message", @"Sign up succeed. Please login.");
    }];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [_usernameInput becomeFirstResponder];
}

-(BOOL)textFieldShouldReturn:(UITextField*)textField;
{
    if (textField == _usernameInput) {
        [_passwordInput becomeFirstResponder];
    }
    return NO;
}


@end
