//
//  SldAppDelegate.m
//  Sld
//
//  Created by Wei Li on 14-4-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldAppDelegate.h"
#import "SldUtil.h"
#import "SldHttpSession.h"

@implementation SldAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //creat image cache dir
    NSString *imgCacheDir = makeDocPath(@"imgCache");
    [[NSFileManager defaultManager] createDirectoryAtPath:imgCacheDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    //
//    [TalkingData setExceptionReportEnabled:YES];
//    [TalkingData sessionStarted:@"A3E09989D8D0FD60D090570D5F60E1F5" withChannelId:@"appstore"];
    //[MobClick startWithAppkey:@"53aeb00356240bdcb8050c26"];
    [Flurry setCrashReportingEnabled:YES];
    [Flurry startSession:@"2P9DTVNTFZS8YBZ36QBZ"];
    
    [AdMoGoInterstitialManager setAppKey:@"8c0728f759464dcda07c81afb00d3bf5"];
    [[AdMoGoInterstitialManager shareInstance] initDefaultInterstitial];
    
    //check version
    NSString *appVer = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"Version":appVer};
    [session postToApi:@"auth/checkVersion" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        NSString *updateUrl = [dict objectForKey:@"UpdateUrl"];
        if (updateUrl && updateUrl.length > 0) {
            NSString *str = [NSString stringWithFormat:@"发现新版本💝，请更新\n当前版本为：%@", appVer];
            [[[UIAlertView alloc] initWithTitle:str
                                        message:nil
                               cancelButtonItem:[RIButtonItem itemWithLabel:@"更新" action:^{
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:updateUrl]];
                alert(@"这个版本太老了，请更新游戏。继续玩的话可能会有些问题。", nil);
            }]
                               otherButtonItems:nil] show];
        }
    }];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    FISoundEngine *engine = [FISoundEngine sharedEngine];
    [engine setSuspended:YES];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    FISoundEngine *engine = [FISoundEngine sharedEngine];
    [engine setSuspended:NO];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
