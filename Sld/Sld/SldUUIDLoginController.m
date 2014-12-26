//
//  SldUUIDLoginController.m
//  pin
//
//  Created by 李炜 on 14/11/15.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldUUIDLoginController.h"
#import "SldUtil.h"
#import "SldGameData.h"
#import "SldHttpSession.h"
#import "SldUserInfoController.h"
#import "SldIapController.h"
#import "SldConfig.h"

static NSString *KEYCHAIN_SERVICE = @"uuidLoginKeychain";
//distcheck
static NSString *LOCAL_ACCOUNT = @"LOCAL_ACCOUNT1"; //LOCAL_ACCOUNT1 is for distribution
//static NSString *LOCAL_ACCOUNT = @"LOCAL_ACCOUNT2";

@interface SldUUIDLoginController ()
@property (weak, nonatomic) IBOutlet UIButton *retryButton;

@end

@implementation SldUUIDLoginController

+ (void)presentWithCurrentController:(UIViewController*)currController animated:(BOOL)animated{
    SldGameData *gd = [SldGameData getInstance];
    gd.online = NO;
    
    UIStoryboard *storyboard = getStoryboard();
    SldUUIDLoginController* controller = (SldUUIDLoginController*)[storyboard instantiateViewControllerWithIdentifier:@"uuidLogin"];
    UIViewController *vc = currController.navigationController;
    if (vc) {
        [vc presentViewController:controller animated:animated completion:nil];
    } else {
        [currController presentViewController:controller animated:animated completion:nil];
    }
}

- (IBAction)onRetryButton:(id)sender {
    [self login];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    _retryButton.hidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self login];
}

- (void)login {
    //    del all account
    //    NSArray *accounts = [SSKeychain accountsForService:KEYCHAIN_SERVICE];
    //    for (NSDictionary *acc in accounts) {
    //        [SSKeychain deletePasswordForService:KEYCHAIN_SERVICE account:acc[@"acct"]];
    //    }
    
    _retryButton.hidden = YES;
    
    NSString *key = [SSKeychain passwordForService:KEYCHAIN_SERVICE account:LOCAL_ACCOUNT];
    NSString *type = @"uuid";
    
    SldConfig *conf = [SldConfig getInstance];
    
    if (!key || key.length == 0) {
        key = [SldUtil genUUID];
    }
    
    //distcheck
    //    NSArray *users = @[@"7F2EB1DC-921A-4415-8A01-778255ABC1B8",
    //                       @"C7F7CE83-FD9E-4F35-B230-179E27825CF9",
    //                       @"49BE1E72-A581-4170-9C3C-AEC38E3BB5A1",
    //                       @"9DA924BB-6327-4C8A-BA4D-B010765478CD",
    //                       @"43DF2717-1407-4D0A-822C-38275B22617A"];
    
    //#define FAKEUSER
    //    key = @"9DA924BB-6327-4C8A-BA4D-B010765478CD111";
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"auth/getSnsSecret" body:nil completionHandler:^(NSData *data, NSURLResponse *resp, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            _retryButton.hidden = NO;
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        NSString *secret = [dict objectForKey:@"Secret"];
        
        //checksum
        NSString *checksum = [NSString stringWithFormat:@"%@+%@ll46i", key, secret];
        checksum = [SldUtil sha1WithString:checksum];
        
        //post auth/loginSns
        NSDictionary *body = @{@"Type":type, @"SnsKey":key, @"Secret":secret, @"Checksum":checksum};
        [session postToApi:@"auth/loginSns" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                return;
            }
            
            //save to keychain
#ifndef FAKEUSER
            [SSKeychain setPassword:key forService:KEYCHAIN_SERVICE account:LOCAL_ACCOUNT];
#endif
            
            //
            SldGameData *gd = [SldGameData getInstance];
            gd.token = [dict objectForKey:@"Token"];
            NSNumber *nUserId = [dict objectForKey:@"UserId"];
            if (nUserId) {
                gd.userId = [nUserId unsignedLongLongValue];
            }
            gd.userName = [dict objectForKey:@"UserName"];
            NSNumber *nNow = [dict objectForKey:@"Now"];
            if (nNow) {
                setServerNow([nNow longLongValue]);
            }
            
            //get player info
            [session postToApi:@"player/getInfo" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error) {
                    if (isServerError(error)) {
                        //show player setting page
                        [SldUserInfoController createAndPresentFromController:self cancelable:NO];
                    } else {
                        alertHTTPError(error, data);
                    }
                    
                } else {
                    gd.online = YES;
                    
                    //update game data
                    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                    
                    gd.playerInfo = [PlayerInfo playerWithDictionary:dict];
                    
                    //update client conf
                    NSDictionary *confDict = [dict objectForKey:@"ClientConf"];
                    [conf updateWithDict:confDict];
                    
                    //init SldIapManager
                    [SldIapManager getInstance];
                    
                    if (gd.playerInfo.nickName.length == 0) {
                        [SldUserInfoController createAndPresentFromController:self cancelable:NO];
                    } else {
                        [self dismissViewControllerAnimated:YES completion:nil];
                    }
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"login" object:nil];
                }
            }];
            
        }];
    }];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
