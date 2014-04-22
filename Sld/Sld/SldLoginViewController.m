//
//  SldLoginViewController.m
//  Sld
//
//  Created by Wei Li on 14-4-20.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldLoginViewController.h"
#import "SldMatchListViewController.h"
#import "SldHttpSession.h"

@interface SldLoginViewController ()
@property (weak, nonatomic) IBOutlet UITextField *userNameInput;
@property (weak, nonatomic) IBOutlet UITextField *passwordInput;
@end

@implementation SldLoginViewController

- (IBAction)onLogin:(id)sender {
    NSString *userName = self.userNameInput.text;
    NSString *password = self.passwordInput.text;
    if ([userName length] == 0 || [password length] == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:@"Fill the blank."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }
    NSDictionary *body = @{@"Username":userName, @"Password":password};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"auth/login" body:body completionHandler:^(id data, NSURLResponse *response, NSError *error) {
        NSLog(@"data:%@\nerror:%@\n", data, error);
        if (!error) {
            //[self dismissViewControllerAnimated:YES completion:nil];
            [self.navigationController popViewControllerAnimated:YES];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:data[@"ErrorString"]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
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
