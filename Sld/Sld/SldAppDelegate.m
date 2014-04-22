//
//  SldAppDelegate.m
//  Sld
//
//  Created by Wei Li on 14-4-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldAppDelegate.h"

@implementation SldAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //db
    NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *dbFileName = @"db/sld.sqlite";
    NSString *dbPath   = [docsPath stringByAppendingPathComponent:dbFileName];
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    [fileMgr createDirectoryAtPath:[docsPath stringByAppendingPathComponent:@"db"] withIntermediateDirectories:YES attributes:nil error:nil];
    
    BOOL dbExist = [fileMgr fileExistsAtPath:dbPath];
    
    FMDatabase *db = [FMDatabase databaseWithPath:dbPath];
    if (![db open]) {
        lwError("fmdb open failed.%@", [db lastErrorMessage]);
    }
    
    BOOL needUpdate = NO;
    NSString *appVer = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    if (dbExist) {
        FMResultSet *r = [db executeQuery:@"SELECT value FROM kv WHERE key=?", @"version"];
        if ([r next]) {
            NSString *dbVer = [r stringForColumnIndex:0];
            if ([dbVer compare:appVer] != 0) {
                needUpdate = YES;
            }
        } else {
            needUpdate = YES;
        }
    } else {
        needUpdate = YES;
    }
    
    if (needUpdate) {
        NSString *createSqlPath = [[NSBundle mainBundle] pathForResource:@"db/create.sql" ofType:nil];
        NSString *fh = [NSString stringWithContentsOfFile:createSqlPath encoding:NSUTF8StringEncoding error:NULL];
        for (NSString *l in [fh componentsSeparatedByString:@";\n"]) {
            if ([l length] > 0) {
                NSMutableString *line = [NSMutableString stringWithString:l];
                [line appendString:@";"];
                lwInfo("%@", line);
                
                [db executeUpdate:line];
            }
        }
        [db executeUpdate:@"REPLACE INTO kv VALUES (?, ?)", @"version", appVer];
    }
    
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
