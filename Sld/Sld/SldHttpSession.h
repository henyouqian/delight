//
//  SldHttpSession.h
//  Sld
//
//  Created by Wei Li on 14-4-19.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldUtil.h"

@interface SldHttpSession : NSObject<NSURLSessionDelegate>

+ (instancetype)defaultSession;
+ (instancetype)sessionWithHost:(NSString*)host;

- (void)logoutWithComplete:(void(^)(void))complete;

- (void)postToApi:(NSString*)api
             body:(id)body
completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;

- (NSURLSessionDownloadTask*)downloadFromUrl:(NSString*)url
                 toPath:(NSString*)path
               withData:(id)data
      completionHandler:(void (^)(NSURL *location, NSURLResponse *response, NSError *error, id data))completionHandler;

- (void)cancelAllTask;

- (void)loadImageFromUrl:(NSString*)url
            completionHandler:(void (^)(NSString* localPath, NSError *error))completionHandler;

@end

BOOL isServerError(NSError *error);
NSString* getServerErrorType(NSData *data);
void alertHTTPError(NSError *error, NSData *data);