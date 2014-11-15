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

@interface SldUUIDLoginController ()

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


- (void)viewDidLoad {
    [super viewDidLoad];
    
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    NSString *key = @"";
    NSString *type = @"uuid";
    
    SldConfig *conf = [SldConfig getInstance];
    
    NSArray *accounts = [SSKeychain accountsForService:KEYCHAIN_SERVICE];
    if ([accounts count]) {
        key = [accounts lastObject][@"acct"];
    } else {
        key = [SldUtil genUUID];
    }
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"auth/getSnsSecret" body:nil completionHandler:^(NSData *data, NSURLResponse *resp, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
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
            [SSKeychain setPassword:@"" forService:KEYCHAIN_SERVICE account:key];
            
            //
            SldGameData *gameData = [SldGameData getInstance];
            gameData.token = [dict objectForKey:@"Token"];
            NSNumber *nUserId = [dict objectForKey:@"UserId"];
            if (nUserId) {
                gameData.userId = [nUserId unsignedLongLongValue];
            }
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
                    gameData.online = YES;
                    
                    //update game data
                    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                    
                    gameData.playerInfo = [PlayerInfo playerWithDictionary:dict];
                    
                    //update client conf
                    NSDictionary *confDict = [dict objectForKey:@"ClientConf"];
                    [conf updateWithDict:confDict];
                    
                    //init SldIapManager
                    [SldIapManager getInstance];
                    
                    if (gameData.playerInfo.nickName.length == 0) {
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
