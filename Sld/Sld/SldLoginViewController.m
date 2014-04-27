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

static NSString *KEYCHAIN_SERVICE = @"com.liwei.Sld.HTTP_ACCOUNT";

@interface SldLoginViewController ()
@property (weak, nonatomic) IBOutlet UITextField *usernameInput;
@property (weak, nonatomic) IBOutlet UITextField *passwordInput;
@end

@implementation SldLoginViewController

- (IBAction)onLogin:(id)sender {
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
            alert(@"Error", @"Http Error");
            return;
        }
        //[self.navigationController popViewControllerAnimated:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
        
        //save to keychain
        [SSKeychain setPassword:password forService:KEYCHAIN_SERVICE account:username];
    }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
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
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
